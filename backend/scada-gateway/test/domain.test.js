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
    suspect_i_sumber: false,
    status_i_sumber: 'NORMAL',
    suspect_i_beban: true,
    status_i_beban: 'SUSPECT',
    kualitas: 0,
    ts: 123456,
  }));
  assert.equal(sensor.sourceVoltage, 230.4);
  assert.equal(sensor.sourceCurrentStatus, 'NORMAL');
  assert.equal(sensor.loadCurrentStatus, 'SUSPECT');
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
  assert.equal(evaluateCommandShape({ ...command, unexpected: true }, 1100, 60_000).status, 'REJECTED');
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

test('requires fresh, GOOD sensor and current-session LRU plus fresh COM before dispatch', () => {
  const state = {
    mqttConnected: true,
    sensorReceivedAt: 19_900,
    sensorQuality: 0,
    lruStatus: 'NORMAL',
    lruReceivedAt: 500,
    comStatus: 'NORMAL',
    comReceivedAt: 19_950,
  };
  // LRU NORMAL is retained and is sent once at ESP32 connect; the gateway
  // invalidates it on reconnect rather than applying the COM heartbeat TTL.
  assert.equal(evaluateDeviceReadiness(state, 20_000, 15_000).ready, true);
  assert.equal(
    evaluateDeviceReadiness({ ...state, comStatus: 'FAIL' }, 20_000, 15_000).ready,
    false,
  );
  assert.equal(
    evaluateDeviceReadiness({ ...state, sensorReceivedAt: 0 }, 20_000, 15_000).ready,
    false,
  );
  assert.equal(
    evaluateDeviceReadiness({ ...state, lruReceivedAt: 0 }, 20_000, 15_000).ready,
    false,
  );
  assert.equal(
    evaluateDeviceReadiness({ ...state, sensorQuality: 1 }, 20_000, 15_000).ready,
    false,
  );
  assert.equal(
    evaluateDeviceReadiness({ ...state, comReceivedAt: 1 }, 20_000, 15_000).ready,
    false,
  );
});

test('maps actions only from explicit NO/NC configuration', () => {
  assert.equal(buildRelayPayload('OPEN', { open: 'NO', close: 'NC' }), '{"command":"NO"}');
  assert.equal(buildRelayPayload('CLOSE', { open: 'NO', close: 'NC' }), '{"command":"NC"}');
  assert.throws(() => buildRelayPayload('OPEN', { open: null, close: 'NC' }));
});

// ============================================================
// HREG7 - PLC Operation Mode Tests
// ============================================================

function makeHreg7SensorPayload(overrides = {}) {
  return {
    v_sumber: 220,
    v_beban: 219,
    i_sumber: 0,
    i_beban: 0,
    kualitas: 0,
    ts: 123456,
    ...overrides,
  };
}

test('HREG7 accepts all supported PLC operation modes', () => {
  const modes = ['UNKNOWN', 'STANDBY', 'RUN', 'INVALID'];

  for (const mode of modes) {
    const sensor = parseSensorPayload(
      makeHreg7SensorPayload({
        mode_operasi: mode,
        mode_operasi_valid: true,
      }),
    );

    assert.equal(sensor.operationMode, mode);
    assert.equal(sensor.operationModeValid, true);
  }
});

test('HREG7 preserves backward compatibility with legacy sensor payloads', () => {
  const sensor = parseSensorPayload(makeHreg7SensorPayload());

  assert.equal(sensor.operationMode, 'UNKNOWN');
  assert.equal(sensor.operationModeValid, false);
});

test('HREG7 rejects unsupported operation modes and non-boolean validity', () => {
  assert.throws(
    () => parseSensorPayload(
      makeHreg7SensorPayload({
        mode_operasi: 'MAINTENANCE',
        mode_operasi_valid: true,
      }),
    ),
    /mode_operasi is not recognized/,
  );

  assert.throws(
    () => parseSensorPayload(
      makeHreg7SensorPayload({
        mode_operasi: 'RUN',
        mode_operasi_valid: 'true',
      }),
    ),
    /mode_operasi_valid must be boolean/,
  );

  assert.throws(
    () => parseSensorPayload(
      makeHreg7SensorPayload({
        mode_operasi: 2,
        mode_operasi_valid: true,
      }),
    ),
    /mode_operasi is not recognized/,
  );
});

test('Firebase telemetry snapshot preserves HREG7 operation mode', () => {
  const sensor = parseSensorPayload(
    makeHreg7SensorPayload({
      mode_operasi: 'STANDBY',
      mode_operasi_valid: true,
    }),
  );

  const record = buildTelemetrySnapshot({
    deviceId: 'LBS_01',
    sensor,
    lruStatus: 'NORMAL',
    comStatus: 'NORMAL',
    now: 2000,
  });

  assert.equal(record.mode_operasi, 'STANDBY');
  assert.equal(record.mode_operasi_valid, true);
  assert.equal(record.status_lbs, 'UNKNOWN');
});

test('Firebase snapshot exposes independent LRU and COM reception timestamps', () => {
  const sensor = parseSensorPayload({
    v_sumber: 220,
    v_beban: 219,
    i_sumber: 0,
    i_beban: 0,
    kualitas: 0,
    ts: 500,
  });

  const record = buildTelemetrySnapshot({
    deviceId: 'LBS_01',
    sensor,
    lruStatus: 'NORMAL',
    comStatus: 'NORMAL',
    lruReceivedAt: 900,
    comReceivedAt: 950,
    now: 1000,
  });

  assert.equal(record.timestamp, 1000);
  assert.equal(record.received_at, 1000);
  assert.equal(record.status_lru_received_at, 900);
  assert.equal(record.status_com_received_at, 950);
});

test('parses and validates firmware voltage operating statuses', () => {
  const base = {
    v_sumber: 220,
    v_beban: 219,
    i_sumber: 0,
    i_beban: 0,
    kualitas: 0,
    ts: 500,
  };

  const parseStatus = (status, flags) => parseSensorPayload({
    ...base,
    status_v_sumber: status,
    suspect_v_sumber: flags.suspect,
    warning_v_sumber: flags.warning,
    ac_off_v_sumber: flags.acOff,
    status_v_beban: status,
    suspect_v_beban: flags.suspect,
    warning_v_beban: flags.warning,
    ac_off_v_beban: flags.acOff,
  });

  const normal = parseStatus('NORMAL', { suspect: false, warning: false, acOff: false });
  assert.equal(normal.sourceVoltageStatus, 'NORMAL');
  assert.equal(normal.loadVoltageStatus, 'NORMAL');

  const acOff = parseStatus('NORMAL', { suspect: false, warning: false, acOff: true });
  assert.equal(acOff.sourceVoltageStatus, 'AC_OFF');

  const suspect = parseStatus('SUSPECT', { suspect: true, warning: false, acOff: false });
  assert.equal(suspect.sourceVoltageStatus, 'SUSPECT');

  const warning = parseStatus('WARNING', { suspect: false, warning: true, acOff: false });
  assert.equal(warning.sourceVoltageStatus, 'WARNING');

  const record = buildTelemetrySnapshot({
    deviceId: 'LBS_01',
    sensor: suspect,
    lruStatus: 'NORMAL',
    comStatus: 'FAIL',
    now: 1000,
  });
  assert.equal(record.status_v_sumber, 'SUSPECT');
  assert.equal(record.status_v_beban, 'SUSPECT');
  assert.equal(record.status_lbs, 'UNKNOWN');
});

test('rejects partial or inconsistent firmware voltage status fields', () => {
  const base = {
    v_sumber: 220,
    v_beban: 219,
    i_sumber: 0,
    i_beban: 0,
    kualitas: 0,
    ts: 500,
  };

  assert.throws(() => parseSensorPayload({
    ...base,
    status_v_sumber: 'NORMAL',
  }), /Incomplete voltage status fields/);

  assert.throws(() => parseSensorPayload({
    ...base,
    status_v_sumber: 'NORMAL',
    suspect_v_sumber: true,
    warning_v_sumber: false,
    ac_off_v_sumber: false,
  }), /Inconsistent voltage status flags/);

  assert.throws(() => parseSensorPayload({
    ...base,
    status_v_sumber: 'WARNING',
    suspect_v_sumber: false,
    warning_v_sumber: true,
    ac_off_v_sumber: true,
  }), /Inconsistent voltage status flags/);

  // Legacy payloads are accepted, but never silently treated as NORMAL.
  const legacy = parseSensorPayload(base);
  assert.equal(legacy.sourceVoltageStatus, 'UNKNOWN');
  assert.equal(legacy.loadVoltageStatus, 'UNKNOWN');
});

test('preserves explicit current status and treats legacy status as UNKNOWN', () => {
  const normal = parseSensorPayload({
    v_sumber: 220,
    v_beban: 219,
    i_sumber: 0,
    i_beban: 2.0,
    suspect_i_sumber: false,
    status_i_sumber: 'NORMAL',
    suspect_i_beban: true,
    status_i_beban: 'SUSPECT',
    kualitas: 8,
    ts: 500,
  });

  assert.equal(normal.sourceCurrentStatus, 'NORMAL');
  assert.equal(normal.loadCurrentStatus, 'SUSPECT');

  const record = buildTelemetrySnapshot({
    deviceId: 'LBS_01',
    sensor: normal,
    now: 1000,
  });
  assert.equal(record.status_i_sumber, 'NORMAL');
  assert.equal(record.status_i_beban, 'SUSPECT');

  const legacy = parseSensorPayload({
    v_sumber: 220,
    v_beban: 219,
    i_sumber: 0,
    i_beban: 0,
    kualitas: 0,
    ts: 500,
  });
  assert.equal(legacy.sourceCurrentStatus, 'UNKNOWN');
  assert.equal(legacy.loadCurrentStatus, 'UNKNOWN');
});

test('rejects incomplete or inconsistent current status fields', () => {
  const base = {
    v_sumber: 220,
    v_beban: 219,
    i_sumber: 0,
    i_beban: 0,
    kualitas: 0,
    ts: 500,
  };

  assert.throws(() => parseSensorPayload({
    ...base,
    status_i_sumber: 'NORMAL',
  }), /Incomplete current status fields/);

  assert.throws(() => parseSensorPayload({
    ...base,
    status_i_sumber: 'NORMAL',
    suspect_i_sumber: true,
  }), /Inconsistent current status fields/);
});