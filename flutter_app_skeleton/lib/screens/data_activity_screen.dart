/// data_activity_screen.dart — Layar Data Activity (Gambar 3.14 mock-up proposal)
/// Menampilkan log riwayat perintah dari Firebase Realtime Database.
/// Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/firebase_service.dart';

class DataActivityScreen extends StatelessWidget {
  const DataActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseService = context.read<FirebaseService>();
    final formatWaktu = DateFormat('dd/MM/yyyy HH:mm:ss');

    return Scaffold(
      appBar: AppBar(title: const Text('Data Activity')),
      body: StreamBuilder<DatabaseEvent>(
        stream: firebaseService.streamDataActivity(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(child: Text('Belum ada riwayat aktivitas.'));
          }

          final Map<dynamic, dynamic> raw = snapshot.data!.snapshot.value as Map;
          final entri = raw.entries.map((e) => Map<String, dynamic>.from(e.value)).toList()
            ..sort((a, b) => (b['timestamp'] as int? ?? 0).compareTo(a['timestamp'] as int? ?? 0));

          return ListView.separated(
            itemCount: entri.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final item = entri[i];
              final aksi = item['aksi'] as String? ?? '-';
              final waktuMs = item['timestamp'] as int?;
              final waktuStr = waktuMs != null
                  ? formatWaktu.format(DateTime.fromMillisecondsSinceEpoch(waktuMs))
                  : '-';

              return ListTile(
                leading: Icon(
                  aksi == 'NC' ? Icons.lock : Icons.lock_open,
                  color: aksi == 'NC' ? Colors.green : Colors.red,
                ),
                title: Text('Perintah $aksi'),
                subtitle: Text('${item['oleh_nama'] ?? '-'} \u2022 sumber: ${item['sumber'] ?? '-'}'),
                trailing: Text(waktuStr, style: const TextStyle(fontSize: 12)),
              );
            },
          );
        },
      ),
    );
  }
}
