# Project Status 2026-11-16

## Ringkasan proyek

Proyek ini berfokus pada prototipe SCADA distribusi listrik berbasis PLC Omron CP1E N30 dan ESP32-S3. Sistem terdiri dari akuisisi sensor, komunikasi Modbus RTU, MQTT ke cloud, telemetry ke Firebase, dan visualisasi Flutter.

## Arsitektur perangkat

- PLC OMRON CP1E-N30DR-A
- ESP32-S3 DevKitC-1 N8
- MAX3232 RS-232 to TTL
- ZMPT101B x2
- ACS712 x2
- Relay MY2N, simulasi posisi LBS
- HiveMQ Cloud
- Firebase Realtime Database
- Flutter Android app

## Arsitektur sensor aktif

- GPIO4 = ZMPT tegangan sumber
- GPIO5 = ZMPT tegangan beban
- GPIO6 = ACS712 arus sumber
- GPIO7 = ACS712 arus beban

Baseline aktif adalah ADC internal ESP32-S3. ADS1115 bukan baseline aktif dan tidak dipertahankan sebagai arsitektur utama.

## Status teknis inti

### Tegangan
- NORMAL: 200–230 V inklusif.
- Di luar range: SUSPECT.
- AC_OFF: kondisi standby, bukan gangguan otomatis.

### Arus
- SUSPECT hanya bila > 1.80 A.
- 1.80 A tetap NORMAL.
- 0 A valid tetap NORMAL/STANDBY.

### Modbus
- Slave ID 1.
- UART2 9600 8N1.
- TX GPIO17, RX GPIO18.
- IREG0–IREG5 = offset 0–5.
- HREG6 = offset 6.
- HREG7 = offset 7.

### COM dan LRU
- COM = komunikasi PLC ↔ ESP32.
- LRU = koneksi ESP32 ↔ MQTT/cloud.
- Keduanya harus diperlakukan secara terpisah.

## Gateway

Gateway tetap DRY-RUN. Nilai `COMMAND_DISPATCH_ENABLED=false` harus dipertahankan. Gateway tidak boleh mengaktifkan relay secara langsung melalui MQTT.

## Firebase dan MQTT

- MQTT payload sensor masih memuat status dan kualitas.
- Gateway memetakan ke Firebase dengan ekstensi timestamp epoch dan status sensor terpisah.
- Pembacaan status posisi aktual LBS tetap UNKNOWN tanpa auxiliary contact/limit switch independen.

## Flutter

Aplikasi Flutter dibangun untuk membaca snapshot Firebase dan menampilkan status sensor, status LRU/COM, serta metadata HREG7 bila tersedia. Tidak ada perubahan besar tanpa kebutuhan teknis.

## PLC / CXT status

Baseline yang dipertahankan untuk handoff adalah file V3 SingleCoil yang benar-benar tersedia bukan V4. File V4 yang ada di workspace adalah instrumentasi revisi untuk simulasi internal ADC dan bukan baseline resmi.

File CXT yang saat ini benar-benar ada di workspace:
- review_claude_modbus/uji_modbus_simulasi/SCADA_CP1E_Mizan_Modbus_Revision_V4_InternalADC.cxt
- review_claude_modbus/uji_modbus_simulasi/SCADA_CP1E_Mizan_Rev.cxt

V3.2 sempat terdeteksi di Downloads pada pemeriksaan sebelumnya, tetapi file tersebut tidak lagi ditemukan saat packaging ulang. File itu tidak disalin atau dimasukkan ke ZIP.

File berikut belum tersedia secara fisik:
- SCADA_CP1E_Mizan_Modbus_Revision_V2_Minimal.cxt
- SCADA_CP1E_Mizan_Modbus_Revision_V3_SingleCoil.cxt
- SCADA_CP1E_Mizan_Modbus_Revision_V3_1_SingleCoil.cxt
- SCADA_LBS_PLC_V3_3_SingleCoil.cxt

## Pengujian yang cukup dipertanggungjawabkan

- Ladder simulator CXT V4: 36/36 lulus.
- PlatformIO firmware build: sukses melalui short-path mapping Windows.
- flutter analyze: no issues found.
- flutter test: 48/48 passed.
- gateway tests: 38/38 passed.
- firmware regression checks: pass.

## Batas validasi

- Tidak ada upload ke hardware aktual.
- Tidak ada validasi PLC Program Check resmi untuk V3.3.
- Tidak ada validasi physical wiring CP1E/ESP32/relay dengan perangkat riil.
- Status LBS actual masih UNKNOWN tanpa feedback hardware independen.

## Pekerjaan berikutnya

1. Validasi serial PLC actual di CP1E dengan fasilitas nyata.
2. Verifikasi pin DB9 dan MAX3232 pada hardware.
3. Konfirmasi program ladder final V3 baseline yang benar-benar lolos Program Check.
4. Verifikasi HREG7 terhadap heartbeat PLC riil.
5. Tindak lanjut on-site untuk relay, auxiliary contact, dan pembacaan LBS aktual.
