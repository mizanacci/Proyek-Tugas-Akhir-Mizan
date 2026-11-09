# Prompt ChatGPT: Migrasi Flutter ke Firebase `scada-lbs`

> Salin seluruh prompt di bawah ini ke ChatGPT, lalu lampirkan file ZIP laporan dan workspace terbaru serta screenshot Firebase yang relevan.

---

## Prompt

Anda adalah senior Flutter/Firebase engineer yang membantu saya memigrasikan aplikasi tugas akhir SCADA ke **proyek Firebase baru bernama `scada-lbs`**. Saya belum membuat akun pengguna di Firebase Authentication untuk proyek baru tersebut.

### Tujuan

Buat **folder proyek baru yang terpisah** berdasarkan workspace/repository terbaru yang saya lampirkan, lalu integrasikan salinan aplikasi Flutter di dalamnya ke Firebase `scada-lbs`. Aplikasi harus dapat login, membaca role pengguna, menerima telemetry MQTT dari HiveMQ, dan menyimpan snapshot/event ke Firebase Realtime Database dengan rules yang aman. Workspace sumber harus tetap utuh.

### Bahan yang saya lampirkan

1. Screenshot Firebase Console proyek baru `scada-lbs`, termasuk halaman konfigurasi project/app, Authentication, Realtime Database, dan informasi lain yang tersedia.
2. ZIP berisi laporan tugas akhir yang sudah direvisi, gambar program ladder CX, screenshot/tampilan aplikasi, repository/workspace Git terbaru, dan bahan pendukung lainnya.

Periksa seluruh bahan sebelum mengubah kode. Gunakan laporan revisi dan program ladder sebagai sumber kebutuhan terbaru; bila bertentangan dengan kode atau dokumen lama, catat perbedaannya dan minta keputusan saya sebelum mengubah perilaku sistem. Jangan mengarang nilai konfigurasi yang tidak tampak pada screenshot atau tidak tersedia di CLI.

### Aturan kerja wajib

1. Mulai dengan inventarisasi isi ZIP/workspace dan jelaskan arsitektur yang benar-benar ditemukan: Flutter, Firebase Auth, Realtime Database atau layanan Firebase lain, HiveMQ/MQTT, firmware, topic, payload, role, dan alur data.
2. Pastikan repository sumber bersih/tercatat kondisinya sebelum bekerja. Buat folder salinan baru sebagai sibling dari workspace sumber, misalnya `Proyek_TA_SCADA_LBS`. Jangan menimpa, memindah, atau menghapus file sumber. Jangan menyalin `.git`, `build`, cache, secret, atau konfigurasi lokal yang tidak aman kecuali memang dibutuhkan dan sudah ditinjau.
3. Pertahankan fungsi dan tampilan aplikasi yang tidak terkait migrasi. Batasi perubahan Firebase pada folder salinan. Tunjukkan daftar file yang diubah dan alasannya.
4. Jangan menaruh password, token, private key, Firebase service-account JSON, kredensial MQTT, atau data sensitif di source control, prompt, log, atau screenshot. Jangan meminta saya mengirim secret melalui chat. Firebase client config yang dihasilkan FlutterFire bukan pengganti service-account dan jangan menyebut API key client sebagai password.
5. Jangan membuka database atau menambahkan rules publik seperti `auth != null` yang tidak dibatasi tanpa analisis kebutuhan. Jangan memberikan write database kepada semua akun hanya agar aplikasi “berhasil”. Uji kasus user tanpa login, user ber-role operator, dan user ber-role manager.
6. Jangan membuat user Firebase atau mengakses Console menggunakan kredensial saya. Jika tindakan memerlukan Console, berhenti pada titik tersebut dan berikan instruksi manual yang presisi. Jangan mengklaim deployment/live test berhasil tanpa bukti nyata.
7. Sebelum mengedit, sampaikan hipotesis singkat tentang titik integrasi yang perlu diubah dan pemeriksaan lokal yang akan membuktikan hasilnya. Kerjakan bertahap dan uji bagian yang disentuh.

### Firebase baru dan konfigurasi Flutter

1. Dari screenshot, identifikasi project ID, aplikasi Android/iOS/web yang sudah terdaftar, package/bundle ID, RTDB URL dan region, provider Authentication yang aktif, serta apakah database sudah dibuat. Jangan samakan nama tampilan `scada-lbs` dengan project ID tanpa bukti.
2. Bandingkan package ID aplikasi di source dengan app registration Firebase. Jika belum cocok/terdaftar, jelaskan konsekuensinya dan minta persetujuan sebelum mengganti application ID atau mendaftarkan app baru.
3. Gunakan konfigurasi FlutterFire yang sesuai dengan platform yang memang dipakai. Bila Firebase CLI/FlutterFire CLI tersedia dan autentikasi lokal sudah siap, jalankan dari root app salinan dengan project ID yang terverifikasi; bila tidak, berikan command dan langkah manual yang harus saya jalankan. Jangan menyalin `firebase_options.dart` lama begitu saja.
4. Pastikan inisialisasi Firebase menggunakan konfigurasi platform yang baru dan RTDB menunjuk ke instance `scada-lbs`. Periksa `firebase.json`, Gradle/Google Services, `google-services.json`, dan konfigurasi platform lain yang relevan. Jangan meminta saya menempelkan file konfigurasi privat ke chat; arahkan untuk menghasilkan/menempatkannya lokal.
5. Jika Google Sign-In dipakai, periksa provider enablement, SHA-1/SHA-256 untuk Android, OAuth client IDs, dan package ID. Jelaskan persis bagian yang dapat dikonfigurasi dari kode dan bagian yang harus saya aktifkan/tambahkan di Console. Jangan menganggap Google Sign-In sudah berfungsi hanya karena build berhasil.
6. Pastikan Auth method yang digunakan aplikasi (misalnya Email/Password) diaktifkan. Jelaskan bahwa email harus berformat email, tetapi tidak harus Gmail atau memiliki inbox aktif kecuali verifikasi/reset email dibutuhkan. Aplikasi tidak memiliki pendaftaran mandiri kecuali kode membuktikan sebaliknya.

### Pengguna, UID, role, dan aturan akses

1. Telusuri kode login dan pembacaan profil user. Tentukan format profil yang sungguh dipakai aplikasi, misalnya `/users/<uid>/{email,nama,role}`, jangan berasumsi hanya dari dokumentasi lama.
2. Karena user proyek baru belum dibuat, berikan instruksi Console langkah demi langkah untuk mengaktifkan provider dan membuat minimal satu akun manager serta satu operator (bila memang dua role digunakan). Setelah akun dibuat, jelaskan cara mengambil UID di Authentication > Users dan menambahkan profil yang cocok di RTDB. Berikan contoh JSON dengan placeholder, bukan UID/email/password rekaan yang tampak nyata.
3. Terangkan data apa yang perlu saya salin manual dan ke mana. UID biasanya baru tersedia setelah akun dibuat; jangan minta saya mengirim password. Untuk Firebase client setup, utamakan FlutterFire CLI atau file konfigurasi resmi, bukan salin token. Jika ada API key/client ID yang perlu dimasukkan, jelaskan sumbernya, lokasi konfigurasi, dan apakah nilainya sensitif.
4. Audit rules yang ada terhadap seluruh operasi baca/tulis aplikasi. Rules harus mempertahankan least privilege, validasi skema dan role, serta mencegah pengguna menaikkan role sendiri. Perhatikan bahwa aturan `.write` di parent dapat melewati validasi child dan bahwa profil role tidak boleh bisa diubah oleh user biasa.
5. Buat rules lokal di folder salinan dan jelaskan prosedur publish manual ke Firebase Console/CLI. Jangan mengklaim rules sudah live sebelum saya publish. Berikan daftar uji akses yang bisa saya lakukan sesudah deploy.

### Alur MQTT ke Firebase

Telusuri implementasi dan pastikan alur yang benar-benar berlaku: ESP32 publish ke HiveMQ, Flutter subscribe, parsing payload, lalu menulis snapshot/event ke RTDB ketika syarat aplikasi terpenuhi. Pertahankan topik, format payload, TLS, dan logika kontrol yang sesuai dengan firmware serta laporan terbaru. Jangan mengubah firmware atau kontrak MQTT kecuali diperlukan dan jelaskan dampaknya terlebih dahulu.

Nyatakan secara eksplisit keterbatasan penyimpanan: jika Flutter menjadi satu-satunya subscriber/penulis, pencatatan dapat berhenti saat app ditutup, dihentikan OS, atau tidak login. Jangan mengklaim sistem menyimpan data 24/7. Jika laporan mensyaratkan operasi kontinu, ajukan backend bridge sebagai pekerjaan terpisah dengan rancangan, kebutuhan secret, dan estimasi perubahan; jangan diam-diam menambah layanan berbayar atau deploy backend.

### Verifikasi dan hasil yang harus diberikan

1. Jalankan pemeriksaan yang tersedia pada app salinan, sekurangnya `flutter pub get`, `flutter analyze`, `flutter test`, dan build platform target jika toolchain tersedia. Jangan menghapus atau melemahkan test yang gagal; laporkan kegagalan dan pisahkan dari perubahan migrasi.
2. Tambahkan atau perbarui dokumentasi setup khusus `scada-lbs`, termasuk prasyarat, konfigurasi, Auth, pembuatan user/profil, deploy rules, cara run, dan troubleshooting error umum (`permission_denied`, project/app mismatch, Google Sign-In/SHA mismatch, RTDB URL salah).
3. Berikan ringkasan hasil: nama/path folder baru, file penting yang berubah, Firebase project/app yang terverifikasi, hasil perintah test/build, apa yang sudah dilakukan otomatis, dan apa yang masih menunggu tindakan manual saya.
4. Buat checklist manual yang benar-benar berurutan dan mudah diikuti, minimal mencakup: cek project ID/RTDB URL, aktifkan Auth provider, buat user, salin UID ke profil, generate konfigurasi FlutterFire, publish rules, jalankan aplikasi, login, uji write/read, dan uji MQTT. Bedakan dengan jelas konfigurasi lokal dari tindakan Firebase Console.
5. Jika ada nilai yang belum diketahui, tulis sebagai placeholder dan jelaskan tepat di mana saya mendapatkannya. Tanyakan hanya keputusan yang benar-benar menghalangi perubahan; selain itu lanjutkan dengan asumsi eksplisit dan aman.

Mulailah dengan inventarisasi attachment dan laporan temuan singkat, lalu lanjutkan implementasi di folder salinan. Jangan mengubah atau mendorong perubahan ke repository GitHub sumber tanpa instruksi terpisah dari saya.

---

## Catatan sebelum mengirim bahan

- Periksa screenshot dan ZIP agar tidak memuat password, access token, private key, QR autentikasi, atau data pribadi yang tidak perlu. Samarkan bagian tersebut sebelum diunggah.
- Screenshot konfigurasi proyek dapat membantu mengidentifikasi project ID dan app registration, tetapi biasanya tidak cukup untuk membuat akun Authentication atau mengaktifkan provider. Langkah Console tetap perlu dilakukan pemilik proyek.
- Untuk Firebase Authentication email/password, UID baru bisa diambil setelah user dibuat. Jangan membagikan password user kepada ChatGPT.
- Prompt ini meminta ChatGPT membuat salinan kerja; pastikan ZIP memang berisi repository terbaru dan bukan folder `build` berukuran besar yang tidak diperlukan.