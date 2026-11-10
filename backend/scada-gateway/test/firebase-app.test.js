import test from 'node:test';
import assert from 'node:assert/strict';
import { GATEWAY_APP_NAME, GATEWAY_UID, gatewayAppOptions } from '../src/firebase-app.js';

test('Firebase gateway app uses the limited service identity', () => {
  const options = gatewayAppOptions('https://example-default-rtdb.asia-southeast1.firebasedatabase.app');

  assert.equal(GATEWAY_APP_NAME, 'scada-lbs-gateway');
  assert.equal(GATEWAY_UID, 'scada-lbs-gateway');
  assert.deepEqual(options.databaseAuthVariableOverride, {
    uid: 'scada-lbs-gateway',
  });
  assert.equal(options.databaseURL, 'https://example-default-rtdb.asia-southeast1.firebasedatabase.app');
});