/// data_activity_screen.dart — Layar Data Activity (Gambar 3.14 mock-up proposal)
/// Menampilkan log audit read-only dari Firebase Realtime Database.
/// Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';

class DataActivityScreen extends StatelessWidget {
  const DataActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseService = context.read<FirebaseService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Data Activity')),
      body: StreamBuilder<DatabaseEvent>(
        stream: firebaseService.streamDataActivity(batas: 100),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Data Activity tidak dapat dibaca. Pastikan sudah login dan '
                  'Security Rules Firebase sudah dipublikasikan.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final value = snapshot.data?.snapshot.value;
          if (value == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Belum ada riwayat. Riwayat tercatat saat perintah dikirim '
                  'atau status LRUFail/COMFail berubah.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final raw = Map<dynamic, dynamic>.from(value as Map);
          final entries = raw.values
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
            ..sort(
              (a, b) => _timestamp(b).compareTo(_timestamp(a)),
            );

          if (entries.isEmpty) {
            return const Center(
              child: Text(
                'Belum ada riwayat. Riwayat tercatat saat perintah dikirim '
                'atau status LRUFail/COMFail berubah.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              columns: const [
                DataColumn(label: Text('No')),
                DataColumn(label: Text('Tanggal')),
                DataColumn(label: Text('Waktu')),
                DataColumn(label: Text('Alarm/Status')),
              ],
              rows: [
                for (var index = 0; index < entries.length; index++)
                  _buildRow(entries[index], entries.length - index),
              ],
            ),
          );
        },
      ),
    );
  }

  static DataRow _buildRow(Map<String, dynamic> item, int number) {
    final jenis = item['jenis'] as String? ?? 'PERINTAH';
    final keterangan = _keterangan(item);
    final waktu =
        DateTime.fromMillisecondsSinceEpoch(_timestamp(item)).toLocal();
    final warna = switch (jenis) {
      'ALARM' => Colors.orange.shade50,
      'STATUS' => Colors.green.shade50,
      _ => Colors.blue.shade50,
    };

    return DataRow(
      color: WidgetStatePropertyAll<Color>(warna),
      cells: [
        DataCell(Text('$number')),
        DataCell(Text(DateFormat('dd/MM/yyyy').format(waktu))),
        DataCell(Text(DateFormat('HH:mm:ss').format(waktu))),
        DataCell(
          SizedBox(
            width: 360,
            child: Text(keterangan),
          ),
        ),
      ],
    );
  }

  static int _timestamp(Map<String, dynamic> item) {
    final value = item['timestamp'];
    return value is num ? value.toInt() : 0;
  }

  static String _keterangan(Map<String, dynamic> item) {
    final jenis = item['jenis'] as String?;
    if (jenis == null) {
      final aksi = item['aksi'] as String? ?? '-';
      final nama = item['oleh_nama'] as String?;
      return 'Perintah $aksi${nama == null ? '' : ' — oleh $nama'}';
    }
    final keterangan = item['keterangan'] as String? ?? '-';
    if (jenis == 'PERINTAH') {
      final nama = item['oleh_nama'] as String?;
      return '$keterangan${nama == null ? '' : ' — oleh $nama'}';
    }
    return keterangan;
  }
}
