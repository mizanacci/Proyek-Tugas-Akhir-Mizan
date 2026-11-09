# Status Integrasi

Status source dan verifikasi lokal per 2026-11-09. Ini bukan bukti deployment
Firebase Rules/backend atau pengujian hardware dari sesi sinkronisasi.

| Komponen | Status | Bukti / batasan |
|---|---|---|
| Firebase Authentication dan role | Diimplementasikan | Email/Password; profil UID menentukan Manager/Operator. Pemilik melaporkan login Manager dan Operator berhasil; tidak diuji live pada sesi sinkronisasi. |
| Manager | Read-only untuk command | Policy service dan rules menolak pembuatan command Manager; tes lokal memverifikasi policy. |
| Operator command request | Diimplementasikan | Operator aktif dapat membuat `OPEN`/`CLOSE` di `/commands` dengan status `PENDING`. Pemilik melaporkan request diterima RTDB; bukan bukti eksekusi gateway/PLC. |
| Telemetry, command results, Data Activity | Read stream Flutter | Source membaca RTDB; penulisan ketiga path dimiliki backend. Live backend stream belum diverifikasi di sini. |
| EventLogger | Auth/profile observer | Tidak menginisialisasi MQTT, menjalankan snapshot timer, atau menulis RTDB. |
| Flutter MQTT | Tidak dipakai runtime | MQTT firmware/protokol tetap ada; Flutter tidak subscribe broker atau publish relay. API lama fail-closed untuk publish. |
| Firebase Security Rules | Proposal lokal | Rules membatasi command create ke Operator dan menolak client write ke telemetry/results/activity; belum diuji di Emulator atau dideploy. |
| Gateway/Admin SDK | Belum tersedia di workspace | Pemrosesan command, telemetry, result, dan audit write harus dilakukan backend terpisah. |
| PLC/pergerakan LBS | Belum diverifikasi | `PENDING` hanya berarti permintaan tercatat; interlock dan feedback fisik tanggung jawab gateway/PLC. |
| Pengujian Android pemilik | Dilaporkan pemilik | RMX5000 berjalan tanpa error terlihat dan RTDB menerima PENDING OPEN/CLOSE; tidak diverifikasi ulang oleh sesi ini. |

Hasil analyzer, tes, dan APK build dicatat setelah verifikasi pada clone
repository yang digunakan untuk rilis.