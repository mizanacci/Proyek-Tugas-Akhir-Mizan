# Troubleshooting Firebase

Periksa urutan berikut agar masalah broker tidak tertukar dengan masalah
database:

1. Pastikan Firebase Auth aktif pada panel diagnosa dan UID memiliki profil
   role yang benar di `/users/{uid}`.
2. Pastikan `/.info/connected` menunjukkan Connected. Ini hanya konektivitas,
   bukan bukti Rules mengizinkan write.
3. Pastikan MQTT broker Connected, subscription menerima ACK, payload diproses,
   dan sensor FRESH.
4. Periksa log `[Firebase] WRITE STARTED`, `WRITE SUCCESS`, atau `WRITE FAILED`
   beserta `error.code` dan path.
5. Untuk `permission-denied`, periksa Rules yang aktif, Auth UID, `oleh_uid`,
   field wajib, dan jenis/nilai field. Rules lokal belum otomatis dipublikasikan.
6. Tekan `Uji tulis Firebase` pada build debug. Record `FIREBASE_WRITE_TEST`
   muncul di `/data_activity` hanya bila write benar-benar sukses.

Jika aplikasi ditutup, subscriber berhenti dan snapshot tidak dikirim. Android
background service tidak menjamin proses tetap hidup. Untuk pengumpulan data
24/7, rancangan tahap lanjut adalah:

```text
ESP32 -> HiveMQ -> backend mqtt.js -> Firebase Admin SDK -> Realtime Database
```

Backend memvalidasi payload, memakai server timestamp, idempotency/sequence,
retry dan logging, serta dijalankan pada hosting dengan process supervision.
Service-account key dan credential MQTT hanya berada di secret store server.
Belum ada backend atau hosting yang dibuat/deploy dalam perubahan ini.