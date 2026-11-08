import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/event_logger.dart';
import '../services/firebase_service.dart';
import '../services/mqtt_service.dart';

class IntegrationDiagnosticsPanel extends StatelessWidget {
  const IntegrationDiagnosticsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final firebase = context.watch<FirebaseService>();
    final mqtt = context.watch<MqttService>();
    final logger = context.read<EventLogger>();

    return ExpansionTile(
      title: const Text('Diagnostik integrasi'),
      subtitle: Text(
        'MQTT ${mqtt.terhubung ? 'terhubung' : 'terputus'} · '
        'Firebase ${_writeState(firebase)}',
      ),
      initiallyExpanded: kDebugMode,
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
            'MQTT broker', mqtt.terhubung ? 'Connected' : 'Disconnected'),
        _statusRow(
            'MQTT Client ID', mqtt.clientIdForDiagnostics ?? 'Belum dibuat'),
        _statusRow('MQTT subscription',
            mqtt.subscriptionReady ? 'ACK diterima' : 'Menunggu ACK'),
        _statusRow(
            'Payload sensor',
            'Diterima ${mqtt.jumlahPayloadSensorDiterima} · '
                'diproses ${mqtt.jumlahPayloadSensorDiproses}'),
        _statusRow('Pesan MQTT terakhir', _time(mqtt.lastMessageReceivedAt)),
        _statusRow(
            'Kesegaran sensor', mqtt.dataBasi ? 'STALE / UNKNOWN' : 'FRESH'),
        _statusRow('EventLogger', logger.aktif ? 'ACTIVE' : 'INACTIVE'),
        _statusRow('Snapshot Firebase',
            '${_writeState(firebase)} · berhasil ${firebase.jumlahSnapshotBerhasil}'),
        _statusRow(
            'Write terakhir berhasil', _time(firebase.terakhirTulisBerhasil)),
        if (firebase.errorTerakhirDatabase != null)
          _statusRow('Error Firebase', firebase.errorTerakhirDatabase!),
        if (mqtt.lastParseError != null)
          _statusRow('Parse error MQTT', mqtt.lastParseError!),
        if (mqtt.errorTerakhir != null)
          _statusRow('Error MQTT', mqtt.errorTerakhir!),
        if (kDebugMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () async {
                  try {
                    final key = await firebase.ujiTulisDatabase();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Firebase write sukses: $key')),
                      );
                    }
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Firebase write gagal: $error')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Uji tulis Firebase'),
              ),
            ),
          ),
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

  static String _writeState(FirebaseService service) {
    return switch (service.hasilTulisTerakhir) {
      true => 'write sukses',
      false => 'write gagal',
      null => 'belum ada write',
    };
  }

  static String _time(DateTime? value) =>
      value?.toLocal().toString() ?? 'Belum ada';
}
