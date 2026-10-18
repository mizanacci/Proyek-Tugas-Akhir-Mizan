/// monitoring_screen.dart — Layar Monitoring (Gambar 3.12 mock-up proposal)
/// Dipakai bersama oleh Manager dan Operator (bisaKontrol=false untuk
/// keduanya di sini — kontrol relay hanya ada di kontrol_monitoring_lbs_screen.dart
/// untuk membedakan tegas layar "lihat" vs layar "lihat + kendalikan").
/// Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mqtt_service.dart';
import '../services/firebase_service.dart';
import '../models/sensor_data.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_link_tile.dart';

class MonitoringScreen extends StatefulWidget {
  final bool bisaKontrol; // diteruskan oleh layar pemanggil; lihat catatan file
  final UserRole role; // menentukan kredensial MQTT mana yang dipakai
  const MonitoringScreen(
      {super.key, required this.bisaKontrol, required this.role});

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
      await mqtt.connectForRole(
        widget.role,
        firebaseUser?.uid ?? DateTime.now().millisecondsSinceEpoch.toString(),
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
          if (!mqtt.terhubung) {
            return const EmptyState(
              imageAsset: 'assets/images/empty_mqtt_disconnected.png',
              title: 'Belum terhubung ke server',
              message: 'Memeriksa koneksi MQTT…',
            );
          }
          if (data == null) {
            return const EmptyState(
              imageAsset: 'assets/images/empty_sensor_waiting.png',
              title: 'Menunggu data sensor',
              message: 'ESP32 belum mengirim data pertama',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/monitoring_header_background.png',
                  height: 110,
                  cacheWidth: 900,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    height: 110,
                    child:
                        Center(child: Icon(Icons.image_not_supported_outlined)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (mqtt.dataBasi) ...[
                Card(
                  color: Colors.orange.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange),
                    title: Text(
                      'Data sensor tidak diperbarui sejak '
                      '${_formatWaktu(mqtt.terakhirDataDiterima)}',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              StatusLinkTile(
                label: 'Koneksi ESP32 ke broker (LRUFail)',
                state: mqtt.lruState,
              ),
              StatusLinkTile(
                label: 'Komunikasi Modbus ESP32–PLC (COMFail)',
                state: mqtt.comState,
                subtitle: 'Estimasi dari sisi ESP32',
              ),
              Text(
                'Terakhir diperbarui: ${_formatWaktu(mqtt.terakhirDataDiterima)}',
                style: Theme.of(context).textTheme.bodySmall,
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

String _formatWaktu(DateTime? waktu) {
  if (waktu == null) return '--:--:--';
  final jam = waktu.hour.toString().padLeft(2, '0');
  final menit = waktu.minute.toString().padLeft(2, '0');
  final detik = waktu.second.toString().padLeft(2, '0');
  return '$jam:$menit:$detik';
}

class _KartuUkuran extends StatelessWidget {
  final String label;
  final double nilai;
  final String satuan;
  final bool good;
  const _KartuUkuran(
      {required this.label,
      required this.nilai,
      required this.satuan,
      required this.good});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text('${nilai.toStringAsFixed(2)} $satuan',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: good
            ? null
            : const Text('SUSPECT — nilai di luar rentang wajar',
                style: TextStyle(color: Colors.orange)),
      ),
    );
  }
}
