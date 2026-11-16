import {
  buildTelemetrySnapshot,
  parseLinkStatusPayload,
  parseSensorPayload,
} from './domain.js';

export class TelemetryIngestor {
  constructor({
    database,
    deviceId,
    sensorTopic,
    lruTopic,
    comTopic,
    logger = console,
    clock = Date.now,
  }) {
    this.database = database;
    this.deviceId = deviceId;
    this.sensorTopic = sensorTopic;
    this.lruTopic = lruTopic;
    this.comTopic = comTopic;
    this.logger = logger;
    this.clock = clock;

    this.sensor = null;
    this.sensorReceivedAt = 0;
    this.lru = null;
    this.com = null;

    // Keep the latest complete snapshot so link-only updates can refresh
    // communication fields without changing the sensor reception time.
    this.latestSnapshot = null;

    // Serialize RTDB writes to preserve MQTT message ordering.
    this.snapshotWriteQueue = Promise.resolve();
  }

  resetSession() {
    // Clear all in-memory permissives for this MQTT session.
    this.sensor = null;
    this.sensorReceivedAt = 0;
    this.lru = null;
    this.com = null;

    const path = 'telemetry/' + this.deviceId + '/latest';

    // Queue the reset behind any RTDB writes already in progress.
    const reset = this.snapshotWriteQueue.then(async () => {
      let snapshot = this.latestSnapshot;

      // On a cold Gateway restart, the local cache is empty while
      // Firebase may still contain a snapshot from the previous process.
      if (!snapshot) {
        const storedSnapshot = await this.database.ref(path).get();

        const storedValue = storedSnapshot.exists()
          ? storedSnapshot.val()
          : null;

        // A missing snapshot must not create partial telemetry data.
        if (
          storedValue === null ||
          typeof storedValue !== 'object' ||
          Array.isArray(storedValue)
        ) {
          return;
        }

        // Prefer a new in-memory snapshot if one arrived while reading RTDB.
        snapshot = this.latestSnapshot ?? storedValue;
      }

      const supportedModes = ['UNKNOWN', 'STANDBY', 'RUN', 'INVALID'];
      const supportedVoltageStatuses = ['NORMAL', 'AC_OFF', 'SUSPECT', 'WARNING', 'UNKNOWN'];
      const supportedCurrentStatuses = ['NORMAL', 'SUSPECT', 'UNKNOWN'];
      const normalizeVoltageStatus = (status) =>
        supportedVoltageStatuses.includes(status) ? status : 'UNKNOWN';
      const normalizeCurrentStatus = (status) =>
        supportedCurrentStatuses.includes(status) ? status : 'UNKNOWN';
      const modeIsSupported = supportedModes.includes(snapshot.mode_operasi);
      const invalidated = {
        ...snapshot,
        status_v_sumber: normalizeVoltageStatus(snapshot.status_v_sumber),
        status_v_beban: normalizeVoltageStatus(snapshot.status_v_beban),
        status_i_sumber: normalizeCurrentStatus(snapshot.status_i_sumber),
        status_i_beban: normalizeCurrentStatus(snapshot.status_i_beban),
        mode_operasi: modeIsSupported ? snapshot.mode_operasi : 'UNKNOWN',
        mode_operasi_valid:
          modeIsSupported && snapshot.mode_operasi_valid === true,
        status_lru: 'UNKNOWN',
        status_lru_received_at: 0,
        status_com: 'UNKNOWN',
        status_com_received_at: 0,
        status_lbs: 'UNKNOWN',
      };

      this.latestSnapshot = invalidated;

      await this.database.ref(path).set(invalidated);
    });

    // A failed reset must not permanently block the write queue.
    this.snapshotWriteQueue = reset.catch(() => {});

    return reset;
  }

  getDeviceState(mqttConnected) {
    return {
      mqttConnected,
      sensorReceivedAt: this.sensorReceivedAt,
      sensorQuality: this.sensor?.quality ?? null,
      lruStatus: this.lru?.status ?? 'UNKNOWN',
      lruReceivedAt: this.lru?.receivedAt ?? 0,
      comStatus: this.com?.status ?? 'UNKNOWN',
      comReceivedAt: this.com?.receivedAt ?? 0,
    };
  }

  writeSnapshot(snapshot) {
    const path = 'telemetry/' + this.deviceId + '/latest';

    const write = this.snapshotWriteQueue.then(() =>
      this.database.ref(path).set(snapshot),
    );

    // A failed write must not permanently block subsequent writes.
    this.snapshotWriteQueue = write.catch(() => {});

    return write;
  }

  async handleMessage(topic, payload, mqttPacket = {}) {
    // Retained COM replay is not proof of a live heartbeat
    // in the current Gateway MQTT session.
    if (topic === this.comTopic && mqttPacket?.retain === true) {
      this.logger.info(
        '[Telemetry] Ignored retained COM status; waiting for live heartbeat.',
      );
      return 'ignored-retained-com';
    }

    const now = this.clock();

    if (topic === this.sensorTopic) {
      this.sensor = parseSensorPayload(payload);
      this.sensorReceivedAt = now;

      const snapshot = buildTelemetrySnapshot({
        deviceId: this.deviceId,
        sensor: this.sensor,
        lruStatus: this.lru?.status,
        comStatus: this.com?.status,
        lruReceivedAt: this.lru?.receivedAt ?? 0,
        comReceivedAt: this.com?.receivedAt ?? 0,
        now,
      });

      this.latestSnapshot = snapshot;

      // Keep only the latest monitoring sample.
      await this.writeSnapshot(snapshot);

      this.logger.info('[Telemetry] Latest sensor sample written to RTDB.');
      return 'sensor';
    }

    if (topic === this.lruTopic || topic === this.comTopic) {
      const status = parseLinkStatusPayload(payload);
      const sample = { ...status, receivedAt: now };

      if (topic === this.lruTopic) {
        this.lru = sample;
      } else {
        this.com = sample;
      }

      const linkName = topic === this.lruTopic ? 'LRU' : 'COM';

      if (this.latestSnapshot) {
        // Refresh only link fields. Do not refresh sensor timestamp,
        // received_at, device_ts_ms, or measurement values.
        this.latestSnapshot = {
          ...this.latestSnapshot,
          status_lru: this.lru?.status ?? 'UNKNOWN',
          status_lru_received_at: this.lru?.receivedAt ?? 0,
          status_com: this.com?.status ?? 'UNKNOWN',
          status_com_received_at: this.com?.receivedAt ?? 0,
        };

        await this.writeSnapshot(this.latestSnapshot);

        this.logger.info(
          '[Telemetry] Link status updated in RTDB: ' +
          linkName + ' = ' + status.status +
          '; sensor received_at preserved.',
        );
      } else {
        this.logger.info(
          '[Telemetry] Link status cached: ' +
          linkName + ' = ' + status.status +
          '; waiting for first sensor sample.',
        );
      }

      return topic === this.lruTopic ? 'lru' : 'com';
    }

    return 'ignored';
  }
}