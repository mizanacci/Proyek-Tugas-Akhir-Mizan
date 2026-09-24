/// firebase_service.dart — Wrapper Firebase Authentication + Realtime Database
/// Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)
///
/// Skema Realtime Database (lihat dokumen 05_Struktur_Workspace.md Bagian 3
/// untuk penjelasan lengkap):
///   /users/<uid>/{email, role, nama}
///   /data_activity/<pushId>/{timestamp, aksi, oleh_uid, oleh_nama, sumber}
///   /settings/threshold_alarm/{tegangan_min, tegangan_max, arus_max}
///   /settings/durasi_timeout

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/sensor_data.dart';

class FirebaseService extends ChangeNotifier {
  static const _googleWebClientId =
      '458957628300-bb44js34pdarnr5httlvv2i8njol352t.apps.googleusercontent.com';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://scada-mizan-ta-default-rtdb.asia-southeast1.firebasedatabase.app',
  ).ref();

  User? get userSaatIni => _auth.currentUser;

  Stream<User?> get perubahanUser => _auth.authStateChanges();

  Future<UserCredential> daftarDenganEmail(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
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

  Future<UserCredential?> loginDenganGoogle() async {
    try {
      final akunGoogle = await GoogleSignIn(
        serverClientId: _googleWebClientId,
      ).signIn();
      if (akunGoogle == null) return null;

      final autentikasiGoogle = await akunGoogle.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: autentikasiGoogle.accessToken,
        idToken: autentikasiGoogle.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(
        code: e.code,
        message: pesanErrorAuth(e),
      );
    } catch (e) {
      throw Exception('Login Google gagal: $e');
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
    try {
      final cred = await loginDenganEmail(email, password);
      final uid = cred.user?.uid;
      if (uid == null) return null;

      final snapshot = await _db.child('users/$uid/role').get();
      if (!snapshot.exists) {
        debugPrint('[Firebase] User $uid tidak punya field role di database.');
        return null;
      }
      final roleStr = snapshot.value as String;
      return roleStr == 'manager' ? UserRole.manager : UserRole.operator;
    } on FirebaseAuthException catch (e) {
      debugPrint('[Firebase] Login gagal: ${e.code}');
      return null;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> tulisScadaData(Map<String, dynamic> nilai) async {
    await _db.child('scada_data').set(nilai);
  }

  Future<DataSnapshot> bacaScadaData() {
    return _db.child('scada_data').get();
  }

  Stream<DatabaseEvent> streamScadaData() {
    return _db.child('scada_data').onValue;
  }

  /// Mencatat satu entri Data Activity — dipanggil setiap kali Operator
  /// mengirim perintah NO/NC (lihat kontrol_monitoring_lbs_screen.dart).
  /// aksi: "NO" atau "NC". sumber: "mobile" (dari aplikasi ini).
  Future<void> catatDataActivity({
    required String aksi,
    required String sumber,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db.child('data_activity').push().set({
      'timestamp': ServerValue.timestamp,
      'aksi': aksi,
      'oleh_uid': user.uid,
      'oleh_nama': user.displayName ?? user.email ?? 'tidak diketahui',
      'sumber': sumber,
    });
  }

  /// Stream entri Data Activity terbaru (untuk layar Data Activity),
  /// diurutkan berdasarkan waktu, dibatasi jumlah agar hemat kuota Spark plan.
  Stream<DatabaseEvent> streamDataActivity({int batas = 50}) {
    return _db
        .child('data_activity')
        .orderByChild('timestamp')
        .limitToLast(batas)
        .onValue;
  }

  Future<Map<String, dynamic>?> ambilThresholdAlarm() async {
    final snapshot = await _db.child('settings/threshold_alarm').get();
    if (!snapshot.exists) return null;
    return Map<String, dynamic>.from(snapshot.value as Map);
  }

  Future<void> simpanThresholdAlarm(Map<String, dynamic> nilai) async {
    await _db.child('settings/threshold_alarm').set(nilai);
  }

  Future<int?> ambilDurasiTimeout() async {
    final snapshot = await _db.child('settings/durasi_timeout').get();
    if (!snapshot.exists) return null;
    return snapshot.value as int;
  }

  Future<void> simpanDurasiTimeout(int detik) async {
    await _db.child('settings/durasi_timeout').set(detik);
  }
}
