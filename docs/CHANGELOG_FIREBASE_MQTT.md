# Changelog Integrasi Firebase dan MQTT

## 2026-11-08

- EventLogger diinisialisasi saat startup dan mengelola koneksi MQTT mengikuti
  sesi Firebase Auth. Perubahan halaman tidak lagi membuka koneksi tambahan.
- MQTT memakai Client ID acak yang tersimpan per instalasi, mencegah bentrok
  antar perangkat dengan UID yang sama.
- Ditambahkan status subscription ACK, reconnect, pesan diterima/diproses,
  error parse, jumlah publish gagal, dan freshness sensor 15 detik.
- Snapshot `/data_activity` hanya menulis sampel valid, fresh, dan belum sukses
  dicatat; timestamp server dipisahkan dari waktu terima Flutter dan uptime ESP32.
- Firebase memakai default database URL dari `FirebaseOptions`, stream
  `/.info/connected`, pencatatan hasil write, serta write-test debug.
- Rules lokal membatasi write record pada UID Auth sendiri, mencegah client
  menulis profil/role, mengindeks timestamp, dan membatasi edit Settings ke Manager.
- Aktivitas command mencatat `PUBLISHED` atau `REJECTED`; publish bukan feedback
  eksekusi PLC.
- Firmware menggunakan CA ISRG Root X1 dan memeriksa hasil publish sensor serta
  COMFail. Data sensor tetap QoS 0.
- Ditambahkan panel diagnostik, unit test parser/Client ID, dan dokumentasi pada
  `docs/`.

Rules belum dipublikasikan. Integrasi broker, Firebase aktif, dan perangkat
fisik masih perlu tes manual.