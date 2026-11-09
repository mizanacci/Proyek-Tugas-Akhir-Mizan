# Prosedur Pengujian Integrasi

## Flutter

Dari flutter_app_skeleton:

    flutter pub get
    dart format --output=none --set-exit-if-changed lib test
    flutter analyze
    flutter test
    flutter build apk --debug

## Gateway local unit tests

Dari backend/scada-gateway:

    npm install
    npm test

Unit tests tidak memerlukan Firebase, HiveMQ, service-account, atau hardware.

## Gateway dry-run

1. Copy .env.example menjadi .env di backend/scada-gateway.
2. Set Firebase RTDB URL, Firebase Admin ADC/service-account path, MQTT TLS URL, MQTT username/password, dan MQTT client ID.
3. Pastikan COMMAND_DISPATCH_ENABLED=false.
4. Jalankan npm install, npm test, lalu node --env-file=.env src/index.js.
5. Pastikan worker tersambung ke HiveMQ dan berhasil subscribe ke sensor, LRUFail, dan COMFail topics.
6. Jalankan ESP32 pada broker uji; verifikasi /telemetry/LBS_01/latest diperbarui.
7. Login Flutter sebagai Operator dan kirim satu request kontrol pada kondisi aman. Pastikan gateway menulis /command_results/{id} dengan status RECEIVED dan dispatch_state dry_run.
8. Pastikan tidak ada MQTT publish ke scada/mizan/cmd/relay ketika dry-run.
9. Login sebagai Manager; pastikan Manager tidak dapat membuat request baru.
10. Uji command kadaluarsa, profil nonaktif, role Manager, status link FAIL, dan payload MQTT malformed.

## Kontrol fisik — BELUM BOLEH DIAKTIFKAN DARI MVP

Jangan set COMMAND_DISPATCH_ENABLED=true sebelum:
- Mapping OPEN/CLOSE ke NO/NC diverifikasi dari ladder logic dan wiring aktual.
- PLC permissive/interlock diuji.
- Perangkat uji menggunakan konfigurasi aman dan command hanya diuji dengan pengawasan teknisi.
- Firmware ditambah correlated command acknowledgement.
- Feedback posisi LBS dari auxiliary contact diterbitkan melalui PLC/firmware dan diverifikasi independen.

MQTT PUBLISH bukan device acknowledgement. Status EXECUTING bukan status SUCCEEDED. Jika result INDETERMINATE, verifikasi posisi aktual sebelum membuat command baru. Gateway tidak pernah retry command yang hasilnya ambigu.

Rules lokal belum dipublish. Firebase Rules Emulator dan deployment perlu dilakukan oleh pemilik setelah review manual. Gateway Admin SDK menulis backend-owned nodes dan bypass rules.
