/// sensor_data.dart — Model data hasil pengukuran dari topic MQTT data/sensor
/// Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)
///
/// Struktur field HARUS sinkron dengan payload JSON yang dipublikasikan
/// firmware ESP32 (lihat mqtt_handler.cpp, fungsi mqttPublishDataSensor,
/// dan dokumen 04_Konfigurasi_HiveMQ.md Bagian 4).

class SensorData {
  final double teganganSumber;
  final double teganganBeban;
  final double arusSumber;
  final double arusBeban;
  final int
      bitmaskKualitas; // bit0..3: V_sumber,V_beban,I_sumber,I_beban — 0=GOOD,1=SUSPECT
  final int timestampMs;

  SensorData({
    required this.teganganSumber,
    required this.teganganBeban,
    required this.arusSumber,
    required this.arusBeban,
    required this.bitmaskKualitas,
    required this.timestampMs,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    num angka(String nama) {
      final value = json[nama];
      if (value is! num || !value.isFinite) {
        throw FormatException(
          'Field sensor "$nama" harus berupa angka finite.',
        );
      }
      return value;
    }

    return SensorData(
      teganganSumber: angka('v_sumber').toDouble(),
      teganganBeban: angka('v_beban').toDouble(),
      arusSumber: angka('i_sumber').toDouble(),
      arusBeban: angka('i_beban').toDouble(),
      bitmaskKualitas: angka('kualitas').toInt(),
      timestampMs: angka('ts').toInt(),
    );
  }

  bool get kualitasVSumberGood => (bitmaskKualitas & 0x01) == 0;
  bool get kualitasVBebanGood => (bitmaskKualitas & 0x02) == 0;
  bool get kualitasISumberGood => (bitmaskKualitas & 0x04) == 0;
  bool get kualitasIBebanGood => (bitmaskKualitas & 0x08) == 0;
}

enum LinkState { unknown, normal, fail }

enum SystemConnectionState {
  disconnected,
  deviceOffline,
  waitingDevice,
  degraded,
  connected,
}

SystemConnectionState resolveSystemConnectionState({
  required bool applicationConnected,
  required LinkState lruState,
  required LinkState comState,
  required bool dataStale,
}) {
  if (!applicationConnected) return SystemConnectionState.disconnected;
  if (lruState == LinkState.fail || dataStale) {
    return SystemConnectionState.deviceOffline;
  }
  if (lruState == LinkState.unknown) {
    return SystemConnectionState.waitingDevice;
  }
  if (comState == LinkState.fail) {
    return SystemConnectionState.degraded;
  }
  return comState == LinkState.unknown
      ? SystemConnectionState.waitingDevice
      : SystemConnectionState.connected;
}

/// Status NORMAL/FAIL generik — dipakai untuk LRUFail maupun estimasi COMFail.
class StatusLink {
  final bool normal; // true = NORMAL, false = FAIL
  final String source;

  StatusLink({required this.normal, required this.source});

  factory StatusLink.fromJson(Map<String, dynamic> json) {
    return StatusLink(
      normal: (json['status'] as String).toUpperCase() == 'NORMAL',
      source: json['source'] as String? ?? '',
    );
  }
}

/// Peran pengguna aplikasi — menentukan routing & hak akses layar.
enum UserRole { manager, operator }
