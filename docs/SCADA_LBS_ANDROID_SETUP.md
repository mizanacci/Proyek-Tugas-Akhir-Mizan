# SCADA LBS Android Setup

## Target dan status

- Firebase Project ID: `scada-lbs`
- RTDB URL: `https://scada-lbs-default-rtdb.asia-southeast1.firebasedatabase.app`
- RTDB region: `asia-southeast1`
- Android package / application ID: `com.mizan.scada_lbs`
- Target build: Android only

Nilai target berasal dari keputusan pemilik dan materi screenshot sebelumnya.
Keadaan Firebase Console saat ini belum diperiksa live. Sebelum tindakan Console,
pemilik harus memastikan Project ID, URL database, dan region masih cocok.

## Prasyarat dan registrasi Android

1. Pasang Flutter/Dart, Android SDK, JDK yang didukung Flutter, ADB, Firebase CLI,
   dan FlutterFire CLI pada komputer pemilik.
2. Firebase Console: buka project `scada-lbs`, verifikasi Project ID dan RTDB URL.
3. Project Settings → General → Your apps → Add app → Android. Isi package persis
   `com.mizan.scada_lbs`. Jangan membuat app registration dengan package lama.
4. `google-services.json` boleh diunduh ke
  `flutter_app_skeleton/android/app/google-services.json` sebagai konfigurasi
  Gradle lokal. File ini diabaikan Git dan bukan service-account key.
5. Pastikan Authentication → Sign-in method mengaktifkan Email/Password. Tidak
   diperlukan Google Sign-In.

Tidak ada app registration atau perubahan Console yang dilakukan otomatis.
Jangan mengirim file konfigurasi atau credential melalui chat.

## FlutterFire configuration

Dari root Flutter app, setelah pemilik menyelesaikan app registration dan Firebase
CLI login secara lokal:

```powershell
cd .\Proyek-Tugas-Akhir-Mizan-main\flutter_app_skeleton
flutterfire configure --project=scada-lbs --platforms=android
```

Pilih app Android dengan package `com.mizan.scada_lbs` saja jika registrasi
berubah atau konfigurasi perlu diregenerasi. File saat ini sudah berisi opsi
Android untuk project `scada-lbs`; startup menolak Project ID atau RTDB URL yang
berbeda dari target. Jangan menempel isi file konfigurasi ke chat atau commit
`google-services.json`.

Setelah CLI selesai, periksa lokal bahwa options Android memuat Project ID
`scada-lbs` dan RTDB URL di atas. FlutterFire options adalah konfigurasi client,
bukan service-account. Jangan menggantinya dengan service-account JSON.

## Authentication dan profil

Pemilik menyatakan user manager dan operator sudah dibuat. Verifikasi akun yang
ada di Firebase Console → Authentication → Users sebelum tindakan live; jangan
membuat duplikat. Jika akun belum ada, owner dapat membuatnya secara manual.
Aplikasi tidak menyediakan pendaftaran mandiri. Pastikan setiap profil memakai
UID yang sama dari Authentication, lalu buat/perbarui profil melalui Realtime
Database Console:

```json
{
  "users": {
    "<UID_FROM_AUTH>": {
      "email": "<EMAIL_FROM_AUTH>",
      "displayName": "<DISPLAY_NAME>",
      "role": "manager",
      "isActive": true
    }
  }
}
```

Gunakan `role: "operator"` untuk akun operator. UID Auth menentukan identitas;
email hanya informasi, bukan dasar otorisasi. Profil kosong, role tak dikenal,
`isActive` selain `true`, atau nama tampilan kosong ditolak. Client hanya membaca
profil UID sendiri dan tidak dapat menulis profil. Jangan menaruh password atau
credential di database.

## RTDB rules

Tinjau [SCADA_LBS_FIREBASE_RULES.md](SCADA_LBS_FIREBASE_RULES.md) dan
`flutter_app_skeleton/database.rules.json`. Rules lokal bukan rules live. Setelah
review dan pengujian Rules Emulator, pemilik dapat menerbitkan secara manual:

```powershell
firebase deploy --only database --project scada-lbs
```

Perintah deploy tidak dijalankan oleh migrasi ini. Jangan membuat rules publik
atau memberi write ke semua user login.

## Gateway/backend boundary

Flutter reads `/telemetry`, `/command_results`, and `/data_activity`; it does not
subscribe to HiveMQ, publish relay commands, or write backend-owned records. The
separate gateway/backend must use Firebase Admin SDK and keep its service-account
credentials on the server. Admin credentials must never be embedded in the APK.
No gateway implementation or live integration is present here. A command created
by Flutter remains only `PENDING` until a separately reviewed backend processes
it. Backend must revalidate UID/role/active state, target, action, expiry,
idempotency, and connectivity; PLC safety interlocks remain authoritative.

If the backend itself needs HiveMQ access, use a dedicated broker identity with
minimum ACL/topic permissions, keep it server-side, and rotate it. Never place
broker credentials in the Flutter app; `--dart-define` does not protect values
from APK extraction.

## Local verification and install

Dari root Flutter app:

```powershell
flutter --version
flutter doctor -v
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
adb devices -l
flutter devices
adb install -r build\app\outputs\flutter-apk\app-debug.apk
flutter run -d <DEVICE_ID>
```

Pilih dan pastikan device yang benar sebelum install. Package baru terpasang
sebagai app terpisah dari `com.example.scada_mizan_app`; jangan uninstall app lama
atau hapus datanya tanpa persetujuan. APK debug berada di
`build/app/outputs/flutter-apk/app-debug.apk` jika build berhasil.

## Runtime acceptance

Dengan konfigurasi dan akun pemilik yang valid, uji startup Firebase project/URL,
login kedua role, profil UID/role/isActive, penolakan role/profil invalid, akses
RTDB sesuai rules, telemetry segar dari gateway, command request/status/result,
dan activity backend. Pastikan posisi aktual hanya berasal dari feedback
telemetry; jangan menyamakan `PENDING` dengan eksekusi. Tanpa akun, backend,
telemetry, atau perangkat, tandai pengujian tersebut belum dilakukan.
Jangan menghapus project Firebase lama sampai aplikasi baru terbukti berfungsi;
penghapusan akan menghapus resource dan data project lama.
