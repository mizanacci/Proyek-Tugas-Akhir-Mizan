import test from 'node:test';
import assert from 'node:assert/strict';
import { TelemetryIngestor } from '../src/telemetry-ingestor.js';

class MemoryDatabase {
  constructor() {
    this.values = new Map();
  }

  ref(path) {
    return {
      set: async (value) => this.values.set(path, value),
    };
  }
}

test('writes latest sensor telemetry and clears cached permissives after disconnect', async () => {
  const database = new MemoryDatabase();
  const ingestor = new TelemetryIngestor({
    database,
    deviceId: 'LBS_01',
    sensorTopic: 'sensor/topic',
    lruTopic: 'lru/topic',
    comTopic: 'com/topic',
    logger: { info() {}, error() {} },
    clock: () => 1000,
  });

  await ingestor.handleMessage('lru/topic', '{"status":"NORMAL","source":"lwt"}');
  await ingestor.handleMessage('com/topic', '{"status":"NORMAL","source":"esp32_watchdog_estimate"}');
  await ingestor.handleMessage('sensor/topic', JSON.stringify({
    v_sumber: 220,
    v_beban: 219,
    i_sumber: 1,
    i_beban: 1,
    kualitas: 0,
    ts: 500,
  }));

  const record = database.values.get('telemetry/LBS_01/latest');
  assert.equal(record.status_lru, 'NORMAL');
  assert.equal(record.status_com, 'NORMAL');
  assert.equal(record.status_lbs, 'UNKNOWN');
  assert.equal(ingestor.getDeviceState(true).lruReceivedAt, 1000);

  ingestor.resetSession();
  const reset = ingestor.getDeviceState(true);
  assert.equal(reset.sensorReceivedAt, 0);
  assert.equal(reset.lruStatus, 'UNKNOWN');
  assert.equal(reset.lruReceivedAt, 0);
  assert.equal(reset.comStatus, 'UNKNOWN');
  assert.equal(reset.comReceivedAt, 0);
});
