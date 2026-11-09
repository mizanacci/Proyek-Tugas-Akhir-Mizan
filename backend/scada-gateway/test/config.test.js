import test from 'node:test';
import assert from 'node:assert/strict';
import { loadConfig } from '../src/config.js';

const valid = {
  FIREBASE_DATABASE_URL: 'https://example-default-rtdb.asia-southeast1.firebasedatabase.app',
  MQTT_URL: 'mqtts://broker.example.com:8883',
  MQTT_USERNAME: 'gateway-user',
  MQTT_PASSWORD: 'not-a-real-secret',
  MQTT_CLIENT_ID: 'gateway-test-01',
};

test('dispatch defaults to safe dry-run mode', () => {
  const config = loadConfig(valid);
  assert.equal(config.commandDispatchEnabled, false);
  assert.equal(config.openCommandValue, null);
  assert.equal(config.closeCommandValue, null);
});

test('enabled dispatch requires explicit and distinct NO/NC mapping', () => {
  assert.throws(() => loadConfig({
    ...valid,
    COMMAND_DISPATCH_ENABLED: 'true',
  }));
  assert.throws(() => loadConfig({
    ...valid,
    COMMAND_DISPATCH_ENABLED: 'true',
    OPEN_COMMAND_VALUE: 'NO',
    CLOSE_COMMAND_VALUE: 'NO',
  }));
  const config = loadConfig({
    ...valid,
    COMMAND_DISPATCH_ENABLED: 'true',
    OPEN_COMMAND_VALUE: 'NO',
    CLOSE_COMMAND_VALUE: 'NC',
  });
  assert.equal(config.commandDispatchEnabled, true);
  assert.equal(config.openCommandValue, 'NO');
  assert.equal(config.closeCommandValue, 'NC');
});

test('rejects non-TLS URL and credentials embedded in broker URL', () => {
  assert.throws(() => loadConfig({ ...valid, MQTT_URL: 'mqtt://broker.example.com' }));
  assert.throws(() => loadConfig({
    ...valid,
    MQTT_URL: 'mqtts://user:password@broker.example.com:8883',
  }));
});
