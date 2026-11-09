import 'package:flutter_test/flutter_test.dart';
import 'package:scada_mizan_app/models/scada_data.dart';
import 'package:scada_mizan_app/models/sensor_data.dart';
import 'package:scada_mizan_app/models/user_profile.dart';
import 'package:scada_mizan_app/services/scada_service.dart';

void main() {
  const operatorProfile = UserProfile(
    uid: 'operator-uid',
    displayName: 'SCADA Operator',
    role: UserRole.operator,
    isActive: true,
  );
  const managerProfile = UserProfile(
    uid: 'manager-uid',
    displayName: 'SCADA Manager',
    role: UserRole.manager,
    isActive: true,
  );

  test('active operator creates a pending Firebase command request', () async {
    final database = _MemoryScadaDatabase();
    final service = ScadaService(
      loadCurrentProfile: () async => operatorProfile,
      database: database,
    );

    final commandId = await service.sendLbsCommand(
      target: ScadaService.lbsTarget,
      action: 'CLOSE',
    );

    expect(commandId, 'generated-command-id');
    expect(database.createCount, 1);
    expect(database.savedCommand, containsPair('target', 'LBS_01'));
    expect(database.savedCommand, containsPair('action', 'CLOSE'));
    expect(database.savedCommand, containsPair('status', 'PENDING'));
    expect(
        database.savedCommand, containsPair('created_by_uid', 'operator-uid'));
    expect(database.savedCommand,
        containsPair('created_by_name', 'SCADA Operator'));
    expect(database.savedCommand!['created_at'], isNotNull);
  });

  test('manager and unauthenticated user cannot create command', () async {
    for (final profile in <UserProfile?>[managerProfile, null]) {
      final database = _MemoryScadaDatabase();
      final service = ScadaService(
        loadCurrentProfile: () async => profile,
        database: database,
      );

      await expectLater(
        service.sendLbsCommand(target: 'LBS_01', action: 'OPEN'),
        throwsA(isA<ScadaServiceException>()),
      );
      expect(database.createCount, 0);
    }
  });

  test('invalid target, action, and disconnected database are rejected',
      () async {
    final database = _MemoryScadaDatabase();
    final service = ScadaService(
      loadCurrentProfile: () async => operatorProfile,
      database: database,
    );

    await expectLater(
      service.sendLbsCommand(target: 'OTHER', action: 'OPEN'),
      throwsA(isA<ScadaServiceException>()),
    );
    await expectLater(
      service.sendLbsCommand(target: 'LBS_01', action: 'NO'),
      throwsA(isA<ScadaServiceException>()),
    );
    database.connected = false;
    await expectLater(
      service.sendLbsCommand(target: 'LBS_01', action: 'OPEN'),
      throwsA(isA<ScadaServiceException>()),
    );
    expect(database.createCount, 0);
  });

  test('manager can watch command requests, results, and activity', () async {
    final database = _MemoryScadaDatabase()
      ..commandsValue = {
        'command-1': {
          'target': 'LBS_01',
          'action': 'OPEN',
          'created_at': 900,
          'created_by_uid': 'operator-uid',
          'created_by_name': 'SCADA Operator',
          'status': 'PENDING',
        },
      }
      ..commandResultValue = {
        'command_id': 'command-1',
        'status': 'EXECUTING',
        'updated_at': 1000,
        'detail': 'Gateway processing request',
      }
      ..activityValue = {'kind': 'PERINTAH', 'command_id': 'command-1'};
    final service = ScadaService(
      loadCurrentProfile: () async => managerProfile,
      database: database,
    );

    final commands = await service.watchCommands().first;
    final result = await service.watchCommandResult('command-1').first;
    final activity = await service.watchActivity().first;

    expect(commands.single.commandId, 'command-1');
    expect(commands.single.status, 'PENDING');
    expect(result?.status, CommandResultStatus.executing);
    expect(activity, containsPair('command_id', 'command-1'));
  });

  test('inactive and unauthenticated profiles cannot watch backend data',
      () async {
    const inactiveProfile = UserProfile(
      uid: 'inactive-uid',
      displayName: 'Inactive',
      role: UserRole.operator,
      isActive: false,
    );
    for (final profile in <UserProfile?>[inactiveProfile, null]) {
      final service = ScadaService(
        loadCurrentProfile: () async => profile,
        database: _MemoryScadaDatabase(),
      );
      await expectLater(
        service.watchActivity().first,
        throwsA(isA<ScadaServiceException>()),
      );
    }
  });

  test('parses backend telemetry and command result independently', () {
    final telemetry = ScadaTelemetry.fromValue('LBS_01', {
      'device_id': 'LBS_01',
      'timestamp': 1000,
      'device_ts_ms': 900,
      'received_at': 950,
      'v_sumber': 230,
      'v_beban': 229,
      'i_sumber': 2.1,
      'i_beban': 2.0,
      'kualitas': 0,
      'status_lru': 'NORMAL',
      'status_com': 'NORMAL',
      'status_lbs': 'OPEN',
    });
    final result = ScadaCommandResult.fromValue('command-1', {
      'command_id': 'command-1',
      'status': 'SUCCEEDED',
      'updated_at': 1100,
      'detail': 'PLC feedback confirmed OPEN',
    });

    expect(telemetry.lbsStatus, 'OPEN');
    expect(result.status, CommandResultStatus.succeeded);
    expect(result.commandId, 'command-1');
  });

  test('parses an indeterminate command result without calling it successful',
      () {
    final result = ScadaCommandResult.fromValue('command-2', {
      'command_id': 'command-2',
      'status': 'INDETERMINATE',
      'updated_at': 1200,
      'detail': 'Delivery and physical position are unknown.',
    });

    expect(result.status, CommandResultStatus.indeterminate);
    expect(result.status, isNot(CommandResultStatus.succeeded));
  });

  test('rejects invalid telemetry identity and unknown result state', () {
    expect(
      () => ScadaTelemetry.fromValue('LBS_01', {'device_id': 'OTHER'}),
      throwsFormatException,
    );
    expect(
      () => ScadaCommandResult.fromValue('command-1', {
        'command_id': 'command-1',
        'status': 'PENDING',
        'updated_at': 100,
        'detail': 'pending',
      }),
      throwsFormatException,
    );
  });
}

class _MemoryScadaDatabase implements ScadaDatabase {
  bool connected = true;
  int createCount = 0;
  Map<String, Object?>? savedCommand;
  Object? commandsValue;
  Object? commandResultValue;
  Object? activityValue;

  @override
  Future<bool> isConnected() async => connected;

  @override
  Future<String> createCommand(Map<String, Object?> command) async {
    createCount++;
    savedCommand = command;
    return 'generated-command-id';
  }

  @override
  Stream<Object?> watchCommands() => Stream<Object?>.value(commandsValue);

  @override
  Stream<Object?> watchActivity() => Stream<Object?>.value(activityValue);

  @override
  Stream<Object?> watchCommandResult(String commandId) =>
      Stream<Object?>.value(commandResultValue);

  @override
  Stream<Object?> watchTelemetry(String deviceId) =>
      const Stream<Object?>.empty();
}
