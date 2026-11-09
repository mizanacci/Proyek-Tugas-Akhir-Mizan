import {
  buildRelayPayload,
  evaluateCommandProfile,
  evaluateCommandShape,
  evaluateDeviceReadiness,
} from './domain.js';

export class CommandProcessor {
  constructor({
    database,
    mqttClient,
    config,
    getDeviceState,
    logger = console,
    clock = Date.now,
  }) {
    this.database = database;
    this.mqttClient = mqttClient;
    this.config = config;
    this.getDeviceState = getDeviceState;
    this.logger = logger;
    this.clock = clock;
    this.inFlight = new Set();
  }

  attach() {
    const query = this.database.ref('commands')
      .orderByChild('created_at')
      .limitToLast(100);
    const onChildAdded = (snapshot) => {
      if (!snapshot.key) return;
      void this.process(snapshot.key, snapshot.val()).catch((error) => {
        this.logger.error('[Command] Processing failed for ' + snapshot.key + ': ' + error.message);
      });
    };
    const onCancel = (error) => {
      this.logger.error('[Command] Firebase listener cancelled: ' + error.message);
    };
    query.on('child_added', onChildAdded, onCancel);
    return () => query.off('child_added', onChildAdded);
  }

  async recoverInterruptedDispatches() {
    const snapshot = await this.database.ref('command_results')
      .orderByChild('updated_at')
      .limitToLast(100)
      .get();

    if (!snapshot.exists()) return;
    const records = snapshot.val();
    for (const [commandId, result] of Object.entries(records)) {
      if (!result) continue;
      const reference = this.database.ref('command_results/' + commandId);
      const now = this.clock();

      if (result.dispatch_state === 'validating') {
        await reference.transaction((current) => {
          if (!current || current.dispatch_state !== 'validating') return;
          return {
            ...current,
            status: 'FAILED',
            dispatch_state: 'interrupted',
            updated_at: now,
            detail: 'Gateway stopped during request validation. No MQTT publish was initiated; submit a new request only after checking the command list.',
          };
        }, undefined, false);
        continue;
      }

      if (!['publishing', 'sent'].includes(result.dispatch_state)) continue;
      await reference.transaction((current) => {
        if (!current || !['publishing', 'sent'].includes(current.dispatch_state)) return;
        return {
          ...current,
          status: 'INDETERMINATE',
          dispatch_state: 'interrupted',
          updated_at: now,
          detail: 'Gateway restarted during/after MQTT publish. Delivery and physical LBS state are unknown. Verify feedback before issuing another command.',
        };
      }, undefined, false);
    }
  }

  async process(commandId, command) {
    if (this.inFlight.has(commandId)) return;
    this.inFlight.add(commandId);

    try {
      const resultRef = this.database.ref('command_results/' + commandId);
      const now = this.clock();
      const claim = await resultRef.transaction((current) => {
        if (current !== null) return;
        return {
          command_id: commandId,
          status: 'RECEIVED',
          dispatch_state: 'validating',
          updated_at: now,
          detail: 'Gateway received the request and is validating it.',
        };
      }, undefined, false);

      // Existing result means this command has already been claimed or handled.
      // Never republish it automatically: that could repeat a physical action.
      if (!claim.committed) return;

      const shape = evaluateCommandShape(
        command,
        this.clock(),
        this.config.commandMaxAgeMs,
      );
      if (!shape.ok) {
        await this.finish(resultRef, commandId, command, shape.status, shape.reason, 'rejected');
        return;
      }

      const profileSnapshot = await this.database.ref(
        'users/' + command.created_by_uid,
      ).get();
      const profileCheck = evaluateCommandProfile(command, profileSnapshot.val());
      if (!profileCheck.ok) {
        await this.finish(
          resultRef, commandId, command, 'REJECTED', profileCheck.reason, 'rejected',
        );
        return;
      }

      if (!this.config.commandDispatchEnabled) {
        await this.finish(
          resultRef,
          commandId,
          command,
          'RECEIVED',
          'DRY-RUN: request validated; no MQTT control message was published.',
          'dry_run',
        );
        return;
      }

      const readiness = evaluateDeviceReadiness(
        this.getDeviceState(),
        this.clock(),
        this.config.deviceStatusMaxAgeMs,
      );
      if (!readiness.ready) {
        await this.finish(
          resultRef, commandId, command, 'REJECTED',
          'Dispatch blocked by gateway readiness check: ' + readiness.reason,
          'rejected',
        );
        return;
      }

      const mapping = {
        open: this.config.openCommandValue,
        close: this.config.closeCommandValue,
      };
      const payload = buildRelayPayload(command.action, mapping);

      await resultRef.update({
        status: 'EXECUTING',
        dispatch_state: 'publishing',
        updated_at: this.clock(),
        detail: 'Gateway is submitting the MQTT command. No device or PLC acknowledgement has been received.',
      });

      try {
        await this.publishQos0(this.config.commandTopic, payload);
        await resultRef.update({
          status: 'EXECUTING',
          dispatch_state: 'sent',
          updated_at: this.clock(),
          detail: 'MQTT QoS 0 PUBLISH was handed to the gateway transport. This is not confirmation of ESP32 receipt, PLC execution, or physical LBS position.',
        });
        await this.writeActivity(commandId, command, profileSnapshot.val(), 'EXECUTING',
          'MQTT request submitted; device/PLC/LBS feedback remains unconfirmed.');
      } catch (error) {
        // A connection failure can occur after bytes were sent. Treat delivery
        // as ambiguous and never retry automatically.
        await resultRef.update({
          status: 'INDETERMINATE',
          dispatch_state: 'interrupted',
          updated_at: this.clock(),
          detail: 'MQTT publish outcome is uncertain: ' + safeError(error) +
            '. Verify device and PLC feedback before issuing another command.',
        });
        await this.writeActivity(commandId, command, profileSnapshot.val(), 'INDETERMINATE',
          'MQTT delivery outcome is uncertain; physical state must be checked.');
      }
    } finally {
      this.inFlight.delete(commandId);
    }
  }

  async publishQos0(topic, payload) {
    if (!this.mqttClient.connected) throw new Error('MQTT broker is disconnected');
    await new Promise((resolve, reject) => {
      this.mqttClient.publish(topic, payload, { qos: 0, retain: false }, (error) => {
        if (error) reject(error);
        else resolve();
      });
    });
  }

  async finish(resultRef, commandId, command, status, detail, dispatchState) {
    await resultRef.update({
      status,
      dispatch_state: dispatchState,
      updated_at: this.clock(),
      detail,
    });
    await this.writeActivity(commandId, command, null, status, detail);
  }

  async writeActivity(commandId, command, profile, status, detail) {
    const actorUid = typeof command?.created_by_uid === 'string'
      ? command.created_by_uid : 'unknown';
    const actorName = profile && typeof profile.displayName === 'string'
      ? profile.displayName
      : (typeof command?.created_by_name === 'string' ? command.created_by_name : 'Gateway');
    try {
      await this.database.ref('data_activity').push().set({
        timestamp: this.clock(),
        jenis: 'PERINTAH',
        keterangan: (String(command?.action || 'UNKNOWN') + ' ' + status + ': ' + detail).slice(0, 300),
        oleh_uid: actorUid,
        oleh_nama: actorName.slice(0, 120),
        sumber: 'gateway',
        command_id: commandId,
      });
    } catch (error) {
      this.logger.error('[Activity] Could not append activity for command ' +
        commandId + ': ' + safeError(error));
    }
  }
}

function safeError(error) {
  return error instanceof Error ? error.message.slice(0, 160) : 'unknown error';
}
