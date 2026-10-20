/// mqtt_service.dart — Wrapper koneksi MQTT ke HiveMQ Cloud
/// Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)
///
/// [DRAF] Nilai host/kredensial di bawah adalah placeholder — pindahkan ke
/// mekanisme konfigurasi yang tidak ter-commit ke Git sebelum implementasi
/// akhir (mis. package flutter_dotenv, atau --dart-define saat build).
/// JANGAN commit kredensial asli ke repository publik/kampus.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../config/app_secrets.dart';
import '../models/sensor_data.dart';

// Samakan dengan config.h firmware & dokumen 04_Konfigurasi_HiveMQ.md
const String _mqttHost = '57b78f1434be4eee81c34de53a922e06.s1.eu.hivemq.cloud';
const int _mqttPort = 8883;
const String _topicDataSensor = 'scada/mizan/data/sensor';
const String _topicStatusLruf = 'scada/mizan/status/lrufail';
const String _topicStatusComf = 'scada/mizan/status/comfail';
const String _topicCmdRemote = 'scada/mizan/cmd/relay';

class MqttService extends ChangeNotifier {
  late MqttServerClient _client;
  bool _clientInitialized = false;
  bool _terhubung = false;
  String? _pesanKoneksi;
  String _statusLbs = 'UNKNOWN';

  SensorData? dataSensorTerbaru;
  StatusLink? statusLRUFail;
  StatusLink? statusCOMFail;
  DateTime? terakhirDataDiterima;
  bool _dataBasi = true;
  Timer? _timerBasi;

  bool get terhubung => _terhubung;
  bool get dataBasi => _dataBasi;
  String? get pesanKoneksi => _pesanKoneksi;
  String get statusLbs => _statusLbs;

  LinkState get lruState {
    if (statusLRUFail?.normal == false) return LinkState.fail;
    if (_terhubung && !_dataBasi && dataSensorTerbaru != null) {
      return LinkState.normal;
    }
    if (_terhubung && _dataBasi) return LinkState.fail;
    return LinkState.unknown;
  }

  String get lruStatusMessage {
    if (!_terhubung) {
      return 'Aplikasi tidak terhubung ke broker MQTT.';
    }
    if (statusLRUFail?.normal == false || _dataBasi) {
      return 'LRUFail: ESP32 tidak terhubung MQTT; periksa hotspot/gateway.';
    }
    return 'ESP32 terhubung ke broker MQTT.';
  }

  String get comStatusMessage {
    if (comState == LinkState.fail) {
      return 'COMFail: ESP32 tidak terhubung atau tidak menerima polling PLC.';
    }
    if (comState == LinkState.unknown) {
      return 'Menunggu status komunikasi ESP32-PLC.';
    }
    return 'Komunikasi ESP32-PLC normal.';
  }

  LinkState get comState => statusCOMFail == null
      ? LinkState.unknown
      : (statusCOMFail!.normal ? LinkState.normal : LinkState.fail);

  String? get alasanTidakBisaKirim {
    if (!terhubung) return 'Belum terhubung ke server MQTT.';
    if (lruState == LinkState.unknown || comState == LinkState.unknown) {
      return 'Menunggu status LRUFail/COMFail dari perangkat…';
    }
    if (lruState == LinkState.fail) {
      return 'LRUFail: ESP32 terputus dari broker.';
    }
    if (comState == LinkState.fail) {
      return 'COMFail: komunikasi Modbus RTU ESP32–PLC bermasalah.';
    }
    if (dataBasi) {
      return 'Data sensor tidak diperbarui lebih dari 5 detik.';
    }
    return null;
  }

  MqttService() {
    _timerBasi = Timer.periodic(const Duration(seconds: 1), (_) {
      final dataBasiBaru = terakhirDataDiterima == null ||
          DateTime.now().difference(terakhirDataDiterima!) >
              const Duration(seconds: 5);
      if (dataBasiBaru != _dataBasi) {
        _dataBasi = dataBasiBaru;
        notifyListeners();
      }
    });
  }

  Future<bool> connectForRole(UserRole role, String uid) {
    final bool isManager = role == UserRole.manager;
    return connect(
      username: isManager
          ? AppSecrets.mqttManagerUsername
          : AppSecrets.mqttOperatorUsername,
      password: isManager
          ? AppSecrets.mqttManagerPassword
          : AppSecrets.mqttOperatorPassword,
      clientId: 'flutter-$uid',
    );
  }

  /// Panggil sekali (mis. dari initState halaman utama setelah login) dengan
  /// kredensial spesifik role/user yang sedang login. clientId HARUS unik
  /// per instalasi aplikasi agar tidak bentrok dengan sesi ESP32/aplikasi
  /// lain yang terhubung ke cluster yang sama.
  Future<bool> connect({
    required String username,
    required String password,
    required String clientId,
  }) async {
    if (username.trim().isEmpty || password.isEmpty) {
      _pesanKoneksi =
          'Kredensial MQTT belum diisi. Buat user Flutter di HiveMQ '
          'Access Management dan jalankan aplikasi dengan --dart-define.';
      notifyListeners();
      return false;
    }

    _client = MqttServerClient.withPort(_mqttHost, clientId, _mqttPort);
    _clientInitialized = true;
    _client.secure = true;
    _client.securityContext = SecurityContext.defaultContext;
    _client.keepAlivePeriod = 30;
    _client.autoReconnect = true;
    _client.onConnected = _onConnected;
    _client.onDisconnected = _onDisconnected;
    _client.onAutoReconnect = () {
      debugPrint('[MQTT] Auto-reconnect dimulai...');
    };
    _client.logging(on: false); // set true saat debugging

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(username, password)
        .startClean();
    _client.connectionMessage = connMessage;

    try {
      await _client.connect();
    } catch (e) {
      _pesanKoneksi = 'Gagal autentikasi/koneksi MQTT: $e';
      debugPrint('[MQTT] Gagal connect: $e');
      _client.disconnect();
      _terhubung = false;
      notifyListeners();
      return false;
    }

    if (_client.connectionStatus?.state != MqttConnectionState.connected) {
      _pesanKoneksi =
          'Broker menolak koneksi MQTT: ${_client.connectionStatus}';
      debugPrint('[MQTT] Status koneksi gagal: ${_client.connectionStatus}');
      notifyListeners();
      return false;
    }

    _subscribeSemuaTopic();
    return true;
  }

  void _onConnected() {
    _terhubung = true;
    _pesanKoneksi = null;
    notifyListeners();
    debugPrint('[MQTT] Terhubung.');
  }

  void _onDisconnected() {
    _terhubung = false;
    _pesanKoneksi ??= 'Koneksi MQTT terputus.';
    statusLRUFail = null;
    statusCOMFail = null;
    dataSensorTerbaru = null;
    terakhirDataDiterima = null;
    _statusLbs = 'UNKNOWN';
    _dataBasi = true;
    notifyListeners();
    debugPrint('[MQTT] Terputus.');
  }

  void _subscribeSemuaTopic() {
    _client.subscribe(_topicDataSensor, MqttQos.atMostOnce);
    _client.subscribe(_topicStatusLruf, MqttQos.atLeastOnce);
    _client.subscribe(_topicStatusComf, MqttQos.atLeastOnce);

    _client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> event) {
      final MqttPublishMessage recMess = event[0].payload as MqttPublishMessage;
      final String payload =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      final String topic = event[0].topic;

      try {
        final Map<String, dynamic> json = jsonDecode(payload);
        if (topic == _topicDataSensor) {
          dataSensorTerbaru = SensorData.fromJson(json);
          terakhirDataDiterima = DateTime.now();
          if (statusLRUFail?.normal != false) {
            statusLRUFail = StatusLink(
              normal: true,
              source: 'sensor_data_received',
            );
          }
          if (_dataBasi) _dataBasi = false;
        } else if (topic == _topicStatusLruf) {
          statusLRUFail = StatusLink.fromJson(json);
        } else if (topic == _topicStatusComf) {
          statusCOMFail = StatusLink.fromJson(json);
        }
        notifyListeners();
      } catch (e) {
        debugPrint('[MQTT] Gagal parse payload topic $topic: $e');
      }
    });
  }

  /// Mengirim perintah NO/NC ke ESP32 (role Operator saja — validasi hak
  /// akses role dilakukan di layar pemanggil, BUKAN di service ini, agar
  /// service tetap sederhana/reusable; lihat kontrol_monitoring_lbs_screen.dart).
  void kirimPerintahRelay(String perintah) {
    if (!_terhubung) {
      debugPrint('[MQTT] Tidak terhubung, perintah $perintah dibatalkan.');
      return;
    }
    final payload = jsonEncode({'command': perintah});
    _statusLbs = 'COMMAND_$perintah';
    notifyListeners();
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client.publishMessage(
      _topicCmdRemote,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }

  void disconnect() {
    if (_clientInitialized) {
      _client.disconnect();
    }
  }

  @override
  void dispose() {
    _timerBasi?.cancel();
    super.dispose();
  }
}
