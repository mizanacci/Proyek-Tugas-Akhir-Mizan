/// kontrol_monitoring_lbs_screen.dart — Kontrol & Monitoring LBS (Gambar 3.13
/// mock-up proposal). SATU-SATUNYA layar yang bisa mengirim perintah NO/NC —
/// hanya dapat diakses lewat menu_operator_screen.dart (Manager tidak
/// mendapat kartu menu ke layar ini, lihat menu_manager_screen.dart).
/// Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mqtt_service.dart';
import '../services/firebase_service.dart';
import '../widgets/status_link_tile.dart';

class KontrolMonitoringLbsScreen extends StatefulWidget {
  const KontrolMonitoringLbsScreen({super.key});

  @override
  State<KontrolMonitoringLbsScreen> createState() =>
      _KontrolMonitoringLbsScreenState();
}

class _KontrolMonitoringLbsScreenState
    extends State<KontrolMonitoringLbsScreen> {
  Future<void> _kirimPerintah(BuildContext context, String perintah) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Perintah'),
        content: Text('Kirim perintah $perintah ke relay MY2N?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Kirim')),
        ],
      ),
    );
    if (konfirmasi != true || !context.mounted) return;

    final mqtt = context.read<MqttService>();
    final firebase = context.read<FirebaseService>();
    final published = mqtt.kirimPerintahRelay(perintah);
    final detail = published
        ? 'PUBLISHED: perintah $perintah dikirim ke MQTT; menunggu konfirmasi PLC.'
        : 'REJECTED: perintah $perintah tidak dipublikasikan. '
            '${mqtt.alasanTidakBisaKirim ?? mqtt.errorTerakhir ?? 'Kegagalan publish MQTT.'}';
    try {
      await firebase.catatEvent(jenis: 'PERINTAH', keterangan: detail);
    } catch (error) {
      debugPrint('[Kontrol] Gagal mencatat aktivitas perintah: $error');
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(published
            ? 'Perintah dipublikasikan ke MQTT; menunggu feedback PLC.'
            : mqtt.alasanTidakBisaKirim ??
                mqtt.errorTerakhir ??
                'Perintah ditolak.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kontrol & Monitoring LBS')),
      body: Consumer<MqttService>(
        builder: (context, mqtt, _) {
          final alasan = mqtt.alasanTidakBisaKirim;
          final bisaKirim = alasan == null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/lbs_control_illustration.png',
                    height: 160,
                    width: double.infinity,
                    cacheWidth: 900,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(
                      height: 160,
                      child: Center(
                          child: Icon(Icons.image_not_supported_outlined)),
                    ),
                  ),
                ),
                if (alasan != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.amber.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(alasan),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _TombolKontrol(
                      label: 'NO',
                      warna: Colors.red,
                      aktif: bisaKirim,
                      onTap: () => _kirimPerintah(context, 'NO'),
                    ),
                    _TombolKontrol(
                      label: 'NC',
                      warna: Colors.green,
                      aktif: bisaKirim,
                      onTap: () => _kirimPerintah(context, 'NC'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const Text('Status Terkini',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                StatusLinkTile(
                  label: 'Koneksi aplikasi ke HiveMQ',
                  state: mqtt.koneksiAplikasiState,
                  subtitle: mqtt.koneksiAplikasiMessage,
                ),
                StatusLinkTile(
                  label: 'Koneksi ESP32 ke MQTT',
                  state: mqtt.lruState,
                  subtitle: mqtt.koneksiPerangkatMessage,
                ),
                StatusLinkTile(
                  label: 'Status koneksi sistem',
                  state: mqtt.statusKoneksiSistemState,
                  subtitle: mqtt.statusKoneksiSistemMessage,
                ),
                StatusLinkTile(
                  label: 'LRUFail',
                  state: mqtt.lruState,
                  subtitle: mqtt.lruStatusMessage,
                ),
                StatusLinkTile(
                  label: 'COMFail (estimasi ESP32)',
                  state: mqtt.comState,
                  subtitle: mqtt.comStatusMessage,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TombolKontrol extends StatelessWidget {
  final String label;
  final Color warna;
  final bool aktif;
  final VoidCallback onTap;
  const _TombolKontrol(
      {required this.label,
      required this.warna,
      required this.aktif,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: aktif ? onTap : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: warna,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(28),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}
