/// kontrol_monitoring_lbs_screen.dart — Kontrol & Monitoring LBS (Gambar 3.13
/// mock-up proposal). SATU-SATUNYA layar yang bisa mengirim perintah NO/NC —
/// hanya dapat diakses lewat menu_operator_screen.dart (Manager tidak
/// mendapat kartu menu ke layar ini, lihat menu_manager_screen.dart).
/// Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../models/sensor_data.dart';
import '../models/scada_data.dart';
import '../services/scada_service.dart';

class KontrolMonitoringLbsScreen extends StatefulWidget {
  const KontrolMonitoringLbsScreen({super.key});

  @override
  State<KontrolMonitoringLbsScreen> createState() =>
      _KontrolMonitoringLbsScreenState();
}

class _KontrolMonitoringLbsScreenState
    extends State<KontrolMonitoringLbsScreen> {
  String? _commandId;
  String? _submissionMessage;
  bool _sending = false;

  Future<void> _kirimPerintah(BuildContext context, String action) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Permintaan'),
        content: Text(
          'Kirim permintaan $action ke ${ScadaService.lbsTarget}? '
          'Gateway dan PLC tetap memvalidasi permissive serta interlock.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Kirim permintaan')),
        ],
      ),
    );
    if (konfirmasi != true || !context.mounted) return;

    setState(() {
      _sending = true;
      _submissionMessage = null;
    });
    try {
      final commandId = await context.read<ScadaService>().sendLbsCommand(
            target: ScadaService.lbsTarget,
            action: action,
          );
      if (!mounted) return;
      setState(() {
        _commandId = commandId;
        _submissionMessage = 'PENDING: permintaan tercatat; menunggu gateway.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _submissionMessage = 'Permintaan gagal dikirim: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }

    if (!context.mounted || _submissionMessage == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_submissionMessage!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kontrol & Monitoring LBS')),
      body: Consumer<FirebaseService>(
        builder: (context, firebase, _) {
          final profile = firebase.profilSaatIni;
          final bisaKirim =
              profile?.isActive == true && profile?.role == UserRole.operator;
          final scada = context.read<ScadaService>();

          return StreamBuilder<ScadaTelemetry?>(
            stream: scada.watchTelemetry(ScadaService.lbsTarget),
            builder: (context, snapshot) => SingleChildScrollView(
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
                  if (!bisaKirim) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.amber.shade50,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Hanya operator aktif yang dapat mengirim permintaan kontrol.',
                        ),
                      ),
                    ),
                  ],
                  if (snapshot.hasError)
                    Text('Telemetry tidak dapat dibaca: ${snapshot.error}'),
                  if (snapshot.data != null) ...[
                    if (snapshot.data!.isStale)
                      const Card(
                        child: ListTile(
                          leading: Icon(Icons.warning_amber_rounded),
                          title: Text('Telemetry stale'),
                        ),
                      ),
                    ListTile(
                      title: const Text('Posisi aktual dari telemetry'),
                      subtitle: Text(snapshot.data!.lbsStatus),
                    ),
                    ListTile(
                      title: const Text('Status komunikasi'),
                      subtitle: Text(
                        'LRU: ${snapshot.data!.lruStatus} · '
                        'COM: ${snapshot.data!.communicationStatus}',
                      ),
                    ),
                  ] else if (snapshot.connectionState ==
                      ConnectionState.waiting)
                    const LinearProgressIndicator()
                  else if (!snapshot.hasError)
                    const Text('Telemetry belum tersedia.'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _TombolKontrol(
                        label: 'OPEN',
                        warna: Colors.red,
                        aktif: bisaKirim && !_sending,
                        onTap: () => _kirimPerintah(context, 'OPEN'),
                      ),
                      _TombolKontrol(
                        label: 'CLOSE',
                        warna: Colors.green,
                        aktif: bisaKirim && !_sending,
                        onTap: () => _kirimPerintah(context, 'CLOSE'),
                      ),
                    ],
                  ),
                  if (_sending) const CircularProgressIndicator(),
                  if (_submissionMessage != null)
                    ListTile(
                      title: const Text('Status pengiriman'),
                      subtitle: Text(_submissionMessage!),
                    ),
                  if (_commandId != null)
                    StreamBuilder<ScadaCommandResult?>(
                      stream: scada.watchCommandResult(_commandId!),
                      builder: (context, resultSnapshot) {
                        if (resultSnapshot.hasError) {
                          return Text('Hasil command gagal dibaca: '
                              '${resultSnapshot.error}');
                        }
                        final result = resultSnapshot.data;
                        return ListTile(
                          title: const Text('Status pemrosesan gateway'),
                          subtitle: Text(result == null
                              ? 'Menunggu hasil command $_commandId'
                              : '${result.status.name.toUpperCase()}: '
                                  '${result.detail}'),
                        );
                      },
                    ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const Text('Keselamatan Operasi',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const Text(
                    'Firebase mencatat permintaan saja. Gateway memvalidasi '
                    'command; PLC tetap memvalidasi permissive, interlock, dan proteksi.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
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
