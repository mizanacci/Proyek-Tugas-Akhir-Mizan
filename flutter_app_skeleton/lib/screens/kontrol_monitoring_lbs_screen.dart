/// kontrol_monitoring_lbs_screen.dart — Kontrol & Monitoring LBS (Gambar 3.13
/// mock-up proposal). SATU-SATUNYA layar yang bisa mengirim perintah NO/NC —
/// hanya dapat diakses lewat menu_operator_screen.dart (Manager tidak
/// mendapat kartu menu ke layar ini, lihat menu_manager_screen.dart).
/// Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mqtt_service.dart';
import '../services/firebase_service.dart';

class KontrolMonitoringLbsScreen extends StatelessWidget {
  const KontrolMonitoringLbsScreen({super.key});

  Future<void> _kirimPerintah(BuildContext context, String perintah) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Perintah'),
        content: Text('Kirim perintah $perintah ke relay MY2N?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kirim')),
        ],
      ),
    );
    if (konfirmasi != true || !context.mounted) return;

    context.read<MqttService>().kirimPerintahRelay(perintah);
    // Catat ke Data Activity — lihat firebase_service.dart. Dicatat SEGERA
    // setelah perintah dikirim (bukan menunggu konfirmasi eksekusi PLC),
    // karena eksekusi sebenarnya masih tunduk pada gerbang Hot Line/LRUFail/
    // COMFail di ladder logic PLC — log ini mencatat "perintah dikirim dari
    // aplikasi", bukan "perintah berhasil dieksekusi". Pertimbangkan
    // menambah field status eksekusi terpisah bila BAB 4 memerlukan
    // pembedaan ini secara eksplisit.
    await context.read<FirebaseService>().catatDataActivity(aksi: perintah, sumber: 'mobile');

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Perintah $perintah terkirim.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kontrol & Monitoring LBS')),
      body: Consumer<MqttService>(
        builder: (context, mqtt, _) {
          final lruf = mqtt.statusLRUFail;
          final comf = mqtt.statusCOMFail;
          final bisaKirim = mqtt.terhubung && (lruf?.normal ?? false) && (comf?.normal ?? false);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (!bisaKirim)
                  Card(
                    color: Colors.amber.shade50,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Perintah remote tidak dapat dikirim saat ini — periksa status koneksi, '
                        'LRUFail, dan COMFail di bawah. Eksekusi akhir tetap ditentukan ladder '
                        'logic PLC (gerbang Hot Line=UNLOCK, LRUFail=NORMAL, COMFail=NORMAL).',
                      ),
                    ),
                  ),
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
                const Text('Status Terkini', style: TextStyle(fontWeight: FontWeight.bold)),
                ListTile(
                  leading: Icon(mqtt.terhubung ? Icons.wifi : Icons.wifi_off),
                  title: const Text('Koneksi MQTT'),
                  trailing: Text(mqtt.terhubung ? 'Terhubung' : 'Terputus'),
                ),
                ListTile(
                  leading: Icon((lruf?.normal ?? false) ? Icons.check_circle : Icons.error, color: (lruf?.normal ?? false) ? Colors.green : Colors.red),
                  title: const Text('LRUFail'),
                  trailing: Text((lruf?.normal ?? false) ? 'NORMAL' : 'FAIL'),
                ),
                ListTile(
                  leading: Icon((comf?.normal ?? false) ? Icons.check_circle : Icons.error, color: (comf?.normal ?? false) ? Colors.green : Colors.red),
                  title: const Text('COMFail (estimasi ESP32)'),
                  trailing: Text((comf?.normal ?? false) ? 'NORMAL' : 'FAIL'),
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
  const _TombolKontrol({required this.label, required this.warna, required this.aktif, required this.onTap});

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
      child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}
