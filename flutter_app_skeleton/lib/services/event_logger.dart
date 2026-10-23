import 'dart:async';
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
  LinkState _lruSebelumnya = LinkState.unknown;
  LinkState _comSebelumnya = LinkState.unknown;

  EventLogger(this._firebaseService, this._mqttService) {
    _mqttListener = _periksaPerubahan;
    _mqttService.addListener(_mqttListener);
    _authSubscription = _firebaseService.perubahanUser.listen((user) {
      _aktif = user != null;
      _lruSebelumnya = LinkState.unknown;
      _comSebelumnya = LinkState.unknown;
      if (_aktif) {
        debugPrint('[Firebase] Auth aktif; EventLogger siap.');
        unawaited(_catatSnapshotScada());
      } else {
        debugPrint(
            '[Firebase] Tidak ada user aktif; EventLogger menunggu login.');
      }
    });
    _snapshotTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(_catatSnapshotScada());
    });
  }

  Future<void> _catatSnapshotScada() async {
    if (!_aktif ||
        _mqttService.dataSensorTerbaru == null ||
        _snapshotSedangDitulis) {
      return;
    }

    _snapshotSedangDitulis = true;
    try {
      await _firebaseService.catatSnapshotScada(
        data: _mqttService.dataSensorTerbaru!,
        statusLru: _namaStatus(_mqttService.lruState),
        statusCom: _namaStatus(_mqttService.comState),
        statusLbs: _mqttService.statusLbs,
      );
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
      unawaited(_firebaseService.catatEvent(
        jenis: 'ALARM',
        keterangan: alarm,
        kodeUnik: kodeUnik,
      ));
    } else if (sebelumnya == LinkState.fail && sekarang == LinkState.normal) {
      unawaited(_firebaseService.catatEvent(
        jenis: 'STATUS',
        keterangan: normal,
      ));
    }
  }

  void dispose() {
    _snapshotTimer.cancel();
    _mqttService.removeListener(_mqttListener);
    _authSubscription.cancel();
  }
}
