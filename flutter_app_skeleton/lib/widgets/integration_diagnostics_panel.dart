import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/event_logger.dart';
import '../services/firebase_service.dart';

class IntegrationDiagnosticsPanel extends StatelessWidget {
  const IntegrationDiagnosticsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final firebase = context.watch<FirebaseService>();
    final logger = context.watch<EventLogger>();
    final profile = firebase.profilSaatIni;

    return ExpansionTile(
      title: const Text('Diagnostik Firebase'),
      subtitle: Text(profile == null
          ? 'Profil aktif belum dimuat'
          : 'Role ${profile.role.name} · '
              '${profile.isActive ? 'aktif' : 'nonaktif'}'),
      children: [
        _statusRow('Firebase Auth',
            firebase.userSaatIni == null ? 'Belum login' : 'Login aktif'),
        StreamBuilder<bool>(
          stream: firebase.koneksiDatabase,
          builder: (context, snapshot) => _statusRow(
            'Realtime Database',
            snapshot.hasError
                ? 'Status gagal dibaca'
                : snapshot.data == null
                    ? 'Memeriksa koneksi'
                    : snapshot.data!
                        ? 'Connected'
                        : 'Disconnected',
          ),
        ),
        _statusRow(
            'Profil', profile == null ? 'Tidak valid/belum tersedia' : 'Valid'),
        _statusRow('EventLogger/session', logger.aktif ? 'ACTIVE' : 'INACTIVE'),
        _statusRow('Sumber monitoring', 'Firebase RTDB / gateway'),
      ],
    );
  }

  static Widget _statusRow(String label, String value) {
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: SizedBox(
        width: 190,
        child: Text(value,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
