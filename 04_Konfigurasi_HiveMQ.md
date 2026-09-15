# Konfigurasi HiveMQ Cloud — Prototipe SCADA Distribusi Listrik

**Tugas Akhir:** Perancangan Prototipe Sistem SCADA Distribusi Listrik Berbasis PLC OMRON yang Terintegrasi dengan Platform Monitoring IoT
**Penyusun:** Almar'u Zaim Mizan (04231006) — Teknik Elektro, Institut Teknologi Kalimantan

> ⚠️ Langkah dan istilah antarmuka pada dokumen ini mengikuti tampilan HiveMQ Cloud Console pada saat dokumen ini disusun. Antarmuka layanan pihak ketiga dapat berubah sewaktu-waktu — **verifikasi ulang terhadap dokumentasi resmi HiveMQ** (`https://docs.hivemq.com/hivemq-cloud/`) saat benar-benar melakukan setup, terutama bila langkah di bawah tidak lagi cocok dengan tampilan yang dijumpai.

---

## 1. Pembuatan Cluster Serverless (Gratis)

1. Buka `https://console.hivemq.cloud` dan buat akun (atau masuk bila sudah punya).
2. Pilih **Create Serverless Cluster** (tingkat gratis, tanpa perlu kartu kredit).
3. Beri nama cluster yang mudah dikenali, misalnya `scada-mizan-ta`.
4. Tunggu proses provisioning selesai (biasanya beberapa detik hingga menit).
5. Catat **Cluster URL/Hostname** yang muncul di halaman *Overview* setelah cluster aktif — formatnya umumnya `xxxxxxxxxx.s1.eu.hivemq.cloud` (region bisa berbeda). Nilai ini yang diisikan ke `MQTT_HOST` pada `config.h` firmware.

### Batas Tingkat Gratis (Serverless) — verifikasi ulang di dokumentasi resmi

| Batasan | Nilai per dokumentasi saat ini |
|---|---|
| Koneksi bersamaan | 100 |
| Kuota data bulanan | 10 GB |
| Protokol didukung | MQTT 3.1, 3.1.1, 5.0 |
| Enkripsi | TLS/SSL |
| SLA uptime | Tidak dijamin (sesuai untuk pengembangan/prototipe, bukan produksi) |

Untuk prototipe TA dengan satu perangkat ESP32 dan satu aplikasi mobile, batas ini jauh mencukupi — namun tetap verifikasi ulang ke `https://www.hivemq.com/pricing/` sebelum implementasi akhir, karena kebijakan tingkat gratis penyedia layanan dapat berubah.

---

## 2. Pembuatan Kredensial Device (Access Management)

1. Pada dashboard cluster yang baru dibuat, buka tab **Access Management**.
2. Buat kredensial baru untuk ESP32, misalnya username `esp32-scada-device`.
3. Buat kredensial **terpisah** untuk aplikasi Flutter (disarankan tidak berbagi kredensial yang sama antar-jenis client, agar hak akses/izin topic bisa diatur berbeda bila diperlukan di kemudian hari), misalnya `flutter-app-manager` dan `flutter-app-operator` bila ingin membedakan izin per role.
4. Catat username + password masing-masing — **password hanya ditampilkan sekali saat dibuat**, simpan dengan aman (jangan commit ke repository Git; lihat catatan `.gitignore` pada dokumen Struktur Workspace).
5. Isikan kredensial ESP32 ke `MQTT_USERNAME`/`MQTT_PASSWORD` pada `config.h` firmware, dan kredensial Flutter ke service MQTT aplikasi (lihat dokumen 05).
6. Username = esp32-scada-device, pass = MQQTmizan15! 
7. Username = flutter-app-manager, pass = MQQTmizan16!
8. Username = flutter-app-operator, pass = MQQTmizan17!

---

## 3. Aktivasi TLS

TLS pada HiveMQ Cloud **aktif secara default** untuk seluruh cluster (tidak ada opsi menonaktifkannya pada tingkat gratis) — tidak ada langkah konfigurasi tambahan di sisi HiveMQ. Yang perlu dipastikan di sisi **client**:

- **Port**: gunakan **8883** (MQTT over TLS), bukan 1883 (MQTT polos tanpa TLS — umumnya tidak dibuka pada HiveMQ Cloud).
- **Sertifikat CA**: HiveMQ Cloud menerbitkan sertifikat lewat Let's Encrypt. Firmware ESP32 perlu root CA ini melalui `WiFiClientSecure::setCACert()` (lihat `mqtt_handler.cpp`, konstanta `CA_CERT_LETSENCRYPT`) — unduh root CA "ISRG Root X1" dari `https://letsencrypt.org/certificates/`.
- Aplikasi Flutter umumnya menangani validasi TLS otomatis melalui package MQTT yang dipakai (`mqtt_client` memakai *trust store* sistem operasi secara default) — biasanya tidak perlu konfigurasi manual sertifikat di sisi Flutter, tapi verifikasi ulang terhadap dokumentasi package `mqtt_client` versi yang dipakai bila terjadi error koneksi TLS.

---

## 4. Struktur Topic

| Topic | Arah | Isi | QoS Disarankan |
|---|---|---|---|
| `scada/mizan/data/sensor` | ESP32 → publish | JSON: `v_sumber`, `v_beban`, `i_sumber`, `i_beban`, `kualitas` (bitmask), `ts` | 0 (data periodik, kehilangan sesekali dapat diterima) |
| `scada/mizan/status/lrufail` | Broker → publish otomatis (LWT) + ESP32 publish saat connect | JSON: `status` (`NORMAL`/`FAIL`), `source` | 1 |
| `scada/mizan/status/comfail` | ESP32 → publish | JSON: `status`, `source: "esp32_watchdog_estimate"` (lihat catatan desain di README firmware — ini estimasi, bukan pembacaan langsung status PLC) | 1 |
| `scada/mizan/cmd/relay` | Aplikasi (Operator) → publish, ESP32 subscribe | JSON: `{"command":"NO"}` atau `{"command":"NC"}` | 1 (perintah kontrol, disarankan minimal QoS 1 agar terjamin sampai) |

**Prefix `scada/mizan/`** dipakai agar topic tidak bentrok bila cluster yang sama kelak dipakai untuk keperluan lain — sesuaikan bila konvensi penamaan lab/kampus berbeda.

---

## 5. Setup LWT (Last Will and Testament)

LWT **didaftarkan di level koneksi client**, bukan dikonfigurasi terpisah di HiveMQ Console — tidak ada langkah UI khusus di sisi HiveMQ untuk ini. Firmware ESP32 mendaftarkan LWT sebagai bagian dari parameter `connect()` (lihat `mqtt_handler.cpp`, fungsi `mqttReconnect()`):

- **Will Topic**: `scada/mizan/status/lrufail`
- **Will Payload**: `{"status":"FAIL","source":"lwt"}`
- **Will QoS**: 1
- **Will Retain**: `true` — agar client yang baru subscribe (misalnya aplikasi mobile baru dibuka) langsung mendapat status LRUFail terakhir yang diketahui, tanpa perlu menunggu pesan berikutnya.

Broker akan **otomatis mempublikasikan** payload ini ke topic tersebut jika koneksi TCP client terputus tanpa proses `DISCONNECT` yang bersih (misal WiFi mati mendadak, ESP32 restart tak terduga, kabel putus) — inilah mekanisme deteksi LRUFail sisi ESP32/broker, terpisah dari mekanisme COMFail (watchdog Modbus RTU sisi PLC).

---

## 6. Uji Pub/Sub via HiveMQ Web Client (Sebelum ke Firmware)

Sebelum menguji dengan firmware fisik, verifikasi dahulu topic dan kredensial berfungsi memakai **HiveMQ Web Client** bawaan console (tab **Web Client** pada dashboard cluster):

1. Buka Web Client, masukkan kredensial (boleh pakai kredensial ESP32 atau buat kredensial uji terpisah).
2. **Uji publish**: subscribe ke `scada/mizan/data/sensor` dari satu tab, lalu publish payload JSON contoh dari tab lain — verifikasi pesan diterima.
3. **Uji command**: subscribe ke `scada/mizan/cmd/relay`, publish `{"command":"NO"}` — pastikan format JSON valid dan sesuai yang diharapkan `mqttCallback()` pada firmware.
4. **Uji LWT**: buka koneksi baru dengan LWT terdaftar (Web Client biasanya punya opsi Last Will di pengaturan koneksi lanjutan), lalu putuskan koneksi secara paksa (tutup tab tanpa disconnect resmi bila memungkinkan, atau matikan jaringan sesaat) — verifikasi topic LWT menerima pesan otomatis dari broker.
5. Baru setelah ketiga uji ini berhasil, lanjutkan ke pengujian dengan firmware ESP32 fisik — ini mengisolasi masalah konfigurasi HiveMQ dari kemungkinan bug firmware.

---

## 7. Checklist Sebelum Lanjut ke Firmware

- [ ] Cluster Serverless aktif, hostname tercatat
- [ ] Kredensial ESP32 dan Flutter dibuat terpisah, tersimpan aman (tidak di Git)
- [ ] Port 8883 + root CA Let's Encrypt siap dipakai firmware
- [ ] Keempat topic pada Bagian 4 berhasil diuji publish/subscribe via Web Client
- [ ] LWT terverifikasi terpicu otomatis saat koneksi diputus paksa
- [ ] Kuota tingkat gratis (100 koneksi, 10GB/bulan) dicek ulang masih berlaku di `hivemq.com/pricing`
