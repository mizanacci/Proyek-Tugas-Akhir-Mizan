import test from 'node:test';
import assert from 'node:assert/strict';
import { TelemetryIngestor } from '../src/telemetry-ingestor.js';

class MemoryDatabase {
  constructor() {
    this.values = new Map();
    this.writeHistory = [];
  }

  ref(path) {
    return {
      get: async () => ({
        exists: () => this.values.has(path),
        val: () => this.values.get(path) ?? null,
      }),
      set: async (value) => {
        const copy = structuredClone(value);
        this.values.set(path, copy);
        this.writeHistory.push({ path, value: copy });
      },
    };
  }
}

function makeSensorPayload() {
  return {
    v_sumber: 220,
    v_beban: 219,
    i_sumber: 0,
    i_beban: 0,
    kualitas: 0,
    ts: 500,
  };
}

function makeIngestor(database, clock) {
  return new TelemetryIngestor({
    database,
    deviceId: 'LBS_01',
    sensorTopic: 'sensor/topic',
    lruTopic: 'lru/topic',
    comTopic: 'com/topic',
    logger: { info() {}, error() {} },
    clock,
  });
}

test('writes latest sensor telemetry and clears cached permissives after disconnect', async () => {
  const database = new MemoryDatabase();
  const ingestor = makeIngestor(database, () => 1000);

  await ingestor.handleMessage(
    'lru/topic',
    '{"status":"NORMAL","source":"lwt"}',
  );

  await ingestor.handleMessage(
    'com/topic',
    '{"status":"NORMAL","source":"esp32_watchdog_estimate"}',
  );

  await ingestor.handleMessage(
    'sensor/topic',
    JSON.stringify(makeSensorPayload()),
  );

  const record = database.values.get('telemetry/LBS_01/latest');

  assert.equal(record.status_lru, 'NORMAL');
  assert.equal(record.status_com, 'NORMAL');
  assert.equal(record.status_lru_received_at, 1000);
  assert.equal(record.status_com_received_at, 1000);
  assert.equal(record.status_lbs, 'UNKNOWN');

  await ingestor.resetSession();

  const reset = database.values.get('telemetry/LBS_01/latest');

  assert.equal(reset.status_lru, 'UNKNOWN');
  assert.equal(reset.status_com, 'UNKNOWN');
  assert.equal(reset.status_lru_received_at, 0);
  assert.equal(reset.status_com_received_at, 0);

  assert.equal(reset.received_at, record.received_at);

  const state = ingestor.getDeviceState(false);

  assert.equal(state.sensorReceivedAt, 0);
  assert.equal(state.lruReceivedAt, 0);
  assert.equal(state.comReceivedAt, 0);
});

test('status-only MQTT messages do not create partial telemetry snapshots', async () => {
  const database = new MemoryDatabase();
  let now = 1000;
  const ingestor = makeIngestor(database, () => now);

  await ingestor.handleMessage(
    'lru/topic',
    '{"status":"NORMAL","source":"lwt"}',
  );

  now = 1010;

  await ingestor.handleMessage(
    'com/topic',
    '{"status":"NORMAL","source":"esp32_watchdog_estimate"}',
  );

  assert.equal(database.values.has('telemetry/LBS_01/latest'), false);
  assert.equal(database.writeHistory.length, 0);

  const state = ingestor.getDeviceState(true);

  assert.equal(state.lruStatus, 'NORMAL');
  assert.equal(state.lruReceivedAt, 1000);
  assert.equal(state.comStatus, 'NORMAL');
  assert.equal(state.comReceivedAt, 1010);
});

test('ignores retained COM replay and accepts live COM heartbeat', async () => {
  const database = new MemoryDatabase();
  let now = 1000;
  const ingestor = makeIngestor(database, () => now);

  await ingestor.handleMessage(
    'sensor/topic',
    JSON.stringify(makeSensorPayload()),
  );

  const initial = database.values.get('telemetry/LBS_01/latest');

  assert.ok(initial);
  assert.equal(initial.status_com, 'UNKNOWN');
  assert.equal(initial.status_com_received_at, 0);

  now = 1020;

  const retainedResult = await ingestor.handleMessage(
    'com/topic',
    '{"status":"NORMAL","source":"esp32_watchdog_estimate"}',
    { retain: true },
  );

  assert.equal(retainedResult, 'ignored-retained-com');

  const afterRetained = database.values.get('telemetry/LBS_01/latest');

  assert.equal(afterRetained.status_com, 'UNKNOWN');
  assert.equal(afterRetained.status_com_received_at, 0);
  assert.equal(afterRetained.timestamp, initial.timestamp);
  assert.equal(afterRetained.received_at, initial.received_at);
  assert.equal(ingestor.getDeviceState(true).comStatus, 'UNKNOWN');
  assert.equal(ingestor.getDeviceState(true).comReceivedAt, 0);

  now = 1030;

  const liveResult = await ingestor.handleMessage(
    'com/topic',
    '{"status":"NORMAL","source":"esp32_watchdog_estimate"}',
    { retain: false },
  );

  assert.equal(liveResult, 'com');

  const afterLive = database.values.get('telemetry/LBS_01/latest');

  assert.equal(afterLive.status_com, 'NORMAL');
  assert.equal(afterLive.status_com_received_at, 1030);

  // Link heartbeat must not refresh sensor timestamps.
  assert.equal(afterLive.timestamp, initial.timestamp);
  assert.equal(afterLive.received_at, initial.received_at);

  assert.equal(ingestor.getDeviceState(true).comStatus, 'NORMAL');
  assert.equal(ingestor.getDeviceState(true).comReceivedAt, 1030);
});
test('sensor snapshot includes separate LRU and COM reception timestamps', async () => {
  const database = new MemoryDatabase();
  let now = 1000;
  const ingestor = makeIngestor(database, () => now);

  await ingestor.handleMessage(
    'lru/topic',
    '{"status":"NORMAL","source":"lwt"}',
  );

  now = 1010;

  await ingestor.handleMessage(
    'com/topic',
    '{"status":"NORMAL","source":"esp32_watchdog_estimate"}',
  );

  now = 1020;

  await ingestor.handleMessage(
    'sensor/topic',
    JSON.stringify(makeSensorPayload()),
  );

  const record = database.values.get('telemetry/LBS_01/latest');

  assert.equal(record.device_id, 'LBS_01');
  assert.equal(record.status_lru, 'NORMAL');
  assert.equal(record.status_lru_received_at, 1000);
  assert.equal(record.status_com, 'NORMAL');
  assert.equal(record.status_com_received_at, 1010);

  assert.equal(record.timestamp, 1020);
  assert.equal(record.received_at, 1020);
  assert.equal(record.device_ts_ms, 500);
  assert.equal(record.status_lbs, 'UNKNOWN');
});

test('LRU and COM updates publish immediately without refreshing sensor timestamps', async () => {
  const database = new MemoryDatabase();
  let now = 1000;
  const ingestor = makeIngestor(database, () => now);

  await ingestor.handleMessage(
    'lru/topic',
    '{"status":"NORMAL","source":"lwt"}',
  );

  now = 1010;

  await ingestor.handleMessage(
    'com/topic',
    '{"status":"NORMAL","source":"esp32_watchdog_estimate"}',
  );

  now = 1020;

  await ingestor.handleMessage(
    'sensor/topic',
    JSON.stringify(makeSensorPayload()),
  );

  const initial = database.values.get('telemetry/LBS_01/latest');
  const originalTimestamp = initial.timestamp;
  const originalReceivedAt = initial.received_at;

  now = 1030;

  await ingestor.handleMessage(
    'lru/topic',
    '{"status":"FAIL","source":"lwt"}',
  );

  const afterLru = database.values.get('telemetry/LBS_01/latest');

  assert.equal(afterLru.status_lru, 'FAIL');
  assert.equal(afterLru.status_lru_received_at, 1030);
  assert.equal(afterLru.status_com, 'NORMAL');
  assert.equal(afterLru.status_com_received_at, 1010);

  assert.equal(afterLru.timestamp, originalTimestamp);
  assert.equal(afterLru.received_at, originalReceivedAt);
  assert.equal(afterLru.device_ts_ms, 500);

  now = 1040;

  await ingestor.handleMessage(
    'com/topic',
    '{"status":"NORMAL","source":"esp32_watchdog_estimate"}',
  );

  const afterCom = database.values.get('telemetry/LBS_01/latest');

  assert.equal(afterCom.status_lru, 'FAIL');
  assert.equal(afterCom.status_lru_received_at, 1030);
  assert.equal(afterCom.status_com, 'NORMAL');
  assert.equal(afterCom.status_com_received_at, 1040);

  assert.equal(afterCom.timestamp, originalTimestamp);
  assert.equal(afterCom.received_at, originalReceivedAt);

  assert.equal(database.writeHistory.length, 3);
});

test('resetSession invalidates published link states but preserves last sensor timestamp', async () => {
  const database = new MemoryDatabase();
  let now = 1000;
  const ingestor = makeIngestor(database, () => now);

  await ingestor.handleMessage(
    'lru/topic',
    '{"status":"NORMAL","source":"lwt"}',
  );

  now = 1010;

  await ingestor.handleMessage(
    'com/topic',
    '{"status":"NORMAL","source":"esp32_watchdog_estimate"}',
  );

  now = 1020;

  await ingestor.handleMessage(
    'sensor/topic',
    JSON.stringify(makeSensorPayload()),
  );

  const beforeReset = database.values.get('telemetry/LBS_01/latest');

  now = 2000;

  await ingestor.resetSession();

  const afterReset = database.values.get('telemetry/LBS_01/latest');

  assert.equal(afterReset.status_lru, 'UNKNOWN');
  assert.equal(afterReset.status_lru_received_at, 0);
  assert.equal(afterReset.status_com, 'UNKNOWN');
  assert.equal(afterReset.status_com_received_at, 0);

  assert.equal(afterReset.timestamp, beforeReset.timestamp);
  assert.equal(afterReset.received_at, beforeReset.received_at);
  assert.equal(afterReset.device_ts_ms, beforeReset.device_ts_ms);

  const state = ingestor.getDeviceState(false);

  assert.equal(state.mqttConnected, false);
  assert.equal(state.sensorReceivedAt, 0);
  assert.equal(state.sensorQuality, null);
  assert.equal(state.lruStatus, 'UNKNOWN');
  assert.equal(state.lruReceivedAt, 0);
  assert.equal(state.comStatus, 'UNKNOWN');
  assert.equal(state.comReceivedAt, 0);
});

test('resetSession before the first sensor sample does not create partial RTDB data', async () => {
  const database = new MemoryDatabase();
  const ingestor = makeIngestor(database, () => 1000);

  await ingestor.resetSession();

  await ingestor.handleMessage(
    'lru/topic',
    '{"status":"NORMAL","source":"lwt"}',
  );

  await ingestor.handleMessage(
    'com/topic',
    '{"status":"NORMAL","source":"esp32_watchdog_estimate"}',
  );

  assert.equal(database.values.has('telemetry/LBS_01/latest'), false);
  assert.equal(database.writeHistory.length, 0);
});

test('cold restart normalizes a legacy snapshot and invalidates persisted link statuses', async () => {
  const database = new MemoryDatabase();

  // Legacy snapshot: HREG7 fields were not yet part of the stored schema.
  const previousSnapshot = {
    device_id: 'LBS_01',
    timestamp: 1000,
    received_at: 1000,
    device_ts_ms: 900,
    v_sumber: 220,
    v_beban: 219,
    i_sumber: 0,
    i_beban: 0,
    kualitas: 0,
    status_lru: 'NORMAL',
    status_lru_received_at: 990,
    status_com: 'NORMAL',
    status_com_received_at: 995,
    status_lbs: 'UNKNOWN',
  };

  database.values.set(
    'telemetry/LBS_01/latest',
    structuredClone(previousSnapshot),
  );

  // A new Gateway process starts with an empty in-memory snapshot cache.
  const restartedGateway = makeIngestor(database, () => 2000);
  await restartedGateway.resetSession();

  const record = database.values.get('telemetry/LBS_01/latest');

  assert.equal(record.status_lru, 'UNKNOWN');
  assert.equal(record.status_lru_received_at, 0);
  assert.equal(record.status_com, 'UNKNOWN');
  assert.equal(record.status_com_received_at, 0);
  assert.equal(record.mode_operasi, 'UNKNOWN');
  assert.equal(record.mode_operasi_valid, false);
  assert.equal(record.status_lbs, 'UNKNOWN');
  assert.equal(record.status_v_sumber, 'UNKNOWN');
  assert.equal(record.status_v_beban, 'UNKNOWN');

  // The reset must not make old sensor measurements appear fresh.
  assert.equal(record.timestamp, previousSnapshot.timestamp);
  assert.equal(record.received_at, previousSnapshot.received_at);
  assert.equal(record.device_ts_ms, previousSnapshot.device_ts_ms);
  assert.equal(record.v_sumber, previousSnapshot.v_sumber);

  const state = restartedGateway.getDeviceState(false);
  assert.equal(state.sensorReceivedAt, 0);
  assert.equal(state.lruStatus, 'UNKNOWN');
  assert.equal(state.lruReceivedAt, 0);
  assert.equal(state.comStatus, 'UNKNOWN');
  assert.equal(state.comReceivedAt, 0);
});

test('cold restart preserves a supported HREG7 mode in a modern snapshot', async () => {
  const database = new MemoryDatabase();
  const previousSnapshot = {
    device_id: 'LBS_01',
    timestamp: 1000,
    received_at: 1000,
    device_ts_ms: 900,
    v_sumber: 220,
    v_beban: 219,
    i_sumber: 0,
    i_beban: 0,
    kualitas: 0,
    status_v_sumber: 'SUSPECT',
    status_v_beban: 'AC_OFF',
    mode_operasi: 'RUN',
    mode_operasi_valid: true,
    status_lru: 'NORMAL',
    status_lru_received_at: 990,
    status_com: 'NORMAL',
    status_com_received_at: 995,
    status_lbs: 'UNKNOWN',
  };

  database.values.set(
    'telemetry/LBS_01/latest',
    structuredClone(previousSnapshot),
  );

  const restartedGateway = makeIngestor(database, () => 2000);
  await restartedGateway.resetSession();

  const record = database.values.get('telemetry/LBS_01/latest');
  assert.equal(record.mode_operasi, 'RUN');
  assert.equal(record.mode_operasi_valid, true);
  assert.equal(record.status_v_sumber, 'SUSPECT');
  assert.equal(record.status_v_beban, 'AC_OFF');
  assert.equal(record.status_lru, 'UNKNOWN');
  assert.equal(record.status_lru_received_at, 0);
  assert.equal(record.status_com, 'UNKNOWN');
  assert.equal(record.status_com_received_at, 0);
  assert.equal(record.status_lbs, 'UNKNOWN');
  assert.equal(record.timestamp, previousSnapshot.timestamp);
  assert.equal(record.received_at, previousSnapshot.received_at);
});

test('cold restart normalizes unsupported voltage statuses to UNKNOWN', async () => {
  const database = new MemoryDatabase();
  const previousSnapshot = {
    device_id: 'LBS_01',
    timestamp: 1000,
    received_at: 1000,
    device_ts_ms: 900,
    v_sumber: 220,
    v_beban: 219,
    i_sumber: 0,
    i_beban: 0,
    kualitas: 0,
    status_v_sumber: 'INVALID_STATUS',
    status_v_beban: null,
    status_lru: 'NORMAL',
    status_lru_received_at: 990,
    status_com: 'NORMAL',
    status_com_received_at: 995,
    status_lbs: 'UNKNOWN',
  };

  database.values.set('telemetry/LBS_01/latest', structuredClone(previousSnapshot));
  const restartedGateway = makeIngestor(database, () => 2000);
  await restartedGateway.resetSession();
  const record = database.values.get('telemetry/LBS_01/latest');

  assert.equal(record.status_v_sumber, 'UNKNOWN');
  assert.equal(record.status_v_beban, 'UNKNOWN');
  assert.equal(record.status_lbs, 'UNKNOWN');
});
