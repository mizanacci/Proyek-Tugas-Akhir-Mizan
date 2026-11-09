/// Firebase Authentication, active-profile validation, and RTDB reads.
/// Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)
///
/// Writes for telemetry, activity, command results, and settings are owned by
/// the backend or project owner. Legacy write methods below fail closed.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../config/firebase_config.dart';
import '../models/sensor_data.dart';
import '../models/user_profile.dart';

class FirebaseService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: firebaseDatabaseUrl,
  );
  late final DatabaseReference _db = _database.ref();
  late final Stream<bool> _koneksiDatabase = _db
      .child('.info/connected')
      .onValue
      .map((event) => event.snapshot.value == true);
  UserProfile? _currentProfile;
  int _loginGeneration = 0;
  String? _pesanLoginTerakhir;

  User? get userSaatIni => _auth.currentUser;
  UserProfile? get profilSaatIni => _currentProfile;
  String? get pesanLoginTerakhir => _pesanLoginTerakhir;

  Stream<User?> get perubahanUser => _auth.authStateChanges();
  Stream<bool> get koneksiDatabase => _koneksiDatabase;

  Future<UserCredential> loginDenganEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(
        code: e.code,
        message: pesanErrorAuth(e),
      );
    }
  }

  static String pesanErrorAuth(FirebaseAuthException error) {
    switch (error.code) {
      case 'weak-password':
        return 'Password terlalu lemah. Gunakan minimal 6 karakter.';
      case 'email-already-in-use':
        return 'Email sudah digunakan oleh akun lain.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email atau password salah.';
      case 'user-disabled':
        return 'Akun ini telah dinonaktifkan.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi nanti.';
      default:
        return error.message ?? 'Operasi autentikasi gagal.';
    }
  }

  Future<UserRole?> login(String email, String password) async {
    final generation = ++_loginGeneration;
    _currentProfile = null;
    notifyListeners();
    _pesanLoginTerakhir = null;
    try {
      final cred = await loginDenganEmail(email, password);
      final uid = cred.user?.uid;
      if (uid == null) {
        _pesanLoginTerakhir =
            'Firebase Authentication tidak mengembalikan UID.';
        return null;
      }

      final profile = await profileUntukUid(uid);
      if (generation != _loginGeneration || _auth.currentUser?.uid != uid) {
        return null;
      }
      if (profile == null) {
        _pesanLoginTerakhir =
            'Login ditolak: profil UID tidak valid, akun tidak aktif, atau role '
            'bukan manager/operator. Minta admin memeriksa profil pengguna.';
        debugPrint('[Firebase] Login ditolak: profil tidak aktif/valid.');
        await _auth.signOut();
        return null;
      }
      _currentProfile = profile;
      notifyListeners();
      return profile.role;
    } on FirebaseAuthException catch (e) {
      _pesanLoginTerakhir = pesanErrorAuth(e);
      debugPrint('[Firebase] Login gagal: ${e.code}');
      return null;
    } on FirebaseException catch (e) {
      _pesanLoginTerakhir =
          'Autentikasi berhasil, tetapi profil Firebase tidak dapat dibaca. '
          'Periksa RTDB URL dan Rules (${e.code}).';
      debugPrint(
          '[Firebase] Login gagal saat membaca profil: ${e.code} - ${e.message}');
      await _auth.signOut();
      return null;
    }
  }

  /// Role hanya sah bila profil Admin telah menetapkan nilai eksplisit.
  /// Profil hilang atau role tak dikenal tidak pernah dipetakan otomatis ke operator.
  @visibleForTesting
  static UserRole? roleDariNilai(dynamic value) {
    if (value is! String) return null;
    return switch (value) {
      'manager' => UserRole.manager,
      'operator' => UserRole.operator,
      _ => null,
    };
  }

  Future<UserProfile?> getCurrentProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final profile = await profileUntukUid(uid);
    if (_auth.currentUser?.uid != uid) return null;
    _currentProfile = profile;
    notifyListeners();
    return profile;
  }

  Future<UserProfile?> profileUntukUid(String uid) async {
    if (_auth.currentUser?.uid != uid) return null;
    final snapshot = await _db.child('users/$uid').get();
    if (!snapshot.exists) return null;
    return UserProfile.tryParse(uid: uid, value: snapshot.value);
  }

  Future<UserRole?> roleUntukUid(String uid) async =>
      (await profileUntukUid(uid))?.role;

  Future<void> logout() async {
    _loginGeneration++;
    _currentProfile = null;
    await _auth.signOut();
    notifyListeners();
  }

  /// Stream entri Data Activity terbaru (untuk layar Data Activity),
  /// diurutkan berdasarkan waktu, dibatasi jumlah agar hemat kuota Spark plan.
  Stream<DatabaseEvent> streamDataActivity({int batas = 100}) {
    return _db
        .child('data_activity')
        .orderByChild('timestamp')
        .limitToLast(batas)
        .onValue
        .map((event) => event);
  }

  @Deprecated('Activity records are written by the backend.')
  Future<void> catatEvent({
    required String jenis,
    required String keterangan,
    String? kodeUnik,
  }) =>
      _denyClientWrite('/data_activity');

  @Deprecated('Activity records are written by the backend.')
  Future<void> catatDataActivity({
    required String aksi,
    required String sumber,
  }) =>
      _denyClientWrite('/data_activity');

  @Deprecated('Telemetry is written by the backend.')
  Future<void> catatSnapshotScada({
    required SensorData data,
    required DateTime diterimaPada,
    required String statusLru,
    required String statusCom,
    required String statusLbs,
  }) =>
      _denyClientWrite('/telemetry');

  @Deprecated('Use ScadaService.sendLbsCommand for operator requests.')
  Future<void> tulisScadaData(Map<String, dynamic> nilai) =>
      _denyClientWrite('/scada_data');

  @Deprecated('Firebase write tests must run against an approved emulator.')
  Future<String> ujiTulisDatabase() =>
      Future<String>.error(UnsupportedError('Client write-test is disabled.'));

  Future<DataSnapshot> bacaScadaData() => _db.child('scada_data').get();

  Stream<DatabaseEvent> streamScadaData() => _db.child('scada_data').onValue;

  Future<Map<String, dynamic>?> ambilThresholdAlarm() async {
    final snapshot = await _db.child('settings/threshold_alarm').get();
    if (!snapshot.exists || snapshot.value is! Map) return null;
    return Map<String, dynamic>.from(snapshot.value as Map);
  }

  @Deprecated('Settings are owner/backend managed.')
  Future<void> simpanThresholdAlarm(Map<String, dynamic> nilai) =>
      _denyClientWrite('/settings/threshold_alarm');

  Future<int?> ambilDurasiTimeout() async {
    final snapshot = await _db.child('settings/durasi_timeout').get();
    return snapshot.value is num ? (snapshot.value as num).toInt() : null;
  }

  @Deprecated('Settings are owner/backend managed.')
  Future<void> simpanDurasiTimeout(int detik) =>
      _denyClientWrite('/settings/durasi_timeout');

  Future<void> _denyClientWrite(String path) async {
    throw UnsupportedError('Client writes to $path are disabled.');
  }
}
