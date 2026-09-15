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
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/sensor_data.dart';

class FirebaseService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  User? get userSaatIni => _auth.currentUser;

  Future<UserRole?> login(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
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
