# SCADA LBS Workspace Handoff

Tanggal: 2026-11-16
Branch: handoff/scada-lbs-workspace-20261116
Base branch: release/scada-lbs-internal-adc-20261116
Base commit: 92ec869ba368c6ee946af31c6b2860a1f25dd5d0

## Tujuan paket handoff

Paket ini dirancang untuk menjadi arsip kerja yang aman dan dapat dipindahkan ke komputer lain atau ChatGPT lain. Tujuan utamanya:

- menyalin snapshot kerja yang sudah diaudit,
- menyimpan dokumentasi handoff yang jelas,
- menyorot status teknis dan batasan validasi,
- menjaga baseline internal ADC dan dry-run MQTT,
- tidak menyertakan konfigurasi sensitif, build cache, atau secret.

## Cara menggunakan ZIP

1. Unduh file ZIP hasil pakaging di folder handoff.
2. Ekstrak ke folder baru di mesin tujuan.
3. Baca file ini terlebih dahulu.
4. Baca 01_PROJECT_STATUS_2026-11-16.md untuk ringkasan proyek.
5. Baca 02_HARDWARE_AND_SAFETY.md untuk aspek safety dan pin.
6. Baca 03_DECISIONS_DO_NOT_CHANGE.md sebelum melakukan perubahan teknis.
7. Baca 04_CXT_STATUS_AND_PROGRAM_CHECK.md sebelum revisi PLC.
8. Gunakan 06_PROMPT_CHATGPT_PROJECT_CONTINUATION.md untuk melanjutkan dengan ChatGPT lain.

## Struktur umum

- firmware_esp32/ : source firmware proyek.
- backend/scada-gateway/ : gateway MQTT → Firebase.
- flutter_app_skeleton/ : aplikasi Flutter.
- docs/ : dokumentasi proyek.
- review_claude_modbus/ : CXT/laporan analisys PLC dan simulator.
- handoff/SCADA_LBS_Workspace_Handoff_20261116/ : handoff dokumentasi dan manifest.

## Status validasi utama

- Baseline ADC internal ESP32-S3 dipertahankan.
- Tegangan NORMAL 200–230 V, arus SUSPECT hanya di atas 1.80 A.
- Command dispatch tetap DRY-RUN (`COMMAND_DISPATCH_ENABLED=false`).
- Komunikasi PLC yang berstatus COM hanya valid bila heartbeat HREG7 diterima dalam timeout 5 detik.
- Status LBS aktual tetap UNKNOWN tanpa auxiliary contact independen.

## Batasan yang perlu dijaga

- Jangan mengembalikan ADS1115 sebagai baseline aktif.
- Jangan mengaktifkan relay fisik melalui MQTT.
- Jangan mengklaim V3.3 sudah lolos Program Check jika tidak ada hasil resmi.
- Jangan mengubah firmware kalibrasi atau pin tanpa bukti pengukuran aktual.
- Jangan menggunakan credential lokal atau file .env/ config.h yang bersifat sensitif.

## Urutan pembacaan

1. 00_README_START_HERE.md
2. 01_PROJECT_STATUS_2026-11-16.md
3. 02_HARDWARE_AND_SAFETY.md
4. 03_DECISIONS_DO_NOT_CHANGE.md
5. 04_CXT_STATUS_AND_PROGRAM_CHECK.md
6. 05_NEXT_STEPS.md
7. 06_PROMPT_CHATGPT_PROJECT_CONTINUATION.md
8. 07_PROMPT_CHATGPT_CXT_REVISION.md
9. 08_REPOSITORY_MANIFEST.md

## Catatan keamanan

Seluruh file secret, credential, token, dan local config tetap dibiarkan di workspace lokal tetapi tidak disertakan ke arsip handoff. Untuk kebutuhan pengembangan baru, gunakan template `.env.example` atau `config.h.example`.
