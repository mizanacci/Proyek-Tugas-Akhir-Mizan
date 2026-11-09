# Prosedur Pengujian Integrasi

## Otomatis

Dari `flutter_app_skeleton`:

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

Dari `firmware_esp32` (memerlukan PlatformIO CLI):

```powershell
pio run
```

Tes unit tidak boleh memakai credential lokal, menulis node backend, atau
memerlukan koneksi broker sungguhan. Tes command menggunakan database mock.

## Manual, tahap demi tahap

1. Login sebagai Manager; verifikasi role, telemetry, commands, results, dan
   Data Activity dapat dibaca serta tidak tersedia jalur untuk membuat command.
2. Login sebagai Operator; verifikasi pembacaan yang sama tetap tersedia.
3. Buat request `OPEN` dan `CLOSE`; pastikan hanya request `PENDING` muncul di
   `/commands`. Status ini bukan bukti gateway meneruskan command atau PLC
   menggerakkan LBS.
4. Buka/tutup panel diagnostik berulang kali, berpindah halaman, lalu logout
   dan login ulang. Pastikan tidak ada duplicate listener atau lifecycle error.
5. Pastikan `/telemetry`, `/command_results`, dan `/data_activity` hanya ditulis
   oleh gateway/backend. Flutter tidak menyediakan tombol write test.
6. Untuk pengujian backend, gunakan gateway dan RTDB yang disetujui; verifikasi
   command result, telemetry, serta audit trail tanpa client-side write.

`firebase.json` saat ini belum mengonfigurasi Emulator. Jangan menjalankan
deployment Rules sebagai pengganti tes lokal; deployment memerlukan review dan
persetujuan terpisah.