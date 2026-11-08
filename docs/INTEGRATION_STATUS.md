# Status Integrasi

Status lokal berdasarkan pemeriksaan kode dan perintah yang dijalankan pada
2026-11-08. Status ini bukan bukti perangkat fisik atau Firebase Console.

| Komponen | Status | Bukti / batasan |
|---|---|---|
| ESP32 publish MQTT | Kode diperbaiki | Validasi JSON, cek hasil publish, TLS CA; build PlatformIO tidak dijalankan karena CLI tidak tersedia |
| HiveMQ menerima pesan | Belum diverifikasi | Tidak melakukan koneksi broker dari sesi ini |
| Flutter subscribe | Kode diperbaiki | Auto-resubscribe dan subscription ACK; belum diuji ke broker langsung |
| Parsing payload | Lulus unit test | Kasus valid, field hilang, tipe salah, null dan non-finite |
| EventLogger aktif | Diperbaiki | Provider eager dan Auth listener; belum diuji dengan Firebase nyata |
| Firebase Auth | Belum diverifikasi | Memerlukan akun/proyek aktif dan sesi pengguna |
| RTDB connected | Instrumentasi tersedia | `/.info/connected`; tidak diuji terhadap project produksi |
| Firebase manual write | Instrumentasi debug tersedia | Belum dijalankan pada project; tidak ada write produksi dari sesi ini |
| Snapshot otomatis | Kode diperbaiki | Freshness 15 detik, subscription-ready, fingerprint sampel; belum diuji live |
| Data Activity read | Implementasi tersedia | Stream path `/data_activity`; belum diuji pada database aktif |
| Database Rules | JSON lokal valid | Belum deploy; Emulator tidak jalan karena butuh JDK 21 |
| Flutter analyze/test | Lulus | `flutter analyze`; 12 Flutter tests lulus |
| APK debug/release | Lulus | Keduanya berhasil dibangun; manifest release memuat INTERNET |
| ESP32/PLC fisik | Belum diuji | Membutuhkan PlatformIO, perangkat, broker dan jaringan |

Penyimpanan berhenti ketika aplikasi Flutter ditutup. Untuk operasi 24/7 perlu
backend MQTT-to-Firebase dan hosting; backend belum dibuat atau dideploy.