# SCADA Mizan Flutter App — scada-lbs workspace

Flutter uses Firebase Authentication Email/Password and reads telemetry,
command results, and activity from Firebase Realtime Database. A separate
SCADA gateway/backend is expected to consume MQTT and write backend-owned data;
no gateway implementation is included in this workspace.

## Firebase setup wajib sebelum run

Buka `../docs/SCADA_LBS_ANDROID_SETUP.md` dan lakukan urutan manual berikut:

1. Verifikasi Firebase project `scada-lbs` dan daftarkan Android app dengan
   package ID `com.mizan.scada_lbs`.
2. Buat akun Authentication manager/operator, salin UID, dan tambahkan profil
   `/users/<uid>` dari Console.
3. Jalankan `flutterfire configure --project=scada-lbs --platforms=android`.
4. Tinjau `database.rules.json` dan publish rules hanya setelah review manual.
5. Jalankan `flutter pub get`, `flutter analyze`, `flutter test`, dan `flutter run`.

`lib/firebase_options.dart` berisi konfigurasi Android untuk project `scada-lbs`;
startup memvalidasi Project ID dan RTDB URL. Jika app registration atau project
berubah, pemilik harus menjalankan ulang FlutterFire CLI dan meninjau hasilnya.
`android/app/google-services.json` adalah konfigurasi lokal opsional untuk
Gradle dan selalu diabaikan Git.

## Gateway and command handling

Flutter does not publish relay commands or write telemetry/results/audit data.
An active operator may append an `OPEN`/`CLOSE` request at `/commands`; this only
records `PENDING`. A separately deployed backend must validate and process it,
and PLC interlocks/protection remain authoritative. Do not put Firebase Admin
credentials or broker credentials in the Flutter app.

## Diagnostik dan test

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Telemetry and activity depend on the separate backend/gateway being available;
the client does not provide 24/7 ingestion.
