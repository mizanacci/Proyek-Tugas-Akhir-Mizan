# SCADA LBS Android Setup

## Target dan status

- Firebase Project ID: `scada-lbs`
- RTDB URL: `https://scada-lbs-default-rtdb.asia-southeast1.firebasedatabase.app`
- RTDB region: `asia-southeast1`
- Android package / application ID: `com.mizan.scada_lbs`
- Target build: Android only

Nilai target berasal dari keputusan pemilik dan materi konfigurasi sebelumnya.
Sebelum tindakan Console, pemilik harus memastikan Project ID, URL database, dan
region masih cocok.

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

Jangan mengirim file konfigurasi atau credential melalui chat.

## FlutterFire configuration

Dari root Flutter app, setelah pemilik menyelesaikan app registration dan Firebase
CLI login secara lokal:

```powershell
cd .\Proyek-Tugas-Akhir-Mizan\flutter_app_skeleton
flutterfire configure --project=scada-lbs --platforms=android
```

Pilih app Android dengan package `com.mizan.scada_lbs` saja jika registrasi
berubah atau konfigurasi perlu diregenerasi. File saat ini sudah berisi opsi
Android untuk project `scada-lbs`; startup menolak Project ID atau RTDB URL yang
berbeda dari target. Jangan menempel isi file konfigurasi ke chat atau commit
`google-services.json`.

FlutterFire options adalah konfigurasi client, bukan service-account. Jangan
menggantinya dengan service-account JSON.

## Authentication dan profil

Pemilik menyatakan akun Manager dan Operator sudah dibuat. Verifikasi akun yang
ada di Firebase Console → Authentication → Users sebelum tindakan live; jangan
membuat duplikat. Aplikasi tidak menyediakan pendaftaran mandiri.

Setiap profil harus memakai UID yang sama dari Authentication, lalu dibuat atau
diperbarui oleh pemilik melalui Realtime Database Console:

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

Gunakan `role: "operator"` untuk akun Operator. UID Auth menentukan identitas;
email hanya informasi, bukan dasar otorisasi. Profil kosong, role tidak dikenal,
`isActive` selain `true`, atau displayName kosong ditolak. Client hanya membaca
profil UID sendiri dan tidak dapat menulis profil. Jangan menaruh password atau
credential di database.

## RTDB rules

Tinjau [SCADA_LBS_FIREBASE_RULES.md](SCADA_LBS_FIREBASE_RULES.md) dan
`flutter_app_skeleton/database.rules.json`. Rules lokal bukan rules live. Setelah
review dan pengujian Rules Emulator, pemilik dapat menerbitkan secara manual:

```powershell
firebase deploy --only database --project scada-lbs
```

Jangan membuat rules publik atau memberi write ke semua user login. Deployment
rules tidak dilakukan oleh gateway MVP.

## Gateway/backend boundary

Flutter membaca `/telemetry`, `/command_results`, dan `/data_activity`; Flutter
tidak subscribe HiveMQ, publish relay command, atau menulis backend-owned records.
Gateway terpisah berada di `backend/scada-gateway` dan menggunakan Firebase Admin
SDK di server, bukan di APK.

Gateway MVP:
- Membaca `/commands` dan memvalidasi ulang UID, role, active state, target,
  action, timestamp, dan expiry.
- Menulis `/command_results`, `/telemetry/LBS_01/latest`, dan
  `/data_activity`.
- Subscribe HiveMQ TLS ke sensor, LRUFail, dan COMFail topics.
- Menggunakan satu instance worker yang berjalan terus-menerus.

Simpan service-account credential dan HiveMQ credentials hanya di server secret
store atau mounted secret. Jangan masukkan ke Git, APK, atau chat.

## Status command dan batas kendali

Jalankan gateway pertama kali dengan `COMMAND_DISPATCH_ENABLED=false`. Mode ini
memvalidasi request dan menulis `RECEIVED` dengan `dispatch_state=dry_run`, tanpa
mengirim perintah MQTT.

Firmware saat ini menerima `{"command":"NO"}` atau `{"command":"NC"}` pada topic
`scada/mizan/cmd/relay`. Mapping OPEN/CLOSE ke NO/NC belum disimpulkan dari source;
cocokkan ladder dan wiring aktual terlebih dahulu.

Firmware belum menerbitkan correlated command acknowledgement maupun feedback
posisi LBS dari auxiliary contact. Karena itu gateway MVP tidak menandai request
`SUCCEEDED`; setelah PUBLISH yang berhasil, status tetap `EXECUTING`, dan hasil
pengiriman yang ambigu menjadi `INDETERMINATE`. Telemetry `status_lbs` tetap
`UNKNOWN`. Jangan menganggap PENDING, MQTT PUBLISH, atau register command sebagai
bukti posisi fisik. Jangan mengaktifkan dispatch sebelum mapping, permissive,
interlock, acknowledgement, dan feedback posisi diverifikasi.

## Local verification dan install

Dari root Flutter app:

```powershell
flutter --version
flutter doctor -v
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
adb devices -l
flutter devices
adb install -r build\app\outputs\flutter-apk\app-debug.apk
flutter run -d <DEVICE_ID>
```

Pilih device yang benar sebelum install. Package baru terpasang sebagai app
terpisah dari `com.example.scada_mizan_app`; jangan uninstall app lama atau
hapus datanya tanpa persetujuan.

Untuk gateway local:

```powershell
cd backend\scada-gateway
Copy-Item .env.example .env
npm install
npm test
node --env-file=.env src/index.js
```

Isi konfigurasi lokal dengan RTDB URL, path service-account di luar repository,
MQTT TLS URL, username, password, dan MQTT client ID unik. File `.env` diabaikan
Git. Gateway ini didesain sebagai satu instance worker, bukan fungsi HTTP singkat
atau beberapa replica autoscaled.

## Runtime acceptance

Dengan konfigurasi dan akun pemilik yang valid, uji startup Firebase project/URL,
login kedua role, profil UID/role/isActive, akses RTDB sesuai rules, telemetry
segar dari gateway, command request/status/result, dan activity backend. Pastikan
posisi aktual hanya berasal dari feedback independen.

Hasil analyzer, tes, build, koneksi Firebase/HiveMQ live, Rules deployment, dan
pengujian hardware harus dicatat secara terpisah. Jangan menyamakan request
PENDING dengan eksekusi atau menyatakan deployment/perangkat lulus tanpa bukti.
Jangan menghapus project Firebase lama sampai aplikasi baru terbukti berfungsi.
