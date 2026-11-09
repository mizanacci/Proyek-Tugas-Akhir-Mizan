import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../config/firebase_config.dart';
import '../models/scada_data.dart';
import '../models/sensor_data.dart';
import '../models/user_profile.dart';

typedef CurrentProfileLoader = Future<UserProfile?> Function();

abstract interface class ScadaDatabase {
  Future<bool> isConnected();
  Future<String> createCommand(Map<String, Object?> command);
  Stream<Object?> watchCommands();
  Stream<Object?> watchTelemetry(String deviceId);
  Stream<Object?> watchCommandResult(String commandId);
  Stream<Object?> watchActivity();
}

class FirebaseScadaDatabase implements ScadaDatabase {
  final DatabaseReference _root;

  FirebaseScadaDatabase()
      : _root = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: firebaseDatabaseUrl,
        ).ref();

  @override
  Future<bool> isConnected() async {
    final event = await _root
        .child('.info/connected')
        .onValue
        .first
        .timeout(const Duration(seconds: 5));
    return event.snapshot.value == true;
  }

  @override
  Future<String> createCommand(Map<String, Object?> command) async {
    final reference = _root.child('commands').push();
    final commandId = reference.key;
    if (commandId == null) {
      throw const ScadaServiceException('Firebase gagal membuat command ID.');
    }
    await reference.set(command);
    return commandId;
  }

  @override
  Stream<Object?> watchCommands() => _root
      .child('commands')
      .orderByChild('created_at')
      .limitToLast(50)
      .onValue
      .map((event) => event.snapshot.value);

  @override
  Stream<Object?> watchTelemetry(String deviceId) {
    return _root
        .child('telemetry/$deviceId')
        .orderByChild('timestamp')
        .limitToLast(1)
        .onValue
        .map((event) {
      final value = event.snapshot.value;
      if (value is! Map || value.isEmpty) return null;
      return Map<dynamic, dynamic>.from(value).values.single;
    });
  }

  @override
  Stream<Object?> watchCommandResult(String commandId) =>
      _root.child('command_results/$commandId').onValue.map(
            (event) => event.snapshot.value,
          );

  @override
  Stream<Object?> watchActivity() {
    return _root
        .child('data_activity')
        .orderByChild('timestamp')
        .limitToLast(100)
        .onValue
        .map((event) => event.snapshot.value);
  }
}

class ScadaServiceException implements Exception {
  final String message;
  const ScadaServiceException(this.message);

  @override
  String toString() => message;
}

class ScadaService {
  static const String lbsTarget = 'LBS_01';

  final CurrentProfileLoader _loadCurrentProfile;
  final ScadaDatabase _database;

  ScadaService({
    required CurrentProfileLoader loadCurrentProfile,
    ScadaDatabase? database,
  })  : _loadCurrentProfile = loadCurrentProfile,
        _database = database ?? FirebaseScadaDatabase();

  Future<String> sendLbsCommand({
    required String target,
    required String action,
  }) async {
    final profile = await _loadCurrentProfile();
    validateCommand(profile: profile, target: target, action: action);
    if (!await _database.isConnected()) {
      throw const ScadaServiceException(
        'Realtime Database tidak terhubung; permintaan tidak dikirim.',
      );
    }

    return _database.createCommand(buildCommandRecord(
      profile: profile!,
      target: target,
      action: action,
    ));
  }

  Stream<ScadaTelemetry?> watchTelemetry(String deviceId) {
    if (deviceId != lbsTarget) {
      throw const ScadaServiceException('Target telemetry tidak dikenal.');
    }
    return _authorizedRead(_database.watchTelemetry(deviceId)).map(
      (value) =>
          value == null ? null : ScadaTelemetry.fromValue(deviceId, value),
    );
  }

  Stream<ScadaCommandResult?> watchCommandResult(String commandId) {
    if (commandId.isEmpty) {
      throw const ScadaServiceException('Command ID tidak valid.');
    }
    return _authorizedRead(_database.watchCommandResult(commandId)).map(
      (value) =>
          value == null ? null : ScadaCommandResult.fromValue(commandId, value),
    );
  }

  Stream<List<ScadaCommand>> watchCommands() {
    return _authorizedRead(_database.watchCommands()).map((value) {
      if (value == null) return const <ScadaCommand>[];
      if (value is! Map) {
        throw const FormatException('Commands node must be an object.');
      }
      final commands = Map<dynamic, dynamic>.from(value)
          .entries
          .map((entry) => ScadaCommand.fromEntry(
                entry.key.toString(),
                entry.value,
              ))
          .toList()
        ..sort((first, second) => second.createdAt.compareTo(first.createdAt));
      return commands;
    });
  }

  Stream<Object?> watchActivity() => _authorizedRead(_database.watchActivity());

  Stream<Object?> _authorizedRead(Stream<Object?> source) async* {
    final profile = await _loadCurrentProfile();
    if (profile == null || !profile.isActive) {
      throw const ScadaServiceException(
        'Profil aktif diperlukan untuk membaca data.',
      );
    }
    yield* source;
  }

  @visibleForTesting
  static void validateCommand({
    required UserProfile? profile,
    required String target,
    required String action,
  }) {
    if (profile == null || !profile.isActive) {
      throw const ScadaServiceException('Login aktif diperlukan.');
    }
    if (profile.role != UserRole.operator) {
      throw const ScadaServiceException(
        'Hanya operator aktif yang dapat mengirim permintaan kontrol.',
      );
    }
    if (target != lbsTarget) {
      throw const ScadaServiceException('Target LBS tidak valid.');
    }
    if (action != 'OPEN' && action != 'CLOSE') {
      throw const ScadaServiceException('Action hanya boleh OPEN atau CLOSE.');
    }
  }

  @visibleForTesting
  static Map<String, Object?> buildCommandRecord({
    required UserProfile profile,
    required String target,
    required String action,
  }) {
    validateCommand(profile: profile, target: target, action: action);
    return {
      'target': target,
      'action': action,
      'created_at': ServerValue.timestamp,
      'created_by_uid': profile.uid,
      'created_by_name': profile.displayName,
      'status': 'PENDING',
    };
  }
}
