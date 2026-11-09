# SCADA LBS Android Setup

## Target

- Firebase Project ID: scada-lbs
- RTDB URL: https://scada-lbs-default-rtdb.asia-southeast1.firebasedatabase.app
- Android application ID: com.mizan.scada_lbs

Pastikan pemilik memverifikasi ulang project dan URL di Firebase Console sebelum tindakan live.

## Firebase client

FlutterFire options Android sudah menunjuk project scada-lbs. Jika app registration berubah, jalankan FlutterFire CLI secara lokal dan periksa Project ID serta RTDB URL. Jangan commit google-services.json. Jangan menggunakan service-account JSON pada aplikasi Flutter.

Authentication menggunakan Email/Password. Profiles ada di /users/{uid} dengan email, displayName, role, dan isActive. Manager/operator dibuat oleh pemilik di Firebase Console dan profil di RTDB memakai UID Authentication yang sama.

## Firebase Rules

Tinjau SCADA_LBS_FIREBASE_RULES.md dan flutter_app_skeleton/database.rules.json. Rules masih lokal, belum diuji di Emulator atau dideploy. Jangan membuka akses publik.

## Gateway/backend

Gateway terpisah berada di backend/scada-gateway. Baca README gateway sebelum run. Gateway:
- Menggunakan Firebase Admin SDK di server, bukan di APK.
- Membaca /commands dan /users/{uid}.
- Menulis /command_results, /telemetry/LBS_01/latest, dan /data_activity.
- Subscribe HiveMQ TLS ke topic telemetry dan status firmware.
- Menjalankan satu instance worker secara terus-menerus.

Jalankan pertama kali dengan COMMAND_DISPATCH_ENABLED=false. Simpan service-account credential dan HiveMQ credentials di server secret store atau mounted secret; jangan menambahkannya ke Git, APK, atau chat.

## Batas kendali

Firmware saat ini menerima {"command":"NO"} atau {"command":"NC"} pada scada/mizan/cmd/relay. Mapping OPEN/CLOSE ke NO/NC belum disimpulkan dari source; cocokkan ladder/wiring aktual terlebih dahulu.

Firmware saat ini belum menerbitkan correlated command acknowledgement maupun feedback posisi LBS dari auxiliary contact. Karena itu gateway MVP tidak menandai request SUCCEEDED dan telemetry status_lbs tetap UNKNOWN. Jangan menganggap PENDING, MQTT publish, atau register command sebagai bukti posisi fisik.

## Verifikasi

Jalankan Flutter commands sesuai docs/INTEGRATION_TEST_PROCEDURE.md. Uji gateway unit tests secara lokal. Hubungan live Firebase/HiveMQ dan pengujian perangkat harus dicatat terpisah; jangan klaim deployment atau kontrol fisik berhasil sebelum benar-benar dilakukan.
