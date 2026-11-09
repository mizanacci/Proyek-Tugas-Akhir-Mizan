import test from 'node:test';
import assert from 'node:assert/strict';
import { CommandProcessor } from '../src/command-processor.js';

class MemoryDatabase {
  constructor(profile) {
    this.values = new Map([['users/operator-uid', profile]]);
    this.pushCount = 0;
  }

  ref(path) {
    const database = this;
    return {
      async get() {
        return {
          exists: () => database.values.has(path),
          val: () => database.values.get(path) ?? null,
        };
      },
      async transaction(update) {
        const current = database.values.get(path) ?? null;
        const next = update(current);
        if (next === undefined) return { committed: false, snapshot: { val: () => current } };
        database.values.set(path, next);
        return { committed: true, snapshot: { val: () => next } };
      },
      async update(patch) {
        const current = database.values.get(path) ?? {};
        database.values.set(path, { ...current, ...patch });
      },
      push() {
        const key = 'activity-' + (++database.pushCount);
        return {
          key,
          async set(value) {
            database.values.set(path + '/' + key, value);
          },
        };
      },
    };
  }
}

const command = {
  target: 'LBS_01',
  action: 'OPEN',
  created_at: 1000,
  created_by_uid: 'operator-uid',
  created_by_name: 'SCADA Operator',
  status: 'PENDING',
};

test('dry-run validates request but never publishes MQTT control', async () => {
  const database = new MemoryDatabase({
    role: 'operator',
    isActive: true,
    displayName: 'SCADA Operator',
  });
  let publishCount = 0;
  const mqttClient = {
    connected: true,
    publish() { publishCount++; },
  };
  const processor = new CommandProcessor({
    database,
    mqttClient,
    config: {
      commandDispatchEnabled: false,
      commandMaxAgeMs: 60_000,
      deviceStatusMaxAgeMs: 15_000,
      commandTopic: 'scada/mizan/cmd/relay',
    },
    getDeviceState: () => ({
      mqttConnected: true,
      sensorReceivedAt: 1000,
      sensorQuality: 0,
      lruStatus: 'NORMAL',
      lruReceivedAt: 1000,
      comStatus: 'NORMAL',
      comReceivedAt: 1000,
    }),
    logger: { info() {}, error() {} },
    clock: () => 1100,
  });

  await processor.process('command-dry-run', command);

  const result = database.values.get('command_results/command-dry-run');
  assert.equal(result.status, 'RECEIVED');
  assert.equal(result.dispatch_state, 'dry_run');
  assert.equal(publishCount, 0);
  assert.equal(database.pushCount, 1);
});

test('enabled dispatch rejects stale or missing LRU status before MQTT publish', async () => {
  const database = new MemoryDatabase({
    role: 'operator',
    isActive: true,
    displayName: 'SCADA Operator',
  });
  let publishCount = 0;
  const mqttClient = {
    connected: true,
    publish() { publishCount++; },
  };
  const processor = new CommandProcessor({
    database,
    mqttClient,
    config: {
      commandDispatchEnabled: true,
      commandMaxAgeMs: 60_000,
      deviceStatusMaxAgeMs: 15_000,
      commandTopic: 'scada/mizan/cmd/relay',
      openCommandValue: 'NO',
      closeCommandValue: 'NC',
    },
    getDeviceState: () => ({
      mqttConnected: true,
      sensorReceivedAt: 1000,
      sensorQuality: 0,
      lruStatus: 'NORMAL',
      lruReceivedAt: 0,
      comStatus: 'NORMAL',
      comReceivedAt: 1000,
    }),
    logger: { info() {}, error() {} },
    clock: () => 1100,
  });

  await processor.process('command-not-ready', command);

  const result = database.values.get('command_results/command-not-ready');
  assert.equal(result.status, 'REJECTED');
  assert.match(result.detail, /LRU status has not been received in this MQTT session/);
  assert.equal(publishCount, 0);
});
