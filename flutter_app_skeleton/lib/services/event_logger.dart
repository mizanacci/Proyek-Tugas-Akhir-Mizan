import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/sensor_data.dart';
import 'firebase_service.dart';
import 'mqtt_service.dart';

class EventLogger {
  final FirebaseService _firebaseService;
  final MqttService _mqttService;
  late final StreamSubscription<dynamic> _authSubscription;
  late final VoidCallback _mqttListener;
  late final Timer _snapshotTimer;
  bool _aktif = false;
  bool _snapshotSedangDitulis = false;
  int _authGeneration = 0;
  String? _activeUid;
  String? _lastSnapshotSampleKey;
  LinkState _lruSebelumnya = LinkState.unknown;
  LinkState _comSebelumnya = LinkState.unknown;

  EventLogger(this._firebaseService, this._mqttService) {
    debugPrint('[EventLogger] Initialized');
    _mqttListener = _periksaPerubahan;
    _mqttService.addListener(_mqttListener);
    debugPrint('[EventLogger] MQTT listener active');
    _authSubscription = _firebaseService.perubahanUser.listen(
      (user) => unawaited(_tanganiPerubahanAuth(user)),
      onError: (Object error) {
        debugPrint('[EventLogger] Auth stream gagal: $error');
      },
    );
    debugPrint('[EventLogger] Firebase Auth listener registered');
    _snapshotTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(_catatSnapshotScada());
    });
    debugPrint('[EventLogger] Snapshot timer active');
  }

  bool get aktif => _aktif;

  Future<void> _tanganiPerubahanAuth(User? user) async {
    final generation = ++_authGeneration;
    _lruSebelumnya = LinkState.unknown;
    _comSebelumnya = LinkState.unknown;
    if (user == null) {
      _aktif = false;
      _activeUid = null;
      _lastSnapshotSampleKey = null;
      _mqttService.disconnect();
      debugPrint('[EventLogger] Menunggu sesi Firebase Auth.');
      return;
    }

    _aktif = true;
    if (_activeUid != user.uid) {
      _mqttService.disconnect();
      _lastSnapshotSampleKey = null;
      _activeUid = user.uid;
    }
    debugPrint('[EventLogger] Firebase Auth listener active');
    try {
      final role = await _firebaseService.roleUntukUid(user.uid);
      if (generation != _authGeneration ||
          _firebaseService.userSaatIni?.uid != user.uid) {
        return;
      }
      final connected = await _mqttService.connectForRole(role, user.uid);
      if (!connected) {
        debugPrint('[EventLogger] MQTT belum terhubung: '
            '${_mqttService.pesanKoneksi ?? _mqttService.errorTerakhir}');
      }
      unawaited(_catatSnapshotScada());
    } catch (error) {
      debugPrint('[EventLogger] Gagal memulai sesi MQTT: $error');
    }
  }

  Future<void> _catatSnapshotScada() async {
    final data = _mqttService.dataSensorTerbaru;
    if (!_aktif ||
        !_mqttService.terhubung ||
        !_mqttService.subscriptionReady ||
        _mqttService.dataBasi ||
        data == null ||
        _snapshotSedangDitulis) {
      return;
    }

    final sampleKey = '${data.timestampMs}:'
        '${data.teganganSumber}:${data.teganganBeban}:'
        '${data.arusSumber}:${data.arusBeban}:${data.bitmaskKualitas}';
    if (sampleKey == _lastSnapshotSampleKey) return;

    _snapshotSedangDitulis = true;
    try {
      await _firebaseService.catatSnapshotScada(
        data: data,
        diterimaPada: _mqttService.terakhirDataDiterima!,
        statusLru: _namaStatus(_mqttService.lruState),
        statusCom: _namaStatus(_mqttService.comState),
        statusLbs: _mqttService.statusLbs,
      );
      _lastSnapshotSampleKey = sampleKey;
      debugPrint(
        '[Firebase] Snapshot SCADA berhasil ditulis '
        '(total: ${_firebaseService.jumlahSnapshotBerhasil}).',
      );
    } catch (error) {
      debugPrint('[Firebase] Gagal menyimpan snapshot SCADA: $error');
    } finally {
      _snapshotSedangDitulis = false;
    }
  }

  String _namaStatus(LinkState state) {
    return switch (state) {
      LinkState.normal => 'NORMAL',
      LinkState.fail => 'FAIL',
      LinkState.unknown => 'UNKNOWN',
    };
  }

  void _periksaPerubahan() {
    if (!_aktif) return;
    final lruSekarang = _mqttService.lruState;
    final comSekarang = _mqttService.comState;
    _catatPerubahan(
      sebelumnya: _lruSebelumnya,
      sekarang: lruSekarang,
      alarm: 'LRUFail: FAIL (ESP32 terputus dari broker)',
      normal: 'LRUFail kembali NORMAL',
      kodeUnik: 'lruf_fail',
    );
    _catatPerubahan(
      sebelumnya: _comSebelumnya,
      sekarang: comSekarang,
      alarm: 'COMFail: FAIL (komunikasi Modbus RTU ESP32–PLC terputus)',
      normal: 'COMFail kembali NORMAL',
      kodeUnik: 'comf_fail',
    );
    _lruSebelumnya = lruSekarang;
    _comSebelumnya = comSekarang;
  }

  void _catatPerubahan({
    required LinkState sebelumnya,
    required LinkState sekarang,
    required String alarm,
    required String normal,
    required String kodeUnik,
  }) {
    if (sekarang == LinkState.fail &&
        (sebelumnya == LinkState.normal || sebelumnya == LinkState.unknown)) {
      unawaited(_catatEventSafely(
        jenis: 'ALARM',
        keterangan: alarm,
        kodeUnik: '${kodeUnik}_${DateTime.now().millisecondsSinceEpoch}',
      ));
    } else if (sebelumnya == LinkState.fail && sekarang == LinkState.normal) {
      unawaited(_catatEventSafely(
        jenis: 'STATUS',
        keterangan: normal,
      ));
    }
  }

  Future<void> _catatEventSafely({
    required String jenis,
    required String keterangan,
    String? kodeUnik,
  }) async {
    try {
      await _firebaseService.catatEvent(
        jenis: jenis,
        keterangan: keterangan,
        kodeUnik: kodeUnik,
      );
    } catch (error) {
      debugPrint('[EventLogger] Gagal menyimpan event $jenis: $error');
    }
  }

  void dispose() {
    _snapshotTimer.cancel();
    _mqttService.removeListener(_mqttListener);
    unawaited(_authSubscription.cancel());
    _mqttService.disconnect();
  }
}
