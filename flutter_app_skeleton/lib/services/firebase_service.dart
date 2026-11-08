/// firebase_service.dart — Wrapper Firebase Authentication + Realtime Database
/// Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)
///
/// Skema Realtime Database (lihat dokumen 05_Struktur_Workspace.md Bagian 3
/// untuk penjelasan lengkap):
///   /users/<uid>/{email, role, nama}
///   /data_activity/<pushId>/{timestamp, jenis, keterangan, oleh_uid, oleh_nama, sumber}
///   /settings/threshold_alarm/{tegangan_min, tegangan_max, arus_max}
///   /settings/durasi_timeout
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/sensor_data.dart';

class FirebaseService extends ChangeNotifier {
  static const _googleWebClientId =
      '458957628300-bb44js34pdarnr5httlvv2i8njol352t.apps.googleusercontent.com';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  late final Stream<bool> _koneksiDatabase = _db
      .child('.info/connected')
      .onValue
      .map((event) => event.snapshot.value == true);
  DateTime? _terakhirUpayaTulis;
  DateTime? _terakhirTulisBerhasil;
  bool? _hasilTulisTerakhir;
  String? _errorTerakhirDatabase;
  int _jumlahSnapshotBerhasil = 0;
  int _jumlahCatatanStreamTerakhir = 0;

  User? get userSaatIni => _auth.currentUser;
  DateTime? get terakhirUpayaTulis => _terakhirUpayaTulis;
  DateTime? get terakhirTulisBerhasil => _terakhirTulisBerhasil;
  bool? get hasilTulisTerakhir => _hasilTulisTerakhir;
  String? get errorTerakhirDatabase => _errorTerakhirDatabase;
  int get jumlahSnapshotBerhasil => _jumlahSnapshotBerhasil;
  int get jumlahCatatanStreamTerakhir => _jumlahCatatanStreamTerakhir;

  Stream<User?> get perubahanUser => _auth.authStateChanges();
  Stream<bool> get koneksiDatabase => _koneksiDatabase;

  Future<UserCredential> daftarDenganEmail(
      String email, String password) async {
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
      return await roleUntukUid(uid);
    } on FirebaseAuthException catch (e) {
      debugPrint('[Firebase] Login gagal: ${e.code}');
      return null;
    } on FirebaseException catch (e) {
      debugPrint(
          '[Firebase] Login gagal saat membaca profil: ${e.code} - ${e.message}');
      return null;
    }
  }

  Future<UserRole> roleUntukUid(String uid) async {
    final snapshot = await _db.child('users/$uid').get();
    if (!snapshot.exists) {
      debugPrint(
          '[Firebase] Profil $uid tidak ditemukan; role default operator.');
      return UserRole.operator;
    }
    final data = snapshot.value;
    final roleValue = data is Map ? data['role'] : null;
    if (roleValue is! String) {
      debugPrint('[Firebase] Role $uid tidak valid; role default operator.');
      return UserRole.operator;
    }
    final role = roleValue.trim().toLowerCase();
    debugPrint('[Firebase] Role sesi dimuat: $role.');
    return role == 'manager' ? UserRole.manager : UserRole.operator;
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

  Future<void> catatEvent({
    required String jenis,
    required String keterangan,
    String? kodeUnik,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Pengguna belum login ke Firebase.');
    }

    String nama = 'Sistem';
    if (jenis == 'PERINTAH') {
      final namaSnapshot = await _db.child('users/${user.uid}/nama').get();
      nama = namaSnapshot.value as String? ??
          user.displayName ??
          user.email ??
          'tidak diketahui';
    }

    final data = {
      'timestamp': ServerValue.timestamp,
      'jenis': jenis,
      'keterangan': keterangan,
      'oleh_uid': user.uid,
      'oleh_nama': nama,
      'sumber': 'mobile',
    };

    final reference = kodeUnik == null
        ? _db.child('data_activity').push()
        : _db.child(
            'data_activity/evt_${DateTime.now().millisecondsSinceEpoch ~/ 1000}_$kodeUnik',
          );
    await _tulis(reference, data, path: 'data_activity', uid: user.uid);
  }

  /// Kompatibilitas pemanggil lama untuk pencatatan perintah NO/NC.
  Future<void> catatDataActivity({
    required String aksi,
    required String sumber,
  }) async {
    await catatEvent(
      jenis: 'PERINTAH',
      keterangan: 'Perintah $aksi dikirim',
    );
  }

  Future<void> catatSnapshotScada({
    required SensorData data,
    required DateTime diterimaPada,
    required String statusLru,
    required String statusCom,
    required String statusLbs,
  }) async {
    _terakhirUpayaTulis = DateTime.now();
    _hasilTulisTerakhir = null;
    final user = _auth.currentUser;
    if (user == null) {
      _hasilTulisTerakhir = false;
      _errorTerakhirDatabase = 'Pengguna belum login ke Firebase.';
      throw StateError('Pengguna belum login ke Firebase.');
    }

    final dataSnapshot = {
      'timestamp': ServerValue.timestamp,
      'device_ts_ms': data.timestampMs,
      'received_at': diterimaPada.millisecondsSinceEpoch,
      'jenis': 'SCADA_UPDATE',
      'keterangan': 'Pembaruan data SCADA otomatis setiap 10 detik',
      'oleh_uid': user.uid,
      'oleh_nama': 'Sistem',
      'sumber': 'mqtt',
      'v_sumber': data.teganganSumber,
      'v_beban': data.teganganBeban,
      'i_sumber': data.arusSumber,
      'i_beban': data.arusBeban,
      'kualitas': data.bitmaskKualitas,
      'status_lru': statusLru,
      'status_com': statusCom,
      'status_lbs': statusLbs,
    };

    try {
      debugPrint('[Firebase] WRITE STARTED path=data_activity uid=${user.uid}');
      await _db.child('data_activity').push().set(dataSnapshot);
      _hasilTulisTerakhir = true;
      _errorTerakhirDatabase = null;
      _jumlahSnapshotBerhasil++;
      _terakhirTulisBerhasil = DateTime.now();
      notifyListeners();
      debugPrint('[Firebase] WRITE SUCCESS path=data_activity uid=${user.uid}');
    } on FirebaseException catch (error) {
      _hasilTulisTerakhir = false;
      _errorTerakhirDatabase =
          'Firebase ${error.code}: ${error.message ?? 'tanpa pesan'}';
      notifyListeners();
      debugPrint('[Firebase] WRITE FAILED code=${error.code} '
          'path=data_activity uid=${user.uid}');
      rethrow;
    } catch (error) {
      _hasilTulisTerakhir = false;
      _errorTerakhirDatabase = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<String> ujiTulisDatabase() async {
    if (!kDebugMode) {
      throw StateError('Tes tulis Firebase hanya tersedia pada mode debug.');
    }
    final user = _auth.currentUser;
    if (user == null) throw StateError('Pengguna belum login ke Firebase.');

    final reference = _db.child('data_activity').push();
    final data = {
      'timestamp': ServerValue.timestamp,
      'jenis': 'STATUS',
      'keterangan': 'FIREBASE_WRITE_TEST',
      'oleh_uid': user.uid,
      'oleh_nama': 'Development test',
      'sumber': 'mobile',
    };
    debugPrint('[Firebase Test] Authentication OK uid=${user.uid}');
    debugPrint('[Firebase Test] WRITE STARTED path=data_activity');
    await _tulis(reference, data, path: 'data_activity', uid: user.uid);
    debugPrint('[Firebase Test] WRITE SUCCESS record=${reference.key}');
    return reference.key!;
  }

  Future<void> _tulis(
    DatabaseReference reference,
    Map<String, dynamic> data, {
    required String path,
    required String uid,
  }) async {
    _terakhirUpayaTulis = DateTime.now();
    _hasilTulisTerakhir = null;
    try {
      debugPrint('[Firebase] WRITE STARTED path=$path uid=$uid');
      await reference.set(data);
      _hasilTulisTerakhir = true;
      _errorTerakhirDatabase = null;
      _terakhirTulisBerhasil = DateTime.now();
      notifyListeners();
      debugPrint('[Firebase] WRITE SUCCESS path=$path uid=$uid');
    } on FirebaseException catch (error) {
      _hasilTulisTerakhir = false;
      _errorTerakhirDatabase =
          'Firebase ${error.code}: ${error.message ?? 'tanpa pesan'}';
      notifyListeners();
      debugPrint('[Firebase] WRITE FAILED code=${error.code} '
          'path=$path uid=$uid');
      rethrow;
    } catch (error) {
      _hasilTulisTerakhir = false;
      _errorTerakhirDatabase = error.toString();
      notifyListeners();
      debugPrint('[Firebase] WRITE FAILED path=$path uid=$uid: $error');
      rethrow;
    }
  }

  /// Stream entri Data Activity terbaru (untuk layar Data Activity),
  /// diurutkan berdasarkan waktu, dibatasi jumlah agar hemat kuota Spark plan.
  Stream<DatabaseEvent> streamDataActivity({int batas = 100}) {
    return _db
        .child('data_activity')
        .orderByChild('timestamp')
        .limitToLast(batas)
        .onValue
        .map((event) {
      final value = event.snapshot.value;
      _jumlahCatatanStreamTerakhir = value is Map ? value.length : 0;
      debugPrint(
        '[Firebase] Stream data_activity menerima '
        '$_jumlahCatatanStreamTerakhir catatan.',
      );
      return event;
    });
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
