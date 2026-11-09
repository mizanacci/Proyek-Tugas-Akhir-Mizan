import test from 'node:test';
import assert from 'node:assert/strict';
import {
  buildRelayPayload,
  buildTelemetrySnapshot,
  evaluateCommandProfile,
  evaluateCommandShape,
  evaluateDeviceReadiness,
  parseLinkStatusPayload,
  parseSensorPayload,
} from '../src/domain.js';

test('parses current ESP32 sensor payload', () => {
  const sensor = parseSensorPayload(JSON.stringify({
    v_sumber: 230.4,
    v_beban: 229.9,
    i_sumber: 2.1,
    i_beban: 2.0,
    kualitas: 0,
    ts: 123456,
  }));
  assert.equal(sensor.sourceVoltage, 230.4);
  assert.equal(sensor.deviceTimestampMs, 123456);
});

test('rejects malformed sensor values and quality bitmasks', () => {
  assert.throws(() => parseSensorPayload('{bad json'));
  assert.throws(() => parseSensorPayload({
    v_sumber: -1, v_beban: 220, i_sumber: 1, i_beban: 1, kualitas: 0, ts: 1,
  }));
  assert.throws(() => parseSensorPayload({
    v_sumber: 220, v_beban: 220, i_sumber: 1, i_beban: 1, kualitas: 16, ts: 1,
  }));
});

test('parses only supported link states', () => {
  assert.equal(parseLinkStatusPayload('{"status":"NORMAL"}').status, 'NORMAL');
  assert.throws(() => parseLinkStatusPayload('{"status":"OK"}'));
});

test('telemetry never infers physical LBS position from a command', () => {
  const sensor = parseSensorPayload({
    v_sumber: 220, v_beban: 219, i_sumber: 1, i_beban: 1, kualitas: 0, ts: 5,
  });
  const record = buildTelemetrySnapshot({
    deviceId: 'LBS_01',
    sensor,
    lruStatus: 'NORMAL',
    comStatus: 'NORMAL',
    now: 1000,
  });
  assert.equal(record.status_lbs, 'UNKNOWN');
  assert.equal(record.received_at, 1000);
});

test('accepts only fresh, valid Operator requests', () => {
  const command = {
    target: 'LBS_01',
    action: 'OPEN',
    created_at: 1000,
    created_by_uid: 'uid-operator',
    created_by_name: 'Operator',
    status: 'PENDING',
  };
  assert.deepEqual(evaluateCommandShape(command, 1100, 60_000), { ok: true });
  assert.deepEqual(
    evaluateCommandProfile(command, {
      role: 'operator', isActive: true, displayName: 'Operator',
    }),
    { ok: true },
  );
});

test('rejects Manager, inactive, stale, future, or altered requests', () => {
  const command = {
    target: 'LBS_01',
    action: 'CLOSE',
    created_at: 1000,
    created_by_uid: 'uid-manager',
    created_by_name: 'Manager',
    status: 'PENDING',
  };
  assert.equal(evaluateCommandShape(command, 70_000, 60_000).status, 'EXPIRED');
  assert.equal(evaluateCommandShape({ ...command, action: 'TRIP' }, 1100, 60_000).status, 'REJECTED');
  assert.equal(evaluateCommandShape({ ...command, created_at: 10_000 }, 1000, 60_000).status, 'REJECTED');
  assert.equal(
    evaluateCommandProfile(command, {
      role: 'manager', isActive: true, displayName: 'Manager',
    }).ok,
    false,
  );
  assert.equal(
    evaluateCommandProfile(command, {
      role: 'operator', isActive: false, displayName: 'Manager',
    }).ok,
    false,
  );
});

test('requires fresh sensor, LRU, and COM status before enabled dispatch', () => {
  const state = {
    mqttConnected: true,
    sensorReceivedAt: 900,
    lruStatus: 'NORMAL',
    lruReceivedAt: 940,
    comStatus: 'NORMAL',
    comReceivedAt: 950,
  };
  assert.equal(evaluateDeviceReadiness(state, 1000, 15_000).ready, true);
  assert.equal(
    evaluateDeviceReadiness({ ...state, comStatus: 'FAIL' }, 1000, 15_000).ready,
    false,
  );
  assert.equal(
    evaluateDeviceReadiness({ ...state, sensorReceivedAt: 0 }, 1000, 15_000).ready,
    false,
  );
  assert.equal(
    evaluateDeviceReadiness({ ...state, lruReceivedAt: 0 }, 1000, 15_000).ready,
    false,
  );
  assert.equal(
    evaluateDeviceReadiness({ ...state, lruReceivedAt: 1 }, 20_000, 15_000).ready,
    false,
  );
});

test('maps actions only from explicit NO/NC configuration', () => {
  assert.equal(buildRelayPayload('OPEN', { open: 'NO', close: 'NC' }), '{"command":"NO"}');
  assert.equal(buildRelayPayload('CLOSE', { open: 'NO', close: 'NC' }), '{"command":"NC"}');
  assert.throws(() => buildRelayPayload('OPEN', { open: null, close: 'NC' }));
});
