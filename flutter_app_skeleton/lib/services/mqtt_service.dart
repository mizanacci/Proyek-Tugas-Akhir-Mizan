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
import '../models/sensor_data.dart';

// Samakan dengan config.h firmware & dokumen 04_Konfigurasi_HiveMQ.md
const String _mqttHost = 'ISI_HOSTNAME.s1.eu.hivemq.cloud';
const int _mqttPort = 8883;
const String _topicDataSensor = 'scada/mizan/data/sensor';
const String _topicStatusLruf = 'scada/mizan/status/lrufail';
const String _topicStatusComf = 'scada/mizan/status/comfail';
const String _topicCmdRemote = 'scada/mizan/cmd/relay';

class MqttService extends ChangeNotifier {
  late MqttServerClient _client;
  bool _terhubung = false;

  SensorData? dataSensorTerbaru;
  StatusLink? statusLRUFail;
  StatusLink? statusCOMFail;

  bool get terhubung => _terhubung;

  /// Panggil sekali (mis. dari initState halaman utama setelah login) dengan
  /// kredensial spesifik role/user yang sedang login. clientId HARUS unik
  /// per instalasi aplikasi agar tidak bentrok dengan sesi ESP32/aplikasi
  /// lain yang terhubung ke cluster yang sama.
  Future<bool> connect({
    required String username,
    required String password,
    required String clientId,
  }) async {
    _client = MqttServerClient.withPort(_mqttHost, clientId, _mqttPort);
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
      debugPrint('[MQTT] Gagal connect: $e');
      _client.disconnect();
      return false;
    }

    if (_client.connectionStatus?.state != MqttConnectionState.connected) {
      debugPrint('[MQTT] Status koneksi gagal: ${_client.connectionStatus}');
      return false;
    }

    _subscribeSemuaTopic();
    return true;
  }

  void _onConnected() {
    _terhubung = true;
    notifyListeners();
    debugPrint('[MQTT] Terhubung.');
  }

  void _onDisconnected() {
    _terhubung = false;
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
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client.publishMessage(
      _topicCmdRemote,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }

  void disconnect() {
    _client.disconnect();
  }
}
