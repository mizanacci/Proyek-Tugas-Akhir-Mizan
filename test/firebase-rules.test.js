import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

const rules = fs.readFileSync(
  path.join(process.cwd(), 'flutter_app_skeleton', 'database.rules.json'),
  'utf8',
);
const now = Date.now();
const command = {
  target: 'LBS_01',
  action: 'OPEN',
  created_at: now,
  created_by_uid: 'operator-uid',
  created_by_name: 'SCADA Operator',
  status: 'PENDING',
};
const result = {
  command_id: 'command-1',
  status: 'RECEIVED',
  dispatch_state: 'dry_run',
  updated_at: now,
  detail: 'Dry run',
};
const telemetry = {
  device_id: 'LBS_01',
  timestamp: now,
  device_ts_ms: 1000,
  received_at: now,
  v_sumber: 220,
  v_beban: 220,
  i_sumber: 1,
  i_beban: 1,
  kualitas: 0,
  status_lru: 'NORMAL',
  status_com: 'NORMAL',
  status_lbs: 'UNKNOWN',
};
const activity = {
  timestamp: now,
  jenis: 'PERINTAH',
  keterangan: 'OPEN RECEIVED: Dry run',
  oleh_uid: 'operator-uid',
  oleh_nama: 'SCADA Operator',
  sumber: 'gateway',
  command_id: 'command-1',
};
const seed = {
  users: {
    'manager-uid': {
      email: 'manager@example.test', displayName: 'SCADA Manager', role: 'manager', isActive: true,
    },
    'operator-uid': {
      email: 'operator@example.test', displayName: 'SCADA Operator', role: 'operator', isActive: true,
    },
    'inactive-uid': {
      email: 'inactive@example.test', displayName: 'Inactive', role: 'operator', isActive: false,
    },
  },
  commands: { 'command-1': command },
  command_results: { 'command-1': result },
  telemetry: { LBS_01: { latest: telemetry } },
  data_activity: { 'activity-1': activity },
};

let env;

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-scada-lbs',
    database: { rules },
  });
  await env.withSecurityRulesDisabled(async (context) => {
    await context.database().ref().set(seed);
  });
});

test.after(async () => {
  await env.cleanup();
});

function context(uid) {
  return env.authenticatedContext(uid).database();
}

function unauthenticated() {
  return env.unauthenticatedContext().database();
}

async function canRead(database, path) {
  return assertSucceeds(database.ref(path).get());
}

async function cannotRead(database, path) {
  return assertFails(database.ref(path).get());
}

const operationalPaths = [
  'commands', 'command_results', 'telemetry', 'data_activity',
];

test('unauthenticated cannot read root or operational data', async () => {
  const database = unauthenticated();
  await assertFails(database.ref().get());
  for (const dataPath of operationalPaths) await cannotRead(database, dataPath);
});

test('active manager can read operational data', async () => {
  const database = context('manager-uid');
  for (const dataPath of operationalPaths) await canRead(database, dataPath);
});

test('active operator can read operational data', async () => {
  const database = context('operator-uid');
  for (const dataPath of operationalPaths) await canRead(database, dataPath);
});

test('inactive operator cannot read operational data', async () => {
  const database = context('inactive-uid');
  for (const dataPath of operationalPaths) await cannotRead(database, dataPath);
});

test('users can read only their own profile', async () => {
  await canRead(context('operator-uid'), 'users/operator-uid');
  await cannotRead(context('operator-uid'), 'users/manager-uid');
});

test('no user can change a profile', async () => {
  await assertFails(context('operator-uid').ref('users/operator-uid').set({ ...seed.users['operator-uid'], displayName: 'Changed' }));
  await assertFails(context('operator-uid').ref('users/operator-uid').update({ displayName: 'Changed' }));
});

test('manager cannot create a command', async () => {
  await assertFails(context('manager-uid').ref('commands/manager-command').set({ ...command, created_by_uid: 'manager-uid', created_by_name: 'SCADA Manager' }));
});

test('active operator can create a valid command', async () => {
  const valid = { ...command, created_at: Date.now() };
  await assertSucceeds(context('operator-uid').ref('commands/valid-command').set(valid));
});

test('invalid target and action are rejected', async () => {
  await assertFails(context('operator-uid').ref('commands/bad-target').set({ ...command, target: 'LBS_02', created_at: Date.now() }));
  await assertFails(context('operator-uid').ref('commands/bad-action').set({ ...command, action: 'TRIP', created_at: Date.now() }));
});

test('stale and future commands are rejected', async () => {
  await assertFails(context('operator-uid').ref('commands/stale').set({ ...command, created_at: Date.now() - 300001 }));
  await assertFails(context('operator-uid').ref('commands/future').set({ ...command, created_at: Date.now() + 300001 }));
});

test('extra fields are rejected', async () => {
  await assertFails(context('operator-uid').ref('commands/extra').set({ ...command, extra: true, created_at: Date.now() }));
});

test('command update and delete are rejected', async () => {
  await assertFails(context('operator-uid').ref('commands/command-1').update({ action: 'CLOSE' }));
  await assertFails(context('operator-uid').ref('commands/command-1').remove());
});

test('gateway can read commands and operator profiles', async () => {
  await canRead(context('scada-lbs-gateway'), 'commands');
  await canRead(context('scada-lbs-gateway'), 'users/operator-uid');
});

test('gateway can create and update valid command results', async () => {
  const database = context('scada-lbs-gateway');
  await assertSucceeds(database.ref('command_results/command-1').set({
    ...result, updated_at: Date.now(),
  }));
  await assertSucceeds(database.ref('command_results/command-1').update({
    status: 'INDETERMINATE', updated_at: Date.now(),
  }));
});

test('gateway can repeatedly write latest telemetry for LBS_01', async () => {
  const database = context('scada-lbs-gateway');
  await assertSucceeds(database.ref('telemetry/LBS_01/latest').set({ ...telemetry, timestamp: Date.now(), received_at: Date.now() }));
  await assertSucceeds(database.ref('telemetry/LBS_01/latest').set({ ...telemetry, timestamp: Date.now(), received_at: Date.now() }));
});

test('gateway telemetry rejects another device and extra fields', async () => {
  const database = context('scada-lbs-gateway');
  await assertFails(database.ref('telemetry/LBS_02/latest').set({ ...telemetry, device_id: 'LBS_02' }));
  await assertFails(database.ref('telemetry/LBS_01/latest').set({ ...telemetry, extra: true }));
});

test('gateway can append activity for a command', async () => {
  await assertSucceeds(context('scada-lbs-gateway').ref('data_activity/activity-2').set({ ...activity, timestamp: Date.now() }));
});

test('gateway cannot update or delete existing activity', async () => {
  const database = context('scada-lbs-gateway');
  await assertFails(database.ref('data_activity/activity-1').update({ keterangan: 'changed' }));
  await assertFails(database.ref('data_activity/activity-1').remove());
});

test('non-gateway users cannot write backend-owned data', async () => {
  const database = context('operator-uid');
  await assertFails(database.ref('command_results/blocked').set({ ...result, command_id: 'command-1' }));
  await assertFails(database.ref('telemetry/LBS_01/latest').set(telemetry));
  await assertFails(database.ref('data_activity/activity-3').set(activity));
});

test('gateway cannot create or change commands or users', async () => {
  const database = context('scada-lbs-gateway');
  await assertFails(database.ref('commands/gateway-command').set(command));
  await assertFails(database.ref('commands/command-1').update({ action: 'CLOSE' }));
  await assertFails(database.ref('users/operator-uid').update({ displayName: 'Changed' }));
});
