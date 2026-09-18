/// menu_manager_screen.dart — Menu role Manager (Gambar 3.10 mock-up proposal)
/// Manager bersifat view-only: Monitoring dan Data Activity, TANPA akses
/// kontrol relay (lihat kontrol_monitoring_lbs_screen.dart — khusus Operator).
/// Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../models/sensor_data.dart';
import 'monitoring_screen.dart';
import 'data_activity_screen.dart';
import 'login_screen.dart';

class MenuManagerScreen extends StatelessWidget {
  const MenuManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<FirebaseService>().logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          _MenuCard(
            ikon: Icons.monitor_heart_outlined,
            label: 'Monitoring',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MonitoringScreen(bisaKontrol: false, role: UserRole.manager)),
            ),
          ),
          _MenuCard(
            ikon: Icons.history,
            label: 'Data Activity',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DataActivityScreen()),
            ),
          ),
          // Manager TIDAK mendapat kartu "Kontrol & Monitoring LBS" — role
          // ini view-only sesuai Batasan Rancangan proposal.
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData ikon;
  final String label;
  final VoidCallback onTap;

  const _MenuCard({required this.ikon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(ikon, size: 48),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
