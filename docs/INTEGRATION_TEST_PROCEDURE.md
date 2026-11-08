# Prosedur Pengujian Integrasi

## Otomatis

Dari `flutter_app_skeleton`:

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
```

Dari `firmware_esp32` (memerlukan PlatformIO CLI):

```powershell
pio run
```

Tes unit tidak boleh memakai credential lokal atau koneksi broker sungguhan.
Tes Client ID hanya menggunakan mock SharedPreferences.

## Manual, tahap demi tahap

1. Gunakan HiveMQ Web Client untuk publish payload uji pada
   `scada/mizan/data/sensor`; pastikan subscriber menerima topic.
2. Pastikan panel Flutter menghitung payload diterima dan diproses; kirim JSON
   rusak/field wajib hilang hanya pada broker uji untuk mengamati parse error.
3. Login ke Firebase, pastikan RTDB Connected, lalu jalankan write test debug.
4. Pastikan `FIREBASE_WRITE_TEST` tampil di `/data_activity` dan layar Data
   Activity membacanya.
5. Jalankan ESP32 dan verifikasi log publish firmware, payload panel, write
   sukses Firebase, lalu record tampil di Data Activity.
6. Putuskan broker/internet untuk menguji reconnect dan status stale; jangan
   menyatakan tes fisik lulus tanpa perangkat yang benar-benar diuji.

`firebase.json` saat ini belum mengonfigurasi Emulator. Jangan menjalankan
deployment Rules sebagai pengganti tes lokal; deployment memerlukan review dan
persetujuan terpisah.