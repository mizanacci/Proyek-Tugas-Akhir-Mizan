# Struktur Workspace — Frontend Flutter & Backend Sisi IoT

**Tugas Akhir:** Perancangan Prototipe Sistem SCADA Distribusi Listrik Berbasis PLC OMRON yang Terintegrasi dengan Platform Monitoring IoT
**Penyusun:** Almar'u Zaim Mizan (04231006) — Teknik Elektro, Institut Teknologi Kalimantan

---

## 1. Struktur Folder Frontend (Flutter)

```
flutter_app/
├── pubspec.yaml              # dependency: mqtt_client, firebase_*, provider, intl
├── .gitignore                # mengecualikan kredensial Firebase & build artifact
└── lib/
    ├── main.dart              # entry point, inisialisasi Firebase, routing berbasis role
    ├── models/
    │   └── sensor_data.dart   # SensorData, StatusLink, UserRole
    ├── services/
    │   ├── mqtt_service.dart      # koneksi HiveMQ Cloud (TLS), publish/subscribe
    │   └── firebase_service.dart  # Auth (login/role) + Realtime Database (Data Activity, Settings)
    └── screens/
        ├── login_screen.dart
        ├── menu_manager_screen.dart          # role Manager: Monitoring, Data Activity (view-only)
        ├── menu_operator_screen.dart         # role Operator: + Kontrol & Monitoring LBS
        ├── monitoring_screen.dart            # dipakai bersama kedua role
        ├── kontrol_monitoring_lbs_screen.dart # KHUSUS Operator — satu-satunya layar kirim perintah NO/NC
        └── data_activity_screen.dart         # log riwayat dari Firebase
```

**Prinsip pemisahan role**: pembedaan hak akses Manager vs Operator dilakukan di **level routing/menu** (Manager tidak pernah mendapat kartu navigasi menuju `KontrolMonitoringLbsScreen`), bukan lewat pengecekan role tersembunyi di dalam satu layar universal. Ini membuat batasan akses lebih eksplisit dan mudah diaudit saat penyusunan BAB 4 — namun perlu dicatat sebagai **keterbatasan keamanan pada level UI saja**: jika suatu saat aplikasi diperluas dengan sumber ancaman yang lebih serius, pembatasan pada level *backend* (Firebase Security Rules, aturan akses topic MQTT) tetap diperlukan sebagai lapisan pertahanan sesungguhnya. [DRAF] Firebase Security Rules dan pembatasan akses topic HiveMQ per-role belum dirancang di dokumen ini — pertimbangkan sebagai pekerjaan lanjutan bila waktu TA memungkinkan, atau catat eksplisit sebagai keterbatasan pada BAB 4/5 laporan bila tidak sempat diimplementasikan.

Setup awal proyek Flutter (di luar cakupan dokumen ini, ikuti dokumentasi resmi saat implementasi):
1. `flutter create scada_mizan_app` (atau salin struktur di atas ke proyek yang sudah ada)
2. `flutterfire configure` untuk menghasilkan `lib/firebase_options.dart` (dan `main.dart` perlu disesuaikan menjadi `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` bila FlutterFire CLI dipakai — versi di dokumen ini memakai `Firebase.initializeApp()` tanpa opsi eksplisit sebagai penyederhanaan awal)
3. `flutter pub get`

---

## 2. Struktur Folder Backend Sisi IoT (Firmware)

```
firmware/
├── platformio.ini          # board esp32dev, lib_deps (ModbusRTU, PubSubClient, ArduinoJson)
├── .gitignore
├── README.md                # ringkasan desain, peta register, dua keputusan desain kunci
└── src/
    ├── config.h              # SUMBER KEBENARAN TUNGGAL: pin, peta register, kredensial, kalibrasi
    ├── shared_state.h         # primitif FreeRTOS untuk komunikasi aman Core 0 <-> Core 1
    ├── sensors.h/.cpp         # ADC + RMS, dibungkus readRawSensor() untuk migrasi ADS1115
    ├── modbus_slave.h/.cpp    # Modbus RTU slave + watchdog estimasi COMFail lokal
    ├── mqtt_handler.h/.cpp    # WiFi + MQTT (TLS, LWT) ke HiveMQ Cloud
    └── main.cpp               # setup()/loop(), pembuatan 2 task dual-core
```

Lihat `firmware/README.md` untuk peta register Modbus lengkap dan penjelasan dua keputusan desain (propagasi COMFail, handshake command remote) — tidak diulang di sini agar tidak ada dua sumber yang bisa saling tidak sinkron.

Setup awal proyek firmware:
1. Install ekstensi PlatformIO (VS Code) atau CLI `pip install platformio`
2. Buka folder `firmware/` sebagai proyek PlatformIO
3. Isi seluruh nilai `[DRAF]` di `src/config.h` (kredensial WiFi/MQTT, koefisien kalibrasi hasil dokumen 02, sertifikat CA di `mqtt_handler.cpp`)
4. `pio run -t upload` untuk build + flash ke ESP32

---

## 3. Skema JSON Firebase Realtime Database

```
/
├── users/
│   └── <uid>/
│       ├── email: string
│       ├── nama: string
│       └── role: "manager" | "operator"
│
├── data_activity/
│   └── <push_id>/                    # key otomatis dari push(), terurut waktu
│       ├── timestamp: ServerValue.timestamp
│       ├── aksi: "NO" | "NC"
│       ├── oleh_uid: string
│       ├── oleh_nama: string
│       └── sumber: "mobile"          # dibedakan dari "hmi"/"lokal" bila kelak log gabungan diperlukan
│
└── settings/
    ├── threshold_alarm/
    │   ├── tegangan_min: number
    │   ├── tegangan_max: number
    │   └── arus_max: number
    └── durasi_timeout: number         # detik, dipakai konsep LRUFail/COMFail timeout di proposal
```

**Catatan skema:**
- `users/<uid>/role` dibaca saat login (`firebase_service.dart`) untuk menentukan routing Manager/Operator — dokumen user harus dibuat **manual** oleh admin/pembimbing saat akun baru dibuat di Firebase Authentication Console (tidak ada layar pendaftaran mandiri di aplikasi ini, sesuai cakupan prototipe TA).
- `data_activity` hanya mencatat perintah yang **dikirim** dari aplikasi mobile, bukan konfirmasi eksekusi ladder logic PLC — lihat catatan di `kontrol_monitoring_lbs_screen.dart` soal potensi kebutuhan field status eksekusi terpisah.
- `settings/threshold_alarm` dan `durasi_timeout` disediakan skemanya, tapi **layar pengaturan (Setting Threshold Alarm/Setting Durasi Timeout) belum dibuat** pada struktur Deliverable 5 ini — service `firebase_service.dart` sudah punya fungsi baca/tulisnya (`ambilThresholdAlarm`, `simpanThresholdAlarm`, dst.), tinggal dibuatkan layar UI-nya bila diperlukan untuk BAB 4.

---

## 4. Skema Topic HiveMQ (Ringkasan — Detail di Dokumen 04)

| Topic | Payload | Dipakai Oleh |
|---|---|---|
| `scada/mizan/data/sensor` | `{v_sumber, v_beban, i_sumber, i_beban, kualitas, ts}` | ESP32 publish → Flutter subscribe |
| `scada/mizan/status/lrufail` | `{status, source}` | Broker (LWT) + ESP32 publish → Flutter subscribe |
| `scada/mizan/status/comfail` | `{status, source}` | ESP32 publish → Flutter subscribe |
| `scada/mizan/cmd/relay` | `{command: "NO"\|"NC"}` | Flutter (Operator) publish → ESP32 subscribe |

Struktur ini **identik** antara `config.h` (firmware), `mqtt_handler.cpp` (firmware), dan `mqtt_service.dart` (Flutter) — bila salah satu diubah saat implementasi, ketiganya harus diperbarui bersamaan agar tidak terjadi payload yang tidak terbaca di sisi lain.

---

## 5. Ringkasan Seluruh Deliverable & Keterkaitannya

| Dokumen | Fokus |
|---|---|
| `01_Panduan_Wiring.md` | Pengawatan fisik — dasar bagi pin di `config.h` |
| `02_Panduan_Kalibrasi_ZMPT101B.md` + `Template_Kalibrasi_ZMPT101B.xlsx` | Prosedur kalibrasi — hasilnya diisi ke `ZMPT_*_GAIN/OFFSET` di `config.h` |
| `firmware/` (kode + README) | Implementasi logika ADC/RMS/Modbus/MQTT — konsumen dari hasil dokumen 1 & 2 |
| `04_Konfigurasi_HiveMQ.md` | Setup broker — dasar bagi `MQTT_*` di `config.h` dan `mqtt_service.dart` |
| Dokumen ini (05) | Struktur proyek Flutter + backend IoT, skema Firebase, ringkasan topic |

---

## 6. Item yang Sengaja Belum Dibuat (Di Luar Cakupan Deliverable Ini)

Ditandai eksplisit agar tidak dianggap terlewat secara tidak sengaja:

- Layar Setting Threshold Alarm dan Setting Durasi Timeout (skema Firebase & fungsi service sudah tersedia, UI belum)
- Firebase Security Rules dan pembatasan akses topic MQTT per-role (lihat catatan keamanan Bagian 1)
- Unit test / widget test Flutter maupun test firmware (di luar permintaan awal prompt ini)
- Layout kondisional untuk tablet/layar besar (skeleton ini memakai layout dasar `GridView`/`ListView` yang responsif secukupnya, belum dioptimalkan untuk banyak ukuran layar)
- Mekanisme migrasi kode saat benar-benar berpindah ke ESP32-S3 + ADS1115 (sudah disiapkan titik migrasinya di `sensors.cpp`, tapi implementasi aktual kode ADS1115 belum ditulis — menunggu iterasi berikutnya sesuai rencana pada prompt awal)
