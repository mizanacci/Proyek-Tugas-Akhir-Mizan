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
  final int bitmaskKualitas; // bit0..3: V_sumber,V_beban,I_sumber,I_beban — 0=GOOD,1=SUSPECT
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
    return SensorData(
      teganganSumber: (json['v_sumber'] as num).toDouble(),
      teganganBeban: (json['v_beban'] as num).toDouble(),
      arusSumber: (json['i_sumber'] as num).toDouble(),
      arusBeban: (json['i_beban'] as num).toDouble(),
      bitmaskKualitas: (json['kualitas'] as num).toInt(),
      timestampMs: (json['ts'] as num).toInt(),
    );
  }

  bool get kualitasVSumberGood => (bitmaskKualitas & 0x01) == 0;
  bool get kualitasVBebanGood => (bitmaskKualitas & 0x02) == 0;
  bool get kualitasISumberGood => (bitmaskKualitas & 0x04) == 0;
  bool get kualitasIBebanGood => (bitmaskKualitas & 0x08) == 0;
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
