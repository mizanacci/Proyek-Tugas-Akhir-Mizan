import {
  buildTelemetrySnapshot,
  parseLinkStatusPayload,
  parseSensorPayload,
} from './domain.js';

export class TelemetryIngestor {
  constructor({ database, deviceId, sensorTopic, lruTopic, comTopic, logger = console, clock = Date.now }) {
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
  }

  getDeviceState(mqttConnected) {
    return {
      mqttConnected,
      sensorReceivedAt: this.sensorReceivedAt,
      lruStatus: this.lru?.status ?? 'UNKNOWN',
      lruReceivedAt: this.lru?.receivedAt ?? 0,
      comStatus: this.com?.status ?? 'UNKNOWN',
      comReceivedAt: this.com?.receivedAt ?? 0,
    };
  }

  async handleMessage(topic, payload) {
    const now = this.clock();

    if (topic === this.sensorTopic) {
      this.sensor = parseSensorPayload(payload);
      this.sensorReceivedAt = now;
      const snapshot = buildTelemetrySnapshot({
        deviceId: this.deviceId,
        sensor: this.sensor,
        lruStatus: this.lru?.status,
        comStatus: this.com?.status,
        now,
      });

      // Keep only the latest monitoring sample. The Flutter client queries the
      // newest child; retaining an unbounded sample history would inflate RTDB.
      await this.database.ref('telemetry/' + this.deviceId + '/latest').set(snapshot);
      this.logger.info('[Telemetry] Latest sample written to RTDB.');
      return 'sensor';
    }

    if (topic === this.lruTopic || topic === this.comTopic) {
      const status = parseLinkStatusPayload(payload);
      const sample = { ...status, receivedAt: now };
      if (topic === this.lruTopic) this.lru = sample;
      else this.com = sample;
      this.logger.info('[Telemetry] Link status updated: ' +
        (topic === this.lruTopic ? 'LRU' : 'COM') + ' = ' + status.status);
      return topic === this.lruTopic ? 'lru' : 'com';
    }

    return 'ignored';
  }
}
