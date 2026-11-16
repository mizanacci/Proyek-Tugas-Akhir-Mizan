/// monitoring_screen.dart — Layar Monitoring (Gambar 3.12 mock-up proposal)
/// Dipakai bersama oleh Manager dan Operator (bisaKontrol=false untuk
/// keduanya di sini — kontrol relay hanya ada di kontrol_monitoring_lbs_screen.dart
/// untuk membedakan tegas layar "lihat" vs layar "lihat + kendalikan").
/// Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../services/scada_service.dart';
import '../models/scada_data.dart';
import '../models/sensor_data.dart';
import '../widgets/empty_state.dart';
import '../widgets/integration_diagnostics_panel.dart';
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
  late final Stream<ScadaTelemetry?> _telemetryStream;
  Timer? _staleRefreshTimer;

  @override
  void initState() {
    super.initState();
    _telemetryStream =
        context.read<ScadaService>().watchTelemetry(ScadaService.lbsTarget);
    _staleRefreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _staleRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Monitoring ${widget.role.name}')),
      body: Consumer<FirebaseService>(
        builder: (context, firebase, _) {
          final profile = firebase.profilSaatIni;
          if (profile == null ||
              !profile.isActive ||
              profile.role != widget.role) {
            return const Center(
                child: Text('Sesi aktif tidak memiliki izin monitoring.'));
          }

          return StreamBuilder<ScadaTelemetry?>(
            stream: _telemetryStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const IntegrationDiagnosticsPanel(),
                    Text('Telemetry tidak dapat dibaca: ${snapshot.error}'),
                  ],
                );
              }
              final telemetry = snapshot.data;
              if (telemetry == null) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const IntegrationDiagnosticsPanel(),
                    EmptyState(
                      imageAsset: 'assets/images/empty_sensor_waiting.png',
                      title: snapshot.connectionState == ConnectionState.waiting
                          ? 'Menghubungkan ke Firebase'
                          : 'Menunggu telemetry gateway',
                      message:
                          'Data akan tampil setelah gateway menulis telemetry.',
                    ),
                  ],
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const IntegrationDiagnosticsPanel(),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/monitoring_header_background.png',
                      height: 110,
                      cacheWidth: 900,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox(
                        height: 110,
                        child: Center(
                          child: Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (telemetry.isStale) ...[
                    const Card(
                      color: Color(0xFFFFF3E0),
                      child: ListTile(
                        leading: Icon(Icons.warning_amber_rounded),
                        title: Text('Telemetry stale: tidak ada update baru.'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  StatusLinkTile(
                    label: 'Gateway / LRU',
                    state: _statusState(telemetry.lruStatus),
                    subtitle: telemetry.lruStatus,
                  ),
                  StatusLinkTile(
                    label: 'Komunikasi PLC',
                    state: _statusState(telemetry.communicationStatus),
                    subtitle: telemetry.communicationStatus,
                  ),
                  ListTile(
                    title: const Text('Posisi LBS dari telemetry'),
                    subtitle: Text(telemetry.lbsStatus),
                  ),
                  Text(
                    'Diterima: ${_formatWaktu(telemetry.receivedAt)} · '
                    'waktu perangkat: ${telemetry.deviceTimestampMs}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  _KartuUkuran(
                    label: 'Tegangan Sisi Sumber',
                    nilai: telemetry.sourceVoltage,
                    satuan: 'V',
                    good: (telemetry.quality & 0x01) == 0,
                    statusOperasi: telemetry.sourceVoltageStatus,
                  ),
                  _KartuUkuran(
                    label: 'Tegangan Sisi Beban',
                    nilai: telemetry.loadVoltage,
                    satuan: 'V',
                    good: (telemetry.quality & 0x02) == 0,
                    statusOperasi: telemetry.loadVoltageStatus,
                  ),
                  _KartuUkuran(
                    label: 'Arus Sisi Sumber',
                    nilai: telemetry.sourceCurrent,
                    satuan: 'A',
                    good: (telemetry.quality & 0x04) == 0,
                    statusOperasi: telemetry.sourceCurrentStatus,
                    isCurrent: true,
                  ),
                  _KartuUkuran(
                    label: 'Arus Sisi Beban',
                    nilai: telemetry.loadCurrent,
                    satuan: 'A',
                    good: (telemetry.quality & 0x08) == 0,
                    statusOperasi: telemetry.loadCurrentStatus,
                    isCurrent: true,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

LinkState _statusState(String status) => switch (status) {
      'NORMAL' => LinkState.normal,
      'FAIL' => LinkState.fail,
      _ => LinkState.unknown,
    };

String _formatWaktu(int millisecondsSinceEpoch) {
  final waktu =
      DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch).toLocal();
  final jam = waktu.hour.toString().padLeft(2, '0');
  final menit = waktu.minute.toString().padLeft(2, '0');
  final detik = waktu.second.toString().padLeft(2, '0');
  return '$jam:$menit:$detik';
}

String _labelStatusTegangan(String status) => switch (status) {
      'AC_OFF' => 'AC_OFF / STANDBY',
      'NORMAL' => 'NORMAL',
      'SUSPECT' => 'SUSPECT',
      'WARNING' => 'WARNING',
      _ => 'UNKNOWN',
    };

String _labelStatusArus(String status) => switch (status) {
      'NORMAL' => 'NORMAL / STANDBY',
      'SUSPECT' => 'SUSPECT',
      _ => 'UNKNOWN',
    };

Color _warnaStatusArus(String status) => switch (status) {
      'NORMAL' => Colors.green,
      'SUSPECT' => Colors.orange,
      _ => Colors.grey,
    };

Color _warnaStatusTegangan(String status) => switch (status) {
      'NORMAL' => Colors.green,
      'AC_OFF' => Colors.blueGrey,
      'SUSPECT' => Colors.orange,
      'WARNING' => Colors.red,
      _ => Colors.grey,
    };

class _KartuUkuran extends StatelessWidget {
  final String label;
  final double nilai;
  final String satuan;
  final bool good;
  final String? statusOperasi;
  final bool isCurrent;

  const _KartuUkuran({
    required this.label,
    required this.nilai,
    required this.satuan,
    required this.good,
    this.statusOperasi,
    this.isCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = !good || statusOperasi != null;

    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text('${nilai.toStringAsFixed(2)} $satuan',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: !hasSubtitle
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (statusOperasi != null)
                    Text(
                      'Status ${isCurrent ? 'arus' : 'tegangan'}: '
                      '${isCurrent ? _labelStatusArus(statusOperasi!) : _labelStatusTegangan(statusOperasi!)}',
                      style: TextStyle(
                        color: isCurrent
                            ? _warnaStatusArus(statusOperasi!)
                            : _warnaStatusTegangan(statusOperasi!),
                      ),
                    ),
                  if (!good)
                    const Text(
                      'Kualitas kanal/pengukuran: SUSPECT - perlu diperiksa',
                      style: TextStyle(color: Colors.orange),
                    ),
                ],
              ),
      ),
    );
  }
}
