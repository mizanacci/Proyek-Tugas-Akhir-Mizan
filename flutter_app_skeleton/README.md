# SCADA Mizan Flutter App

Aplikasi Flutter menerima telemetry dari HiveMQ Cloud dan menulis snapshot ke
Firebase Realtime Database pada `/data_activity` selama aplikasi aktif dan
pengguna Firebase login. ESP32 tidak menulis langsung ke Firebase.

## Menjalankan

Isi credential MQTT pada `lib/config/app_secrets.dart` lokal (file diabaikan
Git), lalu jalankan dari PowerShell:

```powershell
flutter pub get
flutter run `
	--dart-define=MQTT_MANAGER_USERNAME=<username-manager> `
	--dart-define=MQTT_MANAGER_PASSWORD=<password-manager> `
	--dart-define=MQTT_OPERATOR_USERNAME=<username-operator> `
	--dart-define=MQTT_OPERATOR_PASSWORD=<password-operator>
```

Nilai `--dart-define` dapat diekstrak dari APK; credential ini bukan tempat
penyimpanan rahasia untuk aplikasi produksi. Jangan commit credential MQTT atau
service-account Firebase.

## Diagnostik dan Pengujian

Panel diagnostik tersedia pada Monitoring dan Data Activity. Build debug
menyediakan tombol uji tulis Firebase, yang menulis record bertanda
`FIREBASE_WRITE_TEST` hanya bila write benar-benar berhasil.

```powershell
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
```

Snapshot otomatis berhenti ketika proses aplikasi ditutup. Status verifikasi,
prosedur manual, skema, dan batas keamanan tersedia pada folder `../docs/`.
Rules lokal di `database.rules.json` tidak otomatis dipublikasikan ke Firebase.
