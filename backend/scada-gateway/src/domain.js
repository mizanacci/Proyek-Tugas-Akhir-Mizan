export const COMMAND_RESULT_STATUSES = Object.freeze([
  'RECEIVED',
  'EXECUTING',
  'SUCCEEDED',
  'FAILED',
  'REJECTED',
  'EXPIRED',
  'INDETERMINATE',
]);

export function parseJsonObject(payload, label) {
  let value = payload;
  if (Buffer.isBuffer(value)) value = value.toString('utf8');
  if (typeof value === 'string') {
    try {
      value = JSON.parse(value);
    } catch {
      throw new Error(label + ' payload is not valid JSON');
    }
  }
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error(label + ' payload must be a JSON object');
  }
  return value;
}

function finiteNonNegativeNumber(value, field) {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 0) {
    throw new Error('Invalid sensor field: ' + field);
  }
  return value;
}

export function parseSensorPayload(payload) {
  const data = parseJsonObject(payload, 'Sensor');
  const quality = data.kualitas;
  const deviceTimestampMs = data.ts;

  if (!Number.isSafeInteger(quality) || quality < 0 || quality > 15) {
    throw new Error('Invalid sensor field: kualitas must be an integer from 0 to 15');
  }
  if (!Number.isSafeInteger(deviceTimestampMs) || deviceTimestampMs < 0) {
    throw new Error('Invalid sensor field: ts must be a non-negative integer');
  }

  return Object.freeze({
    sourceVoltage: finiteNonNegativeNumber(data.v_sumber, 'v_sumber'),
    loadVoltage: finiteNonNegativeNumber(data.v_beban, 'v_beban'),
    sourceCurrent: finiteNonNegativeNumber(data.i_sumber, 'i_sumber'),
    loadCurrent: finiteNonNegativeNumber(data.i_beban, 'i_beban'),
    quality,
    deviceTimestampMs,
  });
}

export function parseLinkStatusPayload(payload) {
  const data = parseJsonObject(payload, 'Link status');
  if (data.status !== 'NORMAL' && data.status !== 'FAIL') {
    throw new Error('Link status must be NORMAL or FAIL');
  }
  return Object.freeze({
    status: data.status,
    source: typeof data.source === 'string' ? data.source.slice(0, 80) : 'unknown',
  });
}

export function buildTelemetrySnapshot({
  deviceId,
  sensor,
  lruStatus,
  comStatus,
  now = Date.now(),
}) {
  return {
    device_id: deviceId,
    timestamp: now,
    received_at: now,
    device_ts_ms: sensor.deviceTimestampMs,
    v_sumber: sensor.sourceVoltage,
    v_beban: sensor.loadVoltage,
    i_sumber: sensor.sourceCurrent,
    i_beban: sensor.loadCurrent,
    kualitas: sensor.quality,
    status_lru: lruStatus || 'UNKNOWN',
    status_com: comStatus || 'UNKNOWN',
    // Current firmware has no independent LBS auxiliary-contact feedback topic.
    // Never infer the physical position from the last requested command.
    status_lbs: 'UNKNOWN',
  };
}

export function evaluateCommandShape(command, now, maxAgeMs) {
  if (command === null || typeof command !== 'object' || Array.isArray(command)) {
    return { ok: false, status: 'REJECTED', reason: 'Command record is not an object.' };
  }
  if (command.status !== 'PENDING') {
    return { ok: false, status: 'REJECTED', reason: 'Only PENDING requests are eligible.' };
  }
  if (command.target !== 'LBS_01') {
    return { ok: false, status: 'REJECTED', reason: 'Unknown command target.' };
  }
  if (command.action !== 'OPEN' && command.action !== 'CLOSE') {
    return { ok: false, status: 'REJECTED', reason: 'Unsupported command action.' };
  }
  if (typeof command.created_by_uid !== 'string' || !command.created_by_uid.trim()) {
    return { ok: false, status: 'REJECTED', reason: 'Command creator UID is missing.' };
  }
  if (typeof command.created_by_name !== 'string' ||
      !command.created_by_name.trim() ||
      command.created_by_name.length > 120) {
    return { ok: false, status: 'REJECTED', reason: 'Command creator name is invalid.' };
  }
  if (!Number.isSafeInteger(command.created_at) || command.created_at <= 0) {
    return { ok: false, status: 'REJECTED', reason: 'Command timestamp is invalid.' };
  }

  const ageMs = now - command.created_at;
  if (ageMs < -5_000) {
    return { ok: false, status: 'REJECTED', reason: 'Command timestamp is in the future.' };
  }
  if (ageMs > maxAgeMs) {
    return { ok: false, status: 'EXPIRED', reason: 'Command expired before gateway processing.' };
  }
  return { ok: true };
}

export function evaluateCommandProfile(command, profile) {
  if (profile === null || typeof profile !== 'object') {
    return { ok: false, reason: 'Creator profile does not exist.' };
  }
  if (profile.isActive !== true || profile.role !== 'operator') {
    return { ok: false, reason: 'Only an active Operator may request LBS control.' };
  }
  if (typeof profile.displayName !== 'string' ||
      profile.displayName !== command.created_by_name) {
    return { ok: false, reason: 'Command creator name does not match the current profile.' };
  }
  return { ok: true };
}

function isFreshTimestamp(timestamp, now, maxAgeMs) {
  return Number.isSafeInteger(timestamp) &&
    timestamp > 0 &&
    timestamp <= now + 5_000 &&
    now - timestamp <= maxAgeMs;
}

export function evaluateDeviceReadiness(state, now, maxAgeMs) {
  if (!state?.mqttConnected) {
    return { ready: false, reason: 'MQTT broker is disconnected.' };
  }
  if (!isFreshTimestamp(state.sensorReceivedAt, now, maxAgeMs)) {
    return { ready: false, reason: 'Sensor telemetry is missing or stale.' };
  }
  if (state.lruStatus !== 'NORMAL') {
    return { ready: false, reason: 'LRU status is not NORMAL.' };
  }
  if (!isFreshTimestamp(state.lruReceivedAt, now, maxAgeMs)) {
    return { ready: false, reason: 'LRU status is missing or stale.' };
  }
  if (state.comStatus !== 'NORMAL') {
    return { ready: false, reason: 'COM status is not NORMAL.' };
  }
  if (!isFreshTimestamp(state.comReceivedAt, now, maxAgeMs)) {
    return { ready: false, reason: 'COM status heartbeat is missing or stale.' };
  }
  return { ready: true };
}

export function buildRelayPayload(action, mapping) {
  const command = action === 'OPEN' ? mapping.open : action === 'CLOSE' ? mapping.close : null;
  if (command !== 'NO' && command !== 'NC') {
    throw new Error('No explicit OPEN/CLOSE to NO/NC mapping is configured.');
  }
  return JSON.stringify({ command });
}
