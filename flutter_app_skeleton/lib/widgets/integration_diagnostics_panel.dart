import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/event_logger.dart';
import '../services/firebase_service.dart';

class IntegrationDiagnosticsPanel extends StatelessWidget {
  const IntegrationDiagnosticsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final firebase = context.watch<FirebaseService>();
    final profile = firebase.profilSaatIni;

    final subtitle = profile == null
        ? 'Profil aktif belum dimuat'
        : 'Role ${profile.role.name} · '
            '${profile.isActive ? 'aktif' : 'nonaktif'}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.health_and_safety_outlined),
        title: const Text('Diagnostik Firebase'),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => _openDiagnostics(context),
      ),
    );
  }

  void _openDiagnostics(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Consumer2<FirebaseService, EventLogger>(
        builder: (context, firebase, logger, _) {
          final profile = firebase.profilSaatIni;

          return AlertDialog(
            title: const Text('Diagnostik Firebase'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 420,
                maxHeight: 360,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _statusRow(
                      'Firebase Auth',
                      firebase.userSaatIni == null
                          ? 'Belum login'
                          : 'Login aktif',
                    ),
                    const Divider(height: 1),
                    StreamBuilder<bool>(
                      stream: firebase.koneksiDatabase,
                      initialData: firebase.statusKoneksiDatabase,
                      builder: (context, snapshot) {
                        final status = snapshot.hasError
                            ? 'Status gagal dibaca'
                            : snapshot.data == null
                                ? 'Memeriksa koneksi'
                                : snapshot.data!
                                    ? 'Connected'
                                    : 'Disconnected';

                        return _statusRow(
                          'Realtime Database',
                          status,
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _statusRow(
                      'Profil',
                      profile == null ? 'Tidak valid/belum tersedia' : 'Valid',
                    ),
                    const Divider(height: 1),
                    _statusRow(
                      'EventLogger/session',
                      logger.aktif ? 'ACTIVE' : 'INACTIVE',
                    ),
                    const Divider(height: 1),
                    _statusRow(
                      'Sumber monitoring',
                      'Firebase RTDB / gateway',
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Tutup'),
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _statusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(label),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
