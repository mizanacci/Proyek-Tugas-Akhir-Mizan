/// monitoring_screen.dart — Layar Monitoring (Gambar 3.12 mock-up proposal)
/// Dipakai bersama oleh Manager dan Operator (bisaKontrol=false untuk
/// keduanya di sini — kontrol relay hanya ada di kontrol_monitoring_lbs_screen.dart
/// untuk membedakan tegas layar "lihat" vs layar "lihat + kendalikan").
/// Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/mqtt_service.dart';
import '../services/firebase_service.dart';
import '../models/sensor_data.dart';

class MonitoringScreen extends StatefulWidget {
  final bool bisaKontrol; // diteruskan oleh layar pemanggil; lihat catatan file
  final UserRole role; // menentukan kredensial MQTT mana yang dipakai
  const MonitoringScreen({super.key, required this.bisaKontrol, required this.role});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  @override
  void initState() {
    super.initState();
    _pastikanTerhubungMqtt();
  }

  Future<void> _pastikanTerhubungMqtt() async {
    final mqtt = context.read<MqttService>();
    if (!mqtt.terhubung) {
      final firebaseUser = context.read<FirebaseService>().userSaatIni;
      // Kredensial MQTT (username/password broker, BEDA dari kredensial
      // Firebase) dipilih sesuai role — dibuat di HiveMQ Cloud Access
      // Management, lihat 04_Konfigurasi_HiveMQ.md Bagian 2. Untuk skala
      // prototipe TA, kredensial ini di-hardcode per-role (bukan per-user
      // individual) — [DRAF] pertimbangkan mapping uid Firebase -> kredensial
      // MQTT tersendiri bila jumlah pengguna bertambah banyak di masa depan.
      final bool isManager = widget.role == UserRole.manager;
      await mqtt.connect(
        username: isManager ? 'flutter-app-manager' : 'flutter-app-operator',
        password: isManager ? 'MQQTmizan16!' : 'MQQTmizan17!',
        clientId: 'flutter-${firebaseUser?.uid ?? DateTime.now().millisecondsSinceEpoch}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monitoring')),
      body: Consumer<MqttService>(
        builder: (context, mqtt, _) {
          final data = mqtt.dataSensorTerbaru;
          final lruf = mqtt.statusLRUFail;
          final comf = mqtt.statusCOMFail;

          if (!mqtt.terhubung) {
            return const Center(child: Text('Menghubungkan ke server...'));
          }
          if (data == null) {
            return const Center(child: Text('Menunggu data sensor pertama...'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/monitoring_header_background.png',
                  height: 110,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              _KartuStatus(label: 'LRUFail', normal: lruf?.normal ?? true),
              _KartuStatus(
                label: 'COMFail (estimasi)',
                normal: comf?.normal ?? true,
                catatan: 'Estimasi sisi ESP32 — lihat README firmware',
              ),
              const SizedBox(height: 16),
              _KartuUkuran(
                label: 'Tegangan Sisi Sumber',
                nilai: data.teganganSumber,
                satuan: 'V',
                good: data.kualitasVSumberGood,
              ),
              _KartuUkuran(
                label: 'Tegangan Sisi Beban',
                nilai: data.teganganBeban,
                satuan: 'V',
                good: data.kualitasVBebanGood,
              ),
              _KartuUkuran(
                label: 'Arus Sisi Sumber',
                nilai: data.arusSumber,
                satuan: 'A',
                good: data.kualitasISumberGood,
              ),
              _KartuUkuran(
                label: 'Arus Sisi Beban',
                nilai: data.arusBeban,
                satuan: 'A',
                good: data.kualitasIBebanGood,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KartuStatus extends StatelessWidget {
  final String label;
  final bool normal;
  final String? catatan;
  const _KartuStatus({required this.label, required this.normal, this.catatan});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: normal ? Colors.green.shade50 : Colors.red.shade50,
      child: ListTile(
        leading: Icon(
          normal ? Icons.check_circle : Icons.error,
          color: normal ? Colors.green : Colors.red,
        ),
        title: Text(label),
        subtitle: Text(normal ? 'NORMAL' : 'FAIL' '${catatan != null ? " — $catatan" : ""}'),
      ),
    );
  }
}

class _KartuUkuran extends StatelessWidget {
  final String label;
  final double nilai;
  final String satuan;
  final bool good;
  const _KartuUkuran({required this.label, required this.nilai, required this.satuan, required this.good});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text('${nilai.toStringAsFixed(2)} $satuan', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: good ? null : const Text('SUSPECT — nilai di luar rentang wajar', style: TextStyle(color: Colors.orange)),
      ),
    );
  }
}
