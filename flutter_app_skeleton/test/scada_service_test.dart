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

  const testNow = 1700000000000;

  test('active operator creates a pending Firebase command request', () async {
    // LRU timestamp intentionally older than 15 seconds:
    // its validity is scoped to the current MQTT session.
    final database = _MemoryScadaDatabase()
      ..telemetryValue = _healthyTelemetry(
        testNow,
        lruReceivedAt: testNow - 120000,
      );
    final service = ScadaService(
      loadCurrentProfile: () async => operatorProfile,
      database: database,
      clock: () => testNow,
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

  test(
      'command logging does not depend on telemetry or physical link readiness',
      () async {
    final missingLruTimestamp = _healthyTelemetry(testNow)
      ..remove('status_lru_received_at');
    final missingComTimestamp = _healthyTelemetry(testNow)
      ..remove('status_com_received_at');
    final malformedComTimestamp = _healthyTelemetry(testNow)
      ..['status_com_received_at'] = 'invalid';

    final scenarios = <String, Object?>{
      'telemetry missing': null,
      'sensor telemetry stale': _healthyTelemetry(
        testNow,
        receivedAt: testNow - 15001,
      ),
      'sensor timestamp too far in the future': _healthyTelemetry(
        testNow,
        receivedAt: testNow + 5001,
      ),
      'sensor quality not GOOD': _healthyTelemetry(testNow, quality: 1),
      'LRU status not NORMAL': _healthyTelemetry(testNow, lruStatus: 'FAIL'),
      'LRU reception timestamp missing': missingLruTimestamp,
      'LRU reception timestamp zero':
          _healthyTelemetry(testNow, lruReceivedAt: 0),
      'COM status not NORMAL': _healthyTelemetry(testNow, comStatus: 'FAIL'),
      'COM heartbeat stale': _healthyTelemetry(
        testNow,
        comReceivedAt: testNow - 15001,
      ),
      'COM heartbeat too far in the future': _healthyTelemetry(
        testNow,
        comReceivedAt: testNow + 5001,
      ),
      'COM heartbeat timestamp missing': missingComTimestamp,
      'COM heartbeat timestamp malformed': malformedComTimestamp,
    };

    for (final scenario in scenarios.entries) {
      final database = _MemoryScadaDatabase()..telemetryValue = scenario.value;
      final service = ScadaService(
        loadCurrentProfile: () async => operatorProfile,
        database: database,
        clock: () => testNow,
      );

      final commandId = await service.sendLbsCommand(
        target: ScadaService.lbsTarget,
        action: 'OPEN',
      );

      expect(commandId, 'generated-command-id', reason: scenario.key);
      expect(database.createCount, 1, reason: scenario.key);
      expect(database.watchTelemetryCount, 0, reason: scenario.key);
      expect(database.savedCommand, containsPair('status', 'PENDING'));
    }
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

  test('watch activity stream supports repeated subscriptions', () async {
    final database = _MemoryScadaDatabase()
      ..activityValue = {'command_id': 'multi-listener'};

    final service = ScadaService(
      loadCurrentProfile: () async => managerProfile,
      database: database,
    );

    final activityStream = service.watchActivity();

    expect(
      await activityStream.first,
      containsPair('command_id', 'multi-listener'),
    );

    expect(
      await activityStream.first,
      containsPair('command_id', 'multi-listener'),
    );
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
    expect(telemetry.lruReceivedAt, 0);
    expect(telemetry.comReceivedAt, 0);
    expect(result.status, CommandResultStatus.succeeded);
    expect(result.commandId, 'command-1');
  });

  test(
      'detects stale telemetry using the control-readiness timestamp boundaries',
      () {
    ScadaTelemetry telemetryAt(int receivedAt) {
      return ScadaTelemetry.fromValue(
        'LBS_01',
        _healthyTelemetry(testNow, receivedAt: receivedAt),
      );
    }

    expect(telemetryAt(0).isStaleAt(testNow), isTrue);
    expect(telemetryAt(testNow + 5000).isStaleAt(testNow), isFalse);
    expect(telemetryAt(testNow + 5001).isStaleAt(testNow), isTrue);
    expect(telemetryAt(testNow - 15000).isStaleAt(testNow), isFalse);
    expect(telemetryAt(testNow - 15001).isStaleAt(testNow), isTrue);
  });
  test('parses an indeterminate command result without calling it successful',
      () {
    final result = ScadaCommandResult.fromValue('command-2', {
      'command_id': 'command-2',
      'status': 'INDETERMINATE',
      'dispatch_state': 'interrupted',
      'updated_at': 1200,
      'detail': 'Delivery and physical position are unknown.',
    });

    expect(result.status, CommandResultStatus.indeterminate);
    expect(result.dispatchState, 'interrupted');
    expect(
      result.operatorStateLabel,
      'INDETERMINATE · DELIVERY TIDAK PASTI',
    );
    expect(
      result.operatorSafetyNote,
      contains('Jangan kirim ulang otomatis.'),
    );
    expect(result.status, isNot(CommandResultStatus.succeeded));
  });

  test('parses dry-run result as validated but not published', () {
    final result = ScadaCommandResult.fromValue('command-dry-run', {
      'command_id': 'command-dry-run',
      'status': 'RECEIVED',
      'dispatch_state': 'dry_run',
      'updated_at': 1300,
      'detail': 'No MQTT control message was published.',
    });

    expect(result.status, CommandResultStatus.received);
    expect(result.dispatchState, 'dry_run');
    expect(result.operatorStateLabel, 'RECEIVED · DRY-RUN');
    expect(
      result.operatorSafetyNote,
      contains('tidak ada perintah kontrol yang dipublikasikan ke MQTT'),
    );
  });

  test('legacy command result without dispatch_state stays unknown', () {
    final result = ScadaCommandResult.fromValue('command-legacy', {
      'command_id': 'command-legacy',
      'status': 'RECEIVED',
      'updated_at': 1400,
      'detail': 'Legacy result without dispatch state.',
    });

    expect(result.dispatchState, 'unknown');
    expect(
      result.operatorStateLabel,
      'RECEIVED · DISPATCH STATE UNKNOWN',
    );
    expect(
      result.operatorSafetyNote,
      contains('tidak membuktikan perintah telah dikirim'),
    );
  });

  test('rejects unsupported command dispatch state', () {
    expect(
      () => ScadaCommandResult.fromValue('command-invalid-state', {
        'command_id': 'command-invalid-state',
        'status': 'EXECUTING',
        'dispatch_state': 'physical_success',
        'updated_at': 1500,
        'detail': 'Invalid dispatch state.',
      }),
      throwsFormatException,
    );
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

Map<String, Object?> _healthyTelemetry(
  int nowMs, {
  int? receivedAt,
  int quality = 0,
  String lruStatus = 'NORMAL',
  int? lruReceivedAt,
  String comStatus = 'NORMAL',
  int? comReceivedAt,
}) {
  return {
    'device_id': 'LBS_01',
    'timestamp': nowMs,
    'device_ts_ms': nowMs - 10,
    'received_at': receivedAt ?? nowMs,
    'v_sumber': 220.0,
    'v_beban': 219.0,
    'i_sumber': 0.0,
    'i_beban': 0.0,
    'kualitas': quality,
    'status_lru': lruStatus,
    'status_lru_received_at': lruReceivedAt ?? (nowMs - 120000),
    'status_com': comStatus,
    'status_com_received_at': comReceivedAt ?? nowMs,
    'status_lbs': 'UNKNOWN',
  };
}

class _MemoryScadaDatabase implements ScadaDatabase {
  bool connected = true;
  int createCount = 0;
  int watchTelemetryCount = 0;
  Map<String, Object?>? savedCommand;
  Object? commandsValue;
  Object? commandResultValue;
  Object? activityValue;
  Object? telemetryValue;

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
  Stream<Object?> watchTelemetry(String deviceId) {
    watchTelemetryCount++;
    return Stream<Object?>.value(telemetryValue);
  }
}
