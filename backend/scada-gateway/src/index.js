import { initializeApp, applicationDefault, deleteApp } from 'firebase-admin/app';
import { getDatabase } from 'firebase-admin/database';
import mqtt from 'mqtt';
import { loadConfig } from './config.js';
import { CommandProcessor } from './command-processor.js';
import { TelemetryIngestor } from './telemetry-ingestor.js';

function log(level, message) {
  const line = JSON.stringify({
    timestamp: new Date().toISOString(),
    level,
    message,
  });
  (level === 'error' ? console.error : console.log)(line);
}

async function main() {
  const config = loadConfig();
  const firebaseApp = initializeApp({
    credential: applicationDefault(),
    databaseURL: config.firebaseDatabaseUrl,
  }, 'scada-lbs-gateway');
  const database = getDatabase(firebaseApp);

  const mqttClient = mqtt.connect(config.mqttUrl, {
    username: config.mqttUsername,
    password: config.mqttPassword,
    clientId: config.mqttClientId,
    keepalive: 30,
    connectTimeout: 30_000,
    reconnectPeriod: 5_000,
    clean: true,
    rejectUnauthorized: true,
  });

  let mqttConnected = false;
  const telemetry = new TelemetryIngestor({
    database,
    deviceId: config.deviceId,
    sensorTopic: config.sensorTopic,
    lruTopic: config.lruTopic,
    comTopic: config.comTopic,
    logger: {
      info: (message) => log('info', message),
      error: (message) => log('error', message),
    },
  });

  const invalidateDeviceSession = (reason) => {
    mqttConnected = false;
    telemetry.resetSession();
    log('error', reason + '; cached telemetry and link status invalidated.');
  };

  const processor = new CommandProcessor({
    database,
    mqttClient,
    config,
    getDeviceState: () => telemetry.getDeviceState(mqttConnected),
    logger: {
      info: (message) => log('info', message),
      error: (message) => log('error', message),
    },
  });

  await processor.recoverInterruptedDispatches();
  const detachCommandListener = processor.attach();

  mqttClient.on('connect', () => {
    telemetry.resetSession();
    mqttConnected = true;
    log('info', 'MQTT connected over TLS; waiting for fresh telemetry and retained link states.');
    mqttClient.subscribe({
      [config.sensorTopic]: { qos: 0 },
      [config.lruTopic]: { qos: 1 },
      [config.comTopic]: { qos: 1 },
    }, (error, granted) => {
      if (error) {
        invalidateDeviceSession('MQTT subscription failed: ' + error.message);
        return;
      }
      const refused = granted.filter((item) => item.qos === 128);
      if (refused.length) {
        invalidateDeviceSession('Broker refused one or more required telemetry subscriptions');
      } else {
        log('info', 'MQTT telemetry/status subscriptions acknowledged.');
      }
    });
  });

  mqttClient.on('reconnect', () => {
    invalidateDeviceSession('MQTT reconnecting');
  });
  mqttClient.on('offline', () => {
    invalidateDeviceSession('MQTT client is offline');
  });
  mqttClient.on('close', () => {
    invalidateDeviceSession('MQTT connection closed');
  });
  mqttClient.on('error', (error) => {
    invalidateDeviceSession('MQTT client error: ' + error.message);
  });

  mqttClient.on('message', (topic, payload) => {
    void telemetry.handleMessage(topic, payload).catch((error) => {
      log('error', 'Rejected MQTT payload on ' + topic + ': ' + error.message);
    });
  });

  log('info', 'SCADA-LBS gateway started. Command dispatch: ' +
    (config.commandDispatchEnabled ? 'ENABLED' : 'DRY-RUN ONLY') + '.');
  log('info', 'Only one gateway instance is supported in this MVP.');
  log('info', 'LBS position remains UNKNOWN until independent auxiliary-contact feedback exists.');

  let shuttingDown = false;
  const shutdown = async (signal) => {
    if (shuttingDown) return;
    shuttingDown = true;
    log('info', 'Shutdown requested: ' + signal);
    detachCommandListener();
    await new Promise((resolve) => mqttClient.end(false, {}, resolve));
    await deleteApp(firebaseApp);
    process.exit(0);
  };
  process.once('SIGINT', () => void shutdown('SIGINT'));
  process.once('SIGTERM', () => void shutdown('SIGTERM'));
}

main().catch((error) => {
  log('error', 'Gateway startup failed: ' + error.message);
  process.exitCode = 1;
});
