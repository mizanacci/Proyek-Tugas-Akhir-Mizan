# Alur Data MQTT ke Firebase

```mermaid
flowchart LR
  ESP[ESP32 sensor] -->|QoS 0 JSON setiap 5 s| Broker[HiveMQ Cloud]
  Broker -->|TLS MQTT| App[Flutter MqttService]
  Auth[Firebase Auth] --> Session[EventLogger]
  App -->|payload valid| Session
  Session -->|sampel segar dan baru| RTDB[(Realtime Database /data_activity)]
  RTDB --> Activity[Data Activity]
  RTDB --> Diagnostics[Panel diagnostik]
```

ESP32 tidak menulis ke Firebase. Flutter menjadi subscriber sekaligus client
yang menulis ke `/data_activity`; penulisan otomatis berjalan selama aplikasi
hidup, pengguna Firebase login, broker tersambung, subscription di-ACK, dan
data sensor belum stale.

`EventLogger` dibuat saat startup melalui Provider `lazy: false`. Saat Auth
berubah, logger memuat role, mengelola satu koneksi MQTT, dan memutus sesi pada
logout/perubahan UID. Navigasi ke Data Activity tidak memulai atau memutus MQTT.

Snapshot diperiksa tiap 10 detik. Snapshot dilewati bila data stale (batas awal
15 detik), subscription belum siap, atau fingerprint sampel sama dengan sampel
terakhir yang sukses ditulis. `timestamp` adalah waktu server Firebase,
`received_at` waktu lokal Flutter, dan `device_ts_ms` adalah uptime `millis()`
ESP32, bukan waktu kalender.

Penyimpanan tidak berlangsung ketika proses aplikasi ditutup. Untuk rekaman
kontinu diperlukan backend MQTT-to-Firebase yang berjalan di hosting; rancangan
tahap berikutnya dijelaskan pada `FIREBASE_TROUBLESHOOTING.md`.