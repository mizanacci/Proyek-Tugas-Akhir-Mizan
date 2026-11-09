# Status Integrasi

Status source dan verifikasi per 2026-11-09. Hasil manual perangkat adalah laporan pemilik; tidak dianggap sebagai live test yang dilakukan dari repository.

| Komponen | Status | Bukti / batasan |
|---|---|---|
| Firebase Authentication dan role | Diimplementasikan | Email/Password; profil UID menentukan Manager/Operator. Pemilik melaporkan login kedua role berhasil. |
| Operator command request | Diimplementasikan | Operator aktif membuat OPEN/CLOSE PENDING di /commands; pemilik melaporkan RTDB menerima request. Bukan bukti eksekusi gateway/PLC. |
| Flutter telemetry/results/activity | Read-only | Flutter membaca RTDB; tidak menulis backend-owned data. |
| Gateway code | MVP scaffold | Worker Node.js membaca command queue, memvalidasi profil, ingest tiga topic MQTT, dan menulis backend nodes. Belum dijalankan terhadap Firebase/HiveMQ live. |
| Gateway command dispatch | Disabled by default | COMMAND_DISPATCH_ENABLED=false. Mapping OPEN/CLOSE ke NO/NC wajib diverifikasi dari ladder/wiring sebelum diaktifkan. |
| MQTT telemetry | Code path tersedia | Format sensor/status mengikuti firmware. Belum diuji broker live. |
| Telemetry RTDB | Latest-only | Menulis /telemetry/LBS_01/latest agar storage tidak tumbuh tanpa batas. |
| LBS physical feedback | Belum tersedia | Firmware belum mempublikasikan auxiliary-contact status. status_lbs tetap UNKNOWN; jangan infer dari command. |
| Command acknowledgement | Belum tersedia | Firmware menerima NO/NC tetapi belum mengirim correlated command ID acknowledgement atau PLC execution feedback. |
| Firebase Security Rules | Proposal lokal | Rules membatasi client writes; belum diuji di Emulator atau dideploy. Admin SDK bypasses Rules and must be secured server-side. |
| Flutter analyzer/tests/APK | Dilaporkan pemilik | Analyze bersih, format lolos, 23 tests lulus, APK debug build berhasil pada clone lokal. |
| ESP32/PLC fisik | Belum diverifikasi | Memerlukan PlatformIO, perangkat, broker, PLC polling, dan auxiliary feedback. |

PENDING berarti request tercatat. RECEIVED/dry_run berarti gateway validasi tanpa mengirim MQTT. EXECUTING berarti PUBLISH diserahkan ke transport; tidak membuktikan penerimaan ESP32/PLC. INDETERMINATE perlu verifikasi manual. SUCCEEDED harus menunggu correlated acknowledgement dan posisi fisik terkonfirmasi.
