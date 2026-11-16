import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:scada_mizan_app/models/sensor_data.dart';
import 'package:scada_mizan_app/models/user_profile.dart';
import 'package:scada_mizan_app/screens/kontrol_monitoring_lbs_screen.dart';
import 'package:scada_mizan_app/services/firebase_service.dart';
import 'package:scada_mizan_app/services/scada_service.dart';

const _testNow = 1700000000000;

const _operatorProfile = UserProfile(
  uid: 'operator-test',
  displayName: 'Test Operator',
  role: UserRole.operator,
  isActive: true,
);

const _managerProfile = UserProfile(
  uid: 'manager-test',
  displayName: 'Test Manager',
  role: UserRole.manager,
  isActive: true,
);

void main() {
  testWidgets('active Operator can log a request when telemetry is unavailable',
      (tester) async {
    final database = _MemoryScadaDatabase(telemetryValue: null);

    await _pumpLbsScreen(
      tester,
      profile: _operatorProfile,
      database: database,
      clock: () => _testNow,
    );

    expect(_buttonEnabled(tester, 'OPEN'), isTrue);
    expect(_buttonEnabled(tester, 'CLOSE'), isTrue);
    expect(find.text('Telemetry belum tersedia.'), findsOneWidget);
  });

  testWidgets('healthy telemetry enables controls for active Operator',
      (tester) async {
    final database = _MemoryScadaDatabase(
      telemetryValue: _healthyTelemetry(_testNow),
    );

    await _pumpLbsScreen(
      tester,
      profile: _operatorProfile,
      database: database,
      clock: () => _testNow,
    );

    expect(_buttonEnabled(tester, 'OPEN'), isTrue);
    expect(_buttonEnabled(tester, 'CLOSE'), isTrue);
    expect(find.text('Telemetry stale'), findsNothing);
  });

  testWidgets('LRU FAIL does not block Firebase request logging', (tester) async {
    final database = _MemoryScadaDatabase(
      telemetryValue: _healthyTelemetry(
        _testNow,
        lruStatus: 'FAIL',
      ),
    );

    await _pumpLbsScreen(
      tester,
      profile: _operatorProfile,
      database: database,
      clock: () => _testNow,
    );

    expect(_buttonEnabled(tester, 'OPEN'), isTrue);
    expect(_buttonEnabled(tester, 'CLOSE'), isTrue);
    expect(find.text('Status LRU bukan NORMAL (FAIL).'), findsOneWidget);
  });

  testWidgets('LRU UNKNOWN does not block Firebase request logging', (tester) async {
    final database = _MemoryScadaDatabase(
      telemetryValue: _healthyTelemetry(
        _testNow,
        lruStatus: 'UNKNOWN',
      ),
    );

    await _pumpLbsScreen(
      tester,
      profile: _operatorProfile,
      database: database,
      clock: () => _testNow,
    );

    expect(_buttonEnabled(tester, 'OPEN'), isTrue);
    expect(_buttonEnabled(tester, 'CLOSE'), isTrue);
    expect(
      find.text('Status LRU bukan NORMAL (UNKNOWN).'),
      findsOneWidget,
    );
  });

  testWidgets('non-GOOD sensor quality does not block Firebase request logging',
      (tester) async {
    final database = _MemoryScadaDatabase(
      telemetryValue: _healthyTelemetry(
        _testNow,
        quality: 1,
      ),
    );

    await _pumpLbsScreen(
      tester,
      profile: _operatorProfile,
      database: database,
      clock: () => _testNow,
    );

    expect(_buttonEnabled(tester, 'OPEN'), isTrue);
    expect(_buttonEnabled(tester, 'CLOSE'), isTrue);
    expect(
      find.text('Kualitas data sensor bukan GOOD (quality=1).'),
      findsOneWidget,
    );
  });
  testWidgets('COM FAIL does not block Firebase request logging', (tester) async {
    final database = _MemoryScadaDatabase(
      telemetryValue: _healthyTelemetry(
        _testNow,
        comStatus: 'FAIL',
      ),
    );

    await _pumpLbsScreen(
      tester,
      profile: _operatorProfile,
      database: database,
      clock: () => _testNow,
    );

    expect(_buttonEnabled(tester, 'OPEN'), isTrue);
    expect(_buttonEnabled(tester, 'CLOSE'), isTrue);
    expect(find.text('Status COM bukan NORMAL (FAIL).'), findsOneWidget);
  });

  testWidgets(
      'expired COM heartbeat does not block Firebase request logging',
      (tester) async {
    var currentTime = _testNow;

    final database = _MemoryScadaDatabase(liveTelemetry: true);

    addTearDown(database.close);

    await _pumpLbsScreen(
      tester,
      profile: _operatorProfile,
      database: database,
      clock: () => currentTime,
    );

    expect(database.hasTelemetryListener, isTrue);

    database.emitTelemetry(_healthyTelemetry(_testNow));
    await tester.pump();

    expect(_buttonEnabled(tester, 'OPEN'), isTrue);
    expect(_buttonEnabled(tester, 'CLOSE'), isTrue);

    // At 14 seconds, both sensor telemetry and COM are still fresh.
    currentTime = _testNow + 14000;
    await tester.pump(const Duration(seconds: 1));

    expect(_buttonEnabled(tester, 'OPEN'), isTrue);
    expect(_buttonEnabled(tester, 'CLOSE'), isTrue);

    // Sensor data is refreshed, but COM heartbeat retains its old timestamp.
    currentTime = _testNow + 16000;

    database.emitTelemetry(
      _healthyTelemetry(
        currentTime,
        comReceivedAt: _testNow,
      ),
    );

    // Before the next clock tick, the last evaluated time is still 14 seconds.
    await tester.pump();

    expect(_buttonEnabled(tester, 'OPEN'), isTrue);
    expect(_buttonEnabled(tester, 'CLOSE'), isTrue);

    // The periodic clock now evaluates the 16-second-old COM heartbeat.
    await tester.pump(const Duration(seconds: 1));

    expect(_buttonEnabled(tester, 'OPEN'), isTrue);
    expect(_buttonEnabled(tester, 'CLOSE'), isTrue);
    expect(
      find.text('Heartbeat COM belum tersedia atau sudah kedaluwarsa.'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('COM FAIL request is recorded in Firebase without physical operation', (tester) async {
    final database = _MemoryScadaDatabase(
      telemetryValue: _healthyTelemetry(
        _testNow,
        comStatus: 'FAIL',
      ),
    );

    await _pumpLbsScreen(
      tester,
      profile: _operatorProfile,
      database: database,
      clock: () => _testNow,
    );

    await _submitOpenCommand(tester);

    expect(database.createCount, 1);
    expect(database.savedCommand, containsPair('target', 'LBS_01'));
    expect(database.savedCommand, containsPair('action', 'OPEN'));
    expect(find.textContaining('Tercatat di Firebase'), findsWidgets);
    expect(find.textContaining('Mode DRY-RUN: Firebase mencatat'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('dry-run result is displayed as not published to MQTT',
      (tester) async {
    final database = _MemoryScadaDatabase(
      telemetryValue: _healthyTelemetry(_testNow),
      commandResultValue: {
        'command_id': 'widget-test-command',
        'status': 'RECEIVED',
        'dispatch_state': 'dry_run',
        'updated_at': _testNow,
        'detail': 'DRY-RUN: request validated; no MQTT publish.',
      },
    );

    await _pumpLbsScreen(
      tester,
      profile: _operatorProfile,
      database: database,
      clock: () => _testNow,
    );

    await _submitOpenCommand(tester);

    expect(database.createCount, 1);
    expect(find.textContaining('RECEIVED · DRY-RUN'), findsOneWidget);
    expect(
      find.textContaining(
        'tidak ada perintah kontrol yang dipublikasikan ke MQTT',
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('indeterminate result warns operator not to retry automatically',
      (tester) async {
    final database = _MemoryScadaDatabase(
      telemetryValue: _healthyTelemetry(_testNow),
      commandResultValue: {
        'command_id': 'widget-test-command',
        'status': 'INDETERMINATE',
        'dispatch_state': 'interrupted',
        'updated_at': _testNow,
        'detail': 'MQTT publish outcome is uncertain.',
      },
    );

    await _pumpLbsScreen(
      tester,
      profile: _operatorProfile,
      database: database,
      clock: () => _testNow,
    );

    await _submitOpenCommand(tester);

    expect(database.createCount, 1);
    expect(
      find.textContaining('INDETERMINATE · DELIVERY TIDAK PASTI'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Jangan kirim ulang otomatis.'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Manager cannot operate OPEN or CLOSE buttons', (tester) async {
    final database = _MemoryScadaDatabase(
      telemetryValue: _healthyTelemetry(_testNow),
    );

    await _pumpLbsScreen(
      tester,
      profile: _managerProfile,
      database: database,
      clock: () => _testNow,
    );

    expect(_buttonEnabled(tester, 'OPEN'), isFalse);
    expect(_buttonEnabled(tester, 'CLOSE'), isFalse);
    expect(
      find.text(
        'Hanya operator aktif yang dapat mengirim permintaan kontrol.',
      ),
      findsOneWidget,
    );
  });
}

Future<void> _submitOpenCommand(WidgetTester tester) async {
  final openButton = find.widgetWithText(ElevatedButton, 'OPEN');

  expect(openButton, findsOneWidget);
  expect(tester.widget<ElevatedButton>(openButton).onPressed, isNotNull);

  await tester.tap(openButton);
  await tester.pumpAndSettle();

  expect(find.text('Konfirmasi Permintaan'), findsOneWidget);

  await tester.tap(find.text('Catat permintaan'));
  await tester.pumpAndSettle();
}

bool _buttonEnabled(WidgetTester tester, String label) {
  final finder = find.widgetWithText(ElevatedButton, label);

  expect(finder, findsOneWidget);

  return tester.widget<ElevatedButton>(finder).onPressed != null;
}

Map<String, Object?> _healthyTelemetry(
  int nowMs, {
  String lruStatus = 'NORMAL',
  String comStatus = 'NORMAL',
  int quality = 0,
  int? lruReceivedAt,
  int? comReceivedAt,
}) {
  return {
    'device_id': 'LBS_01',
    'timestamp': nowMs,
    'device_ts_ms': nowMs - 100,
    'received_at': nowMs,
    'v_sumber': 220.0,
    'v_beban': 219.0,
    'i_sumber': 0.0,
    'i_beban': 0.0,
    'kualitas': quality,
    'status_lru': lruStatus,
    'status_lru_received_at': lruReceivedAt ?? nowMs - 120000,
    'status_com': comStatus,
    'status_com_received_at': comReceivedAt ?? nowMs,
    'status_lbs': 'UNKNOWN',
  };
}

Future<void> _pumpLbsScreen(
  WidgetTester tester, {
  required UserProfile profile,
  required _MemoryScadaDatabase database,
  required int Function() clock,
}) async {
  final fakeFirebase = _FakeFirebaseService(profile);
  addTearDown(fakeFirebase.dispose);

  final scada = ScadaService(
    loadCurrentProfile: () async => profile,
    database: database,
    clock: clock,
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<FirebaseService>.value(
          value: fakeFirebase,
        ),
        Provider<ScadaService>.value(
          value: scada,
        ),
      ],
      child: MaterialApp(
        home: KontrolMonitoringLbsScreen(clock: clock),
      ),
    ),
  );

  // Flush profile authorization and telemetry stream subscription.
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

class _FakeFirebaseService extends ChangeNotifier implements FirebaseService {
  _FakeFirebaseService(this._profile);

  final UserProfile? _profile;

  @override
  UserProfile? get profilSaatIni => _profile;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryScadaDatabase implements ScadaDatabase {
  _MemoryScadaDatabase({
    this.telemetryValue,
    this.commandResultValue,
    this.liveTelemetry = false,
  });

  bool connected = true;
  int createCount = 0;
  Map<String, Object?>? savedCommand;

  Object? telemetryValue;
  Object? commandResultValue;
  final bool liveTelemetry;
  StreamController<Object?>? _updates;

  bool get hasTelemetryListener => _updates?.hasListener ?? false;

  @override
  Future<bool> isConnected() async => connected;

  @override
  Future<String> createCommand(Map<String, Object?> command) async {
    createCount++;
    savedCommand = command;
    return 'widget-test-command';
  }

  @override
  Stream<Object?> watchCommands() => Stream<Object?>.value(null);

  @override
  Stream<Object?> watchTelemetry(String deviceId) {
    if (!liveTelemetry) {
      return Stream<Object?>.value(telemetryValue);
    }

    _updates ??= StreamController<Object?>.broadcast(sync: true);
    return _updates!.stream;
  }

  void emitTelemetry(Object? value) {
    if (_updates == null || !_updates!.hasListener) {
      throw StateError('Widget belum berlangganan telemetry stream.');
    }
    _updates!.add(value);
  }

  Future<void> close() async {
    await _updates?.close();
  }

  @override
  Stream<Object?> watchCommandResult(String commandId) =>
      Stream<Object?>.value(commandResultValue);

  @override
  Stream<Object?> watchActivity() => Stream<Object?>.value(null);
}
