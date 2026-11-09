const DEFAULTS = {
  deviceId: 'LBS_01',
  commandTopic: 'scada/mizan/cmd/relay',
  sensorTopic: 'scada/mizan/data/sensor',
  lruTopic: 'scada/mizan/status/lrufail',
  comTopic: 'scada/mizan/status/comfail',
  commandMaxAgeMs: 60_000,
  deviceStatusMaxAgeMs: 15_000,
};

function required(env, key) {
  const value = env[key]?.trim();
  if (!value) throw new Error('Missing required environment variable: ' + key);
  return value;
}

function positiveInteger(env, key, fallback, max) {
  const raw = env[key]?.trim();
  if (!raw) return fallback;
  const value = Number(raw);
  if (!Number.isSafeInteger(value) || value <= 0 || value > max) {
    throw new Error(key + ' must be a positive integer <= ' + max);
  }
  return value;
}

function parseBoolean(env, key, fallback = false) {
  const raw = env[key]?.trim().toLowerCase();
  if (!raw) return fallback;
  if (raw === 'true') return true;
  if (raw === 'false') return false;
  throw new Error(key + ' must be true or false');
}

function commandToken(env, key, dispatchEnabled) {
  const value = env[key]?.trim().toUpperCase() || '';
  if (!dispatchEnabled && !value) return null;
  if (value !== 'NO' && value !== 'NC') {
    throw new Error(key + ' must explicitly be NO or NC when command dispatch is enabled');
  }
  return value;
}

export function loadConfig(env = process.env) {
  const firebaseDatabaseUrl = required(env, 'FIREBASE_DATABASE_URL');
  let databaseUrl;
  try {
    databaseUrl = new URL(firebaseDatabaseUrl);
  } catch {
    throw new Error('FIREBASE_DATABASE_URL must be a valid HTTPS URL');
  }
  if (databaseUrl.protocol !== 'https:') {
    throw new Error('FIREBASE_DATABASE_URL must use HTTPS');
  }

  const mqttUrl = required(env, 'MQTT_URL');
  let brokerUrl;
  try {
    brokerUrl = new URL(mqttUrl);
  } catch {
    throw new Error('MQTT_URL must be a valid mqtts:// URL');
  }
  if (brokerUrl.protocol !== 'mqtts:') {
    throw new Error('MQTT_URL must use mqtts:// TLS');
  }
  if (brokerUrl.username || brokerUrl.password) {
    throw new Error('Do not embed MQTT credentials in MQTT_URL; use MQTT_USERNAME and MQTT_PASSWORD');
  }

  const mqttUsername = required(env, 'MQTT_USERNAME');
  const mqttPassword = required(env, 'MQTT_PASSWORD');
  const mqttClientId = required(env, 'MQTT_CLIENT_ID');
  if (mqttClientId.length > 64 || /\s/.test(mqttClientId)) {
    throw new Error('MQTT_CLIENT_ID must be <=64 characters and contain no whitespace');
  }

  const commandDispatchEnabled = parseBoolean(env, 'COMMAND_DISPATCH_ENABLED', false);
  const openCommandValue = commandToken(env, 'OPEN_COMMAND_VALUE', commandDispatchEnabled);
  const closeCommandValue = commandToken(env, 'CLOSE_COMMAND_VALUE', commandDispatchEnabled);
  if (commandDispatchEnabled && openCommandValue === closeCommandValue) {
    throw new Error('OPEN_COMMAND_VALUE and CLOSE_COMMAND_VALUE must be different');
  }

  const deviceId = (env.DEVICE_ID || DEFAULTS.deviceId).trim();
  if (deviceId !== DEFAULTS.deviceId) {
    throw new Error('DEVICE_ID must remain LBS_01 until the Flutter client supports another target');
  }

  return Object.freeze({
    firebaseDatabaseUrl,
    mqttUrl,
    mqttUsername,
    mqttPassword,
    mqttClientId,
    deviceId,
    commandTopic: DEFAULTS.commandTopic,
    sensorTopic: DEFAULTS.sensorTopic,
    lruTopic: DEFAULTS.lruTopic,
    comTopic: DEFAULTS.comTopic,
    commandDispatchEnabled,
    openCommandValue,
    closeCommandValue,
    commandMaxAgeMs: positiveInteger(
      env, 'COMMAND_MAX_AGE_MS', DEFAULTS.commandMaxAgeMs, 300_000,
    ),
    deviceStatusMaxAgeMs: positiveInteger(
      env, 'DEVICE_STATUS_MAX_AGE_MS', DEFAULTS.deviceStatusMaxAgeMs, 60_000,
    ),
  });
}
