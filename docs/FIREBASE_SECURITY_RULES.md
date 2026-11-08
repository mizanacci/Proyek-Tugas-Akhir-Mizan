# Firebase Security Rules

Aturan sumber berada di `flutter_app_skeleton/database.rules.json` dan dirujuk
oleh `flutter_app_skeleton/firebase.json`. Mengubah file lokal tidak mengubah
aturan yang aktif di Firebase Console.

- Tidak ada read/write publik.
- Profil dapat dibaca pemiliknya; client tidak dapat menulis profil atau role.
- Record baru `/data_activity/{id}` memerlukan Auth, key yang belum ada, dan
  `oleh_uid` sama dengan `auth.uid`.
- Field utama dan nilai sensor/status divalidasi; query timestamp diindeks.
- `/settings` hanya dapat ditulis oleh UID dengan role `manager` pada profil
  yang disiapkan admin.

> Aturan lokal belum dipublikasikan. Sebelum deploy, bandingkan dengan Rules
> aktif, jalankan tes Rules di Firebase Emulator, lalu minta persetujuan pemilik
> proyek. Emulator belum dapat dijalankan pada lingkungan kerja ini.
> Jangan menggunakan rules publik untuk debugging.

> Data yang ditulis Flutter tetap dapat dipalsukan oleh client yang sudah login
> sebagai UID-nya sendiri. Untuk data telemetry tepercaya/terus-menerus, gunakan
> backend dengan Firebase Admin SDK; jangan menaruh service-account key di APK.