# Migrasi Flutter/Firebase ke project `scada-lbs`

Tanggal inventaris: 9 November 2026
Folder aplikasi: `flutter_app_skeleton/`

> Arsip audit sebelum integrasi gateway/backend. Jangan gunakan bagian MQTT,
> write Data Activity, atau checklist lama sebagai konfigurasi operasional.
> Panduan aktif adalah `SCADA_LBS_ANDROID_SETUP.md`, skema ada di
> `FIREBASE_DATABASE_SCHEMA.md`, dan rules ada di `SCADA_LBS_FIREBASE_RULES.md`.

Catatan: nilai Console di bawah berasal dari screenshot yang diberikan
sebelumnya, bukan pemeriksaan live saat ini. Pemilik harus memverifikasi ulang
Project ID, RTDB URL, status Authentication, dan rules di Console sebelum
tindakan live. Untuk langkah operasional terbaru, gunakan
`SCADA_LBS_ANDROID_SETUP.md`.

Dokumen ini menyimpan catatan audit migrasi sebelumnya. Instruksi dan status
toolchain historisnya telah disupersede oleh `SCADA_LBS_ANDROID_SETUP.md` dan
`SCADA_LBS_MIGRATION_REPORT.md`.

## 1. Temuan dari bahan yang disediakan

### Firebase Console (screenshot 9 November 2026)

| Item | Temuan yang dapat diverifikasi |
|---|---|
| Nama project | `scada lbs` |
| Project ID | `scada-lbs` |
| Project number | `959980736595` |
| Plan | Spark |
| App Android/iOS/web | Project Settings menunjukkan belum ada aplikasi yang terdaftar |
| RTDB URL | `https://scada-lbs-default-rtdb.asia-southeast1.firebasedatabase.app` |
| RTDB region | Singapore (`asia-southeast1`) |
| Isi awal RTDB | `null` / kosong |
| RTDB rules awal | Default locked: `.read: false`, `.write: false` |
| Authentication | Email/Password sudah `Enabled` |
| Google Sign-In | Belum diaktifkan; Console menampilkan opsi Enable |
| Akun Auth | Screenshot lama tidak menunjukkan daftar Users. Pemilik kini menyatakan akun manager/operator sudah dibuat; status Console dan profil RTDB belum diverifikasi live. |

Nama project dan Project ID bukan nilai yang sama. Gunakan **Project ID** `scada-lbs`
untuk CLI dan `.firebaserc`. URL RTDB adalah URL yang terlihat pada halaman
Realtime Database; jangan membuat URL dengan menebak region lain.

### Source workspace dan status repository

- Sumber: ZIP `Proyek Tugas Akhir, Konversi Mata Kuliah dan Magang PLN UP2D(2).zip`.
- Aplikasi: `flutter_app_skeleton`.
- Source ZIP tidak menyertakan folder `.git`; karena itu status working tree,
  branch, commit, dan perubahan lokal Git tidak dapat dipastikan. File
  `SOURCE_SNAPSHOT_SHA256.txt` pada folder migrasi merekam fingerprint file
  sumber sebelum modifikasi.
- Salinan migrasi tidak menyalin `.git`, cache/build, `google-services.json`
  lama, atau `database.users.seed.json` lama. Source ZIP tidak dimodifikasi.
- Android package telah ditetapkan menjadi `com.mizan.scada_lbs` pada source.
  iOS bundle identifier di source adalah `com.example.scadaMizanApp`, tetapi
  target yang dipersiapkan di panduan ini hanya Android.

### Arsitektur kode pada snapshot sebelum integrasi backend (arsip)

Bagian ini sengaja mempertahankan kondisi historis sebelum integrasi backend.
Jangan gunakan diagram atau klaim Flutter-writer di bawah sebagai instruksi
operasional. Arsitektur aktif dijelaskan di `MQTT_FIREBASE_DATA_FLOW.md` dan
`SCADA_LBS_ANDROID_SETUP.md`: Flutter membaca Firebase, Operator hanya membuat
request `PENDING` di `/commands`, sedangkan gateway/backend menulis telemetry,
command results, dan Data Activity.

```text
ESP32 firmware
  └─ publish MQTT over TLS → HiveMQ Cloud
       ├─ scada/mizan/data/sensor
       ├─ scada/mizan/status/lrufail
       └─ scada/mizan/status/comfail
             ↓ Flutter MqttService (subscriber)
       SensorData parser + EventLogger
             ↓ ketika Auth valid, MQTT subscribe di-ACK,
               data segar dan sample baru
       Firebase Realtime Database /data_activity
             ↑ Firebase Auth (Email/Password)
       Flutter membaca /users/<uid>/role untuk menentukan manager/operator

Flutter control → publish `{"command":"NO|NC"}` ke
`scada/mizan/cmd/relay` (alur kontrol yang ada; firmware tidak diubah).
```

Detail historis snapshot:

- `Firebase Auth`: `signInWithEmailAndPassword`; tidak ada form pendaftaran
  mandiri pada layar login. Service memiliki method pendaftaran, tetapi tidak
  ada UI yang memanggilnya.
- Profil yang dibaca aplikasi: `/users/{uid}` dan field `role`; nama dibaca dari
  `/users/{uid}/nama` saat mencatat perintah. Bentuk profil yang disiapkan:
  `{email, nama, role}`.
- `role`: hanya `manager` atau `operator`. Salinan migrasi menolak profil hilang
  atau role yang tidak dikenal; tidak lagi menganggap semua role tidak dikenal
  sebagai `operator`.
- Pada snapshot lama, `Data Activity`: `/data_activity/{pushId}` diperiksa
  otomatis setiap 10 detik, tetapi hanya ditulis saat ada sample baru,
  subscription siap,
  data belum stale (batas 15 detik), dan pengguna ber-auth.
- `settings` dan `scada_data` memiliki method kompatibilitas di service tetapi
  tidak ditemukan call-site aktif pada UI/workflow; rules migrasi tidak memberi
  akses ke path tersebut.
- ESP32 tidak menulis langsung ke Firebase. Pada snapshot lama Flutter adalah
  subscriber MQTT sekaligus penulis RTDB; source aktif sudah menghapus alur ini.

### Kontrak MQTT yang dipertahankan

| Peran | Topic | Format |
|---|---|---|
| Telemetry | `scada/mizan/data/sensor` | JSON `v_sumber`, `v_beban`, `i_sumber`, `i_beban`, `kualitas`, `ts` |
| Status gateway | `scada/mizan/status/lrufail` | JSON `status` (`NORMAL`/`FAIL`) dan `source` |
| Status komunikasi PLC | `scada/mizan/status/comfail` | JSON `status` (`NORMAL`/`FAIL`) dan `source` |
| Perintah | `scada/mizan/cmd/relay` | JSON `{"command":"NO"}` atau `{"command":"NC"}` |

Host broker yang dipakai kode Flutter: HiveMQ Cloud pada port TLS `8883`.

Topic dan format payload tidak diubah dalam migrasi ini. Kredensial broker tidak
disalin ke workspace baru dan tidak perlu dikirim lewat chat.

## 2. File yang diubah pada migrasi sebelumnya

| File | Perubahan |
|---|---|
| `lib/firebase_options.dart` | Placeholder fail-fast; harus digenerate ulang untuk Android `scada-lbs` |
| `firebase.json` | Menghapus mapping/app ID lama; hanya menunjuk rules lokal |
| `.firebaserc` | Default project CLI menjadi `scada-lbs` |
| `android/app/google-services.json` | File project lama tidak disalin; buat/generate untuk Android app baru setelah registrasi |
| `android/app/build.gradle.kts` | Google Services plugin diterapkan hanya jika file baru tersedia |
| `database.rules.json` | Rules least privilege untuk profil dan Data Activity; tidak membuka akses publik |
| `lib/services/firebase_service.dart` | Role harus eksplisit; penanganan pesan login; OAuth web client lama dihapus dari source |
| `lib/services/event_logger.dart` | MQTT dan pencatatan hanya aktif setelah profil role valid; invalid profile di-sign-out |
| `lib/screens/login_screen.dart` | Menampilkan pesan kegagalan profil/role yang spesifik |
| `lib/config/app_secrets.dart` | Stub lokal tanpa kredensial (diabaikan Git) agar import tersedia |
| `database.users.seed.json` | Data seed UID/email dari project lama dikeluarkan |
| `database.users.seed.example.json` | Template profil dengan placeholder UID/email |
| `.gitignore` | Mengabaikan konfigurasi Google Services lokal dan file secret |
| `test/firebase_role_test.dart` | Unit test parsing role valid/invalid |
| `docs/FIREBASE_DATABASE_SCHEMA.md` | Skema dan scope path diperbarui |
| `docs/FIREBASE_SECURITY_RULES.md` | Dokumentasi akses sesuai rules baru |
| `docs/SCADA_LBS_FIREBASE_SETUP.md` | Panduan migrasi dan tindakan manual |

Tidak ada perubahan pada firmware ESP32, file program Ladder, topic MQTT,
format payload MQTT, applicationId Android, atau desain layar aplikasi.

## 3. Registrasi aplikasi Android (manual di Console)

Screenshot sebelumnya belum menunjukkan app registration. Keadaan Console
saat ini belum diverifikasi dan tidak ada app yang didaftarkan dari sesi ini.

1. Buka Firebase Console → project `scada lbs` → Project Settings → General.
2. Pada bagian **Your apps**, pilih ikon Android / Add app.
3. Isi Android package name persis `com.mizan.scada_lbs` (nilai dari
   `android/app/build.gradle.kts`). Jangan memakai nama folder atau `pubspec`
   sebagai package ID.
4. Nama panggilan app boleh diisi `SCADA LBS Android`.
5. Untuk pengujian Email/Password, SHA fingerprint bukan syarat login email.
  Email/Password tidak memerlukan SHA fingerprint. Jangan aktifkan Google
  Sign-In untuk migrasi ini.
6. Selesaikan registrasi. Jangan mengubah package name pada Console tanpa
   mengubah `applicationId` Android secara konsisten di source.
7. Pada detail Android app yang baru dibuat, unduh `google-services.json` dan
   simpan secara lokal di `flutter_app_skeleton/android/app/google-services.json`.
   File ini tidak disertakan di workspace migrasi karena app registration baru
   belum ada; file akan diabaikan Git. Jangan mengirim file ini ke chat.

Konsekuensi: selama app Android belum terdaftar, FlutterFire tidak dapat
menghasilkan konfigurasi khusus app tersebut. `firebase_options.dart` di
workspace salinan saat ini sengaja melempar `UnsupportedError` sampai langkah
FlutterFire dilakukan. Android build dapat berjalan tanpa Google Services JSON;
Firebase initialization belum dapat dijalankan sampai konfigurasi digenerate.

## 4. Buat akun Firebase Authentication

Email/Password sudah `Enabled` pada screenshot. Tidak perlu mengaktifkan Google
Sign-In untuk alur login layar saat ini.

Untuk membuat akun:

1. Firebase Console → Authentication → Users.
2. Pilih **Add user**.
3. Buat satu akun manager dan satu akun operator dengan email yang sah secara
   format serta password kuat yang Anda simpan sendiri.
4. Email tidak wajib Gmail. Inbox aktif diperlukan hanya jika Anda akan memakai
   verifikasi email atau reset password melalui email.
5. Jangan membuat akun untuk peran dari aplikasi; tidak ada UI pendaftaran
   mandiri. Jangan mengirim password melalui chat.
6. Buka setiap user pada tabel Users, salin **UID** masing-masing.

Contoh profil berikut hanya template; semua nilai placeholder harus diganti
menggunakan UID/email dari Authentication:

```json
{
  "users": {
    "<UID_MANAGER_FROM_AUTH>": {
      "email": "<MANAGER_EMAIL_FROM_AUTH>",
      "nama": "<NAMA_MANAGER>",
      "role": "manager"
    },
    "<UID_OPERATOR_FROM_AUTH>": {
      "email": "<OPERATOR_EMAIL_FROM_AUTH>",
      "nama": "<NAMA_OPERATOR>",
      "role": "operator"
    }
  }
}
```

Cara memasukkan profil: Realtime Database → Data → buat child `users` jika
belum ada → buat child dengan key UID manager dan object profil manager → ulangi
untuk UID operator. Atau gunakan tombol `+` pada node root untuk menambah
child `users`, lalu key UID masing-masing. Email di profil harus sama dengan
email akun Auth. **Jangan** menaruh password, token, atau credential di RTDB.

Rules migrasi tidak memberikan izin write ke `/users`, sehingga operasi
pembuatan profil ini harus dilakukan oleh owner/admin lewat Console.

## 5. Generate konfigurasi FlutterFire di komputer lokal

Perintah dijalankan pada komputer yang sudah memiliki Flutter SDK, Android SDK,
Firebase CLI, dan Dart. Jangan menempelkan isi file konfigurasi ke chat.

Install/login CLI:

```powershell
npm install -g firebase-tools
firebase login
firebase projects:list
 dart pub global activate flutterfire_cli
```

Pastikan `firebase projects:list` menampilkan `scada-lbs`. Jika folder Dart Pub
Cache belum masuk PATH, tambahkan direktori executable Dart Pub Cache ke PATH
sesuai OS Anda, lalu buka terminal baru.

Masuk ke folder aplikasi Flutter:

```powershell
cd .\Proyek-Tugas-Akhir-Mizan-main\flutter_app_skeleton
flutterfire configure --project=scada-lbs --platforms=android
```

Pada pemilihan aplikasi, pilih Android app yang sudah didaftarkan pada langkah
3. Jangan memilih/membuat aplikasi dengan package ID berbeda. FlutterFire CLI
menghasilkan `lib/firebase_options.dart`; file `google-services.json` diunduh
terpisah dari detail app Android di Console. Periksa bahwa project ID di file
hasil FlutterFire `scada-lbs` dan `databaseURL` sama persis dengan URL RTDB pada
tabel di atas. Jika CLI meminta membuat app baru karena registrasi belum ada,
batalkan dan selesaikan registrasi Console dahulu.

`firebase_options.dart` berisi identifier client (termasuk API key client),
bukan password atau service-account. Jangan menggantinya dengan JSON
service-account. File `google-services.json` juga harus berasal dari app
Android `scada-lbs`, bukan project lama `scada-mizan-ta`.

## 6. Publish rules (manual, setelah review)

Rules lokal ada di `flutter_app_skeleton/database.rules.json`. Rules yang ada di
server saat ini masih default locked berdasarkan screenshot. File lokal tidak
mengubah database sampai dipublikasikan.

Sebelum publish, pastikan profil manager/operator sudah dibuat, lalu:

**Opsi Console**

1. Realtime Database → tab Rules.
2. Salin isi `database.rules.json` dari workspace migrasi.
3. Periksa ulang `.read`/`.write`; pastikan tidak ada `true` untuk akses publik.
4. Klik Publish.

**Opsi Firebase CLI**

Dari folder `flutter_app_skeleton` setelah `firebase login`:

```powershell
firebase deploy --only database --project scada-lbs
```

Perintah ini hanya deploy database rules dari `firebase.json`. Jalankan hanya
setelah rules ditinjau dan Anda menyetujui publikasi. Belum ada deployment yang
dilakukan oleh workspace migrasi ini.

### Matriks uji akses setelah deploy

| Kasus | Baca profil sendiri | Baca Data Activity | Buat event sendiri | Ubah profil/role | Update/delete event |
|---|---:|---:|---:|---:|---:|
| Tanpa login | Tolak | Tolak | Tolak | Tolak | Tolak |
| Manager dengan profil valid | Izinkan | Izinkan | Izinkan | Tolak | Tolak |
| Operator dengan profil valid | Izinkan | Izinkan | Izinkan | Tolak | Tolak |
| Akun Auth tanpa profil/role | Tolak oleh aplikasi/rules | Tolak | Tolak | Tolak | Tolak |
| UID mencoba menulis `oleh_uid` milik orang lain | - | - | Tolak | - | - |
| Record berisi field tak dikenal | - | - | Tolak | - | - |

Perhatikan: rules `/data_activity` memberi manager dan operator akses baca ke
seluruh log karena kedua menu menyediakan Data Activity. Jika kebutuhan privasi
berubah menjadi hanya manager yang boleh melihat semua log, ubah kebijakan dan
UI bersama-sama sebelum publish.

## 7. Menjalankan aplikasi dan menguji MQTT

Setelah FlutterFire selesai dan rules dipublikasikan:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run `
  --dart-define=MQTT_MANAGER_USERNAME=<USERNAME_MANAGER_HIVEMQ> `
  --dart-define=MQTT_MANAGER_PASSWORD=<PASSWORD_MANAGER_HIVEMQ> `
  --dart-define=MQTT_OPERATOR_USERNAME=<USERNAME_OPERATOR_HIVEMQ> `
  --dart-define=MQTT_OPERATOR_PASSWORD=<PASSWORD_OPERATOR_HIVEMQ>
```

Jangan commit atau kirim kredensial MQTT. `--dart-define` hanya untuk prototipe;
nilai yang dimasukkan ke aplikasi client dapat diekstrak dari binary. Jangan
gunakan credential berhak tinggi/berumur panjang untuk distribusi publik.

Uji berurutan:

1. Login sebagai manager. Pastikan masuk ke Menu Manager.
2. Pastikan MQTT connect, ketiga subscription mendapat ACK, dan payload sensor
   diproses. Uji MQTT tidak membuktikan RTDB write berhasil.
3. Buka panel diagnostik dan jalankan Firebase write test dalam debug build.
   Pastikan satu record `FIREBASE_WRITE_TEST` muncul di `/data_activity`.
4. Pastikan Data Activity menampilkan record tadi.
5. Login operator dan ulangi pembacaan serta penulisan event sendiri.
6. Uji user tanpa profil (gunakan akun uji terpisah): aplikasi harus menolak
   sesi dan tidak membuka koneksi MQTT.
7. Verifikasi melalui Firebase Rules Emulator/Console bahwa operator tidak
   dapat menulis profil sendiri, menaikkan role, menulis UID orang lain, atau
   mengubah/menghapus record.

### Troubleshooting

- `permission_denied`: periksa bahwa Auth sudah login, profil `/users/{uid}`
  ada, role tepat `manager`/`operator`, `oleh_uid` sama dengan UID Auth, dan
  rules server sudah dipublikasikan. Pastikan Anda tidak mengandalkan JSON
  lokal saja.
- Project/app mismatch: cek `projectId` di `firebase_options.dart`, app ID di
  Firebase Console, package ID di Gradle, dan project default di `.firebaserc`.
  Semua harus menunjuk ke app `scada-lbs`.
- RTDB URL salah: cek `databaseURL` hasil FlutterFire harus sama dengan URL
  `asia-southeast1` yang ditampilkan di Console.
- Google Sign-In tidak menjadi bagian dari aplikasi ini. Gunakan hanya
  Email/Password seperti yang ditetapkan untuk migrasi.
- RTDB kosong: `null` adalah kondisi awal yang normal. Data log baru muncul
  setelah app login, MQTT menerima payload baru, dan syarat snapshot terpenuhi.
- Aplikasi tidak menulis saat ditutup: ini keterbatasan desain saat ini, bukan
  permission error. Flutter menjadi satu-satunya subscriber/penulis.

## 8. Keterbatasan penyimpanan 24/7

Pencatatan berhenti ketika proses aplikasi ditutup/dihentikan OS, perangkat
offline, user logout, MQTT terputus, subscription belum siap, atau data sensor
stale. Tidak ada layanan server/backend MQTT-to-Firebase di workspace ini.

Jika laporan menuntut penyimpanan kontinu, pekerjaan terpisah diperlukan:
backend subscriber MQTT yang selalu aktif (misalnya Cloud Run/Cloud Functions
atau server terkelola), secret broker di Secret Manager/environment server,
Firebase Admin SDK service identity, validasi payload, logging/retry, dan
monitoring. Rancangan/deploy backend tidak dilakukan di migrasi ini dan dapat
membawa biaya operasional.

## 9. Status tindakan

**Dikerjakan lokal pada salinan:** membuat folder kerja baru, menyingkirkan
konfigurasi project Firebase lama dan contoh akun lama, menyiapkan project
alias `scada-lbs`, menyiapkan rules lokal, mengunci role fail-closed, menyiapkan
placeholder FlutterFire, menambah unit test role, serta dokumentasi.

**Menunggu pemilik project:** mendaftarkan Android app dengan package ID yang
disetujui, membuat akun Auth manager/operator, menambah profil UID di RTDB,
menjalankan FlutterFire CLI pada komputer dengan toolchain, meninjau dan publish
rules, serta melakukan live test Firebase/MQTT.

**Belum dapat diverifikasi live:** Rules Emulator, koneksi HiveMQ, Firebase Auth,
RTDB read/write, dan runtime pada Android device. Flutter dan CLI tersedia lokal;
FlutterFire configure/deploy tidak dijalankan karena app Android belum
dikonfirmasi terdaftar dan tindakan Console harus dilakukan pemilik.

## 10. Checklist manual berurutan untuk pemilik project

- [ ] **Verifikasi project** di Firebase Console: Project ID `scada-lbs`, RTDB URL `https://scada-lbs-default-rtdb.asia-southeast1.firebasedatabase.app`, region `asia-southeast1`.
- [ ] **Gunakan package ID Android** `com.mizan.scada_lbs`; jangan mendaftarkan package lama `com.example.scada_mizan_app`.
- [ ] **Daftarkan app Android** pada Project Settings → General dengan package ID yang telah diputuskan.
- [ ] **Periksa Authentication** → Sign-in method. Email/Password telah Enabled pada screenshot; pastikan status itu masih aktif.
- [ ] **Buat user manager dan operator** di Authentication → Users. Simpan password secara lokal; jangan kirim melalui chat.
- [ ] **Salin UID** masing-masing user dan tambahkan profil `/users/<UID>` melalui Realtime Database Console dengan `email`, `nama`, dan `role` yang sesuai.
- [ ] **Unduh `google-services.json`** dari detail app Android baru dan letakkan di `android/app/` pada workspace salinan. Jangan gunakan file project lama.
- [ ] **Jalankan FlutterFire CLI** dari root `flutter_app_skeleton`: `flutterfire configure --project=scada-lbs --platforms=android`. Pastikan `firebase_options.dart` menunjuk ke project ID dan RTDB URL di atas.
- [ ] **Tinjau lalu publish RTDB rules** dari `database.rules.json` melalui Console atau `firebase deploy --only database --project scada-lbs`. Jangan publish sebelum memahami matriks izin di Bagian 6.
- [ ] **Jalankan pemeriksaan lokal**: `flutter pub get`, `flutter analyze`, `flutter test`, lalu `flutter run` dengan kredensial MQTT yang dimasukkan lokal melalui `--dart-define`.
- [ ] **Uji login manager dan operator**. Pastikan setiap user masuk ke menu role masing-masing; profil tanpa role valid harus ditolak.
- [ ] **Uji akses RTDB**: baca profil sendiri, buat event dengan UID sendiri, dan pastikan profil/role tidak dapat diubah serta event lama tidak dapat di-update/delete.
- [ ] **Uji MQTT**: verifikasi koneksi TLS HiveMQ, ACK subscription untuk ketiga topic telemetry/status, penerimaan payload, dan record snapshot/event di `/data_activity`.
- [ ] **Uji penolakan** tanpa login, UID milik orang lain, role tidak dikenal, dan field tambahan yang tidak termasuk skema.

Tindakan pada Console, pembuatan user, registrasi app, pengunduhan konfigurasi,
dan publikasi rules harus dilakukan oleh pemilik project. File lokal pada
workspace tidak menjalankan tindakan Console secara otomatis.
