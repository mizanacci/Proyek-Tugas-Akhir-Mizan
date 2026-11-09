/// data_activity_screen.dart — Layar Data Activity (Gambar 3.14 mock-up proposal)
/// Menampilkan log audit read-only dari Firebase Realtime Database.
/// Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/scada_data.dart';
import '../services/scada_service.dart';
import '../widgets/integration_diagnostics_panel.dart';

class DataActivityScreen extends StatelessWidget {
  const DataActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scadaService = context.read<ScadaService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat & Command')),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const IntegrationDiagnosticsPanel(),
            const TabBar(
              tabs: [
                Tab(text: 'Aktivitas'),
                Tab(text: 'Perintah'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _activityTab(scadaService),
                  _commandTab(scadaService),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activityTab(ScadaService scadaService) {
    return StreamBuilder<Object?>(
      stream: scadaService.watchActivity(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child:
                  Text('Data Activity tidak dapat dibaca: ${snapshot.error}'),
            ),
          );
        }
        final value = snapshot.data;
        if (value == null) {
          return const Center(
              child: Text('Belum ada riwayat dari gateway/backend.'));
        }
        if (value is! Map) {
          return const Center(
            child: Text('Format data_activity tidak valid di Firebase.'),
          );
        }

        final entries = Map<dynamic, dynamic>.from(value)
            .values
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
          ..sort((first, second) =>
              _timestamp(second).compareTo(_timestamp(first)));
        if (entries.isEmpty) {
          return const Center(child: Text('Belum ada riwayat dari backend.'));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 20,
            columns: const [
              DataColumn(label: Text('Waktu')),
              DataColumn(label: Text('Jenis')),
              DataColumn(label: Text('Pengguna')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Command ID')),
              DataColumn(label: Text('Keterangan')),
            ],
            rows: [for (final entry in entries) _buildRow(entry)],
          ),
        );
      },
    );
  }

  Widget _commandTab(ScadaService scadaService) {
    return StreamBuilder<List<ScadaCommand>>(
      stream: scadaService.watchCommands(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child:
                  Text('Daftar command tidak dapat dibaca: ${snapshot.error}'),
            ),
          );
        }
        final commands = snapshot.data ?? const <ScadaCommand>[];
        if (commands.isEmpty) {
          return const Center(child: Text('Belum ada permintaan command.'));
        }
        return ListView.builder(
          itemCount: commands.length,
          itemBuilder: (context, index) {
            final command = commands[index];
            return StreamBuilder<ScadaCommandResult?>(
              stream: scadaService.watchCommandResult(command.commandId),
              builder: (context, resultSnapshot) {
                final result = resultSnapshot.data;
                final resultText = resultSnapshot.hasError
                    ? 'Hasil gagal dibaca'
                    : result == null
                        ? 'Menunggu gateway'
                        : '${result.status.name.toUpperCase()}: ${result.detail}';
                return ListTile(
                  leading: const Icon(Icons.outbox_outlined),
                  title: Text('${command.action} · ${command.target}'),
                  subtitle: Text(
                    'Request: ${command.status} · ${command.createdByName} · '
                    '${_formatWaktu(command.createdAt)}\n'
                    'Hasil gateway: $resultText',
                  ),
                  isThreeLine: true,
                );
              },
            );
          },
        );
      },
    );
  }

  static DataRow _buildRow(Map<String, dynamic> item) {
    final jenis = item['jenis'] as String? ?? 'PERINTAH';
    final waktu = _formatWaktu(_timestamp(item));
    final warna = switch (jenis) {
      'ALARM' => Colors.orange.shade50,
      'STATUS' => Colors.green.shade50,
      _ => Colors.blue.shade50,
    };

    return DataRow(
      color: WidgetStatePropertyAll<Color>(warna),
      cells: [
        DataCell(Text(waktu)),
        DataCell(Text(jenis)),
        DataCell(Text(item['oleh_nama'] as String? ?? 'Sistem')),
        DataCell(Text(item['status'] as String? ?? '-')),
        DataCell(Text(item['command_id'] as String? ?? '-')),
        DataCell(
          SizedBox(
            width: 420,
            child: Text(item['keterangan'] as String? ?? '-'),
          ),
        ),
      ],
    );
  }

  static int _timestamp(Map<String, dynamic> item) {
    final value = item['timestamp'];
    return value is num ? value.toInt() : 0;
  }

  static String _formatWaktu(int millisecondsSinceEpoch) {
    if (millisecondsSinceEpoch <= 0) return '-';
    final waktu =
        DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch).toLocal();
    return '${DateFormat('dd/MM/yyyy').format(waktu)} '
        '${DateFormat('HH:mm:ss').format(waktu)}';
  }
}
