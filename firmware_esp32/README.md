# README — Firmware ESP32 SCADA Distribusi Listrik

Ringkasan desain untuk referensi cepat dan bahan BAB 4. Detail lengkap ada di komentar masing-masing file `src/*.cpp` dan `src/*.h`.

## Struktur File

| File | Isi |
|---|---|
| `src/config.h` | **Sumber kebenaran tunggal** — pin, peta register Modbus, kredensial WiFi/MQTT, konstanta kalibrasi |
| `src/sensors.h/.cpp` | Pembacaan ADS1115 16-bit via I2C + perhitungan RMS |
| `src/modbus_slave.h/.cpp` | Modbus RTU slave (library ModbusRTU/emelianov), termasuk watchdog estimasi COMFail lokal |
| `src/mqtt_handler.h/.cpp` | WiFi + MQTT (TLS, LWT, publish/subscribe) ke HiveMQ Cloud |
| `src/shared_state.h` | Primitif FreeRTOS (queue + volatile bool) untuk komunikasi aman Core 0 ↔ Core 1 |
| `src/main.cpp` | `setup()`/`loop()`, pembuatan dua task dual-core |

## Peta Register Modbus RTU (Draf — lihat `config.h` untuk nilai definitif)

ESP32 = **slave**, PLC = **master**. Alamat 0-based sesuai konvensi library.

| Alamat | Nama | Tipe | Isi | Skala |
|---|---|---|---|---|
| 0 | `REG_RMS_V_SUMBER` | Input Register | Tegangan RMS sisi sumber | ÷100 → Volt |
| 1 | `REG_RMS_V_BEBAN` | Input Register | Tegangan RMS sisi beban | ÷100 → Volt |
| 2 | `REG_RMS_I_SUMBER` | Input Register | Arus RMS sisi sumber | ÷1000 → Ampere |
| 3 | `REG_RMS_I_BEBAN` | Input Register | Arus RMS sisi beban | ÷1000 → Ampere |
| 4 | `REG_KUALITAS_DATA` | Input Register | Bitmask GOOD(0)/SUSPECT(1) per kanal (bit0-3) | — |
| 5 | `REG_LRUFAIL` | Input Register | Status LRUFail (0=NORMAL, 1=FAIL) | — |
| 6 | `REG_CMD_REMOTE` | Holding Register | Perintah remote (0=none, 1=NO, 2=NC) — **PLC wajib tulis-balik 0 setelah eksekusi** | — |

**Wajib dikonfirmasi**: pemetaan alamat di atas ke konfigurasi *Modbus-RTU Easy Master* pada PLC Setup CX-Programmer harus disamakan manual — tidak ada sinkronisasi otomatis antara firmware dan ladder logic.

**Mengapa "Arus Gangguan" tidak punya register sendiri**: nilai ini diusulkan dihitung di ladder logic PLC (bandingkan `REG_RMS_I_BEBAN` terhadap ambang batas), bukan dikirim terpisah dari ESP32 — karena secara fisik berasal dari sensor arus yang sama, dan sesuai Batasan Rancangan proposal (poin keterbatasan Trip Otomatis), nilai ini murni untuk tampilan SCADA/HMI, tidak memicu aksi apa pun di ESP32 maupun firmware.

## Dua Keputusan Desain yang Perlu Diklarifikasi (dari prompt awal)

### 1. Propagasi status COMFail ke aplikasi mobile

COMFail (kegagalan link Modbus RTU) dideteksi watchdog **di sisi PLC**. Secara prinsip, PLC tidak bisa memberi tahu ESP32 tentang status ini melalui link yang sedang gagal itu sendiri. Solusi yang diimplementasikan: ESP32 melakukan **estimasi mandiri** dengan watchdog terpisah di sisinya sendiri (`modbusEstimasiComFailLokal()` pada `modbus_slave.cpp`) — mengukur waktu sejak permintaan Modbus valid terakhir diterima dari PLC. Estimasi ini dipublikasikan ke topic `TOPIC_STATUS_COMF` dengan `"source":"esp32_watchdog_estimate"` agar jelas ini **bukan** pembacaan langsung status internal PLC. Perbedaan ini perlu divalidasi empiris pada pengujian Sub-bab 3.4.6 dan didokumentasikan sebagai keterbatasan desain di BAB 4.

### 2. Pola *handshake* command remote

Register `REG_CMD_REMOTE` dirancang dengan pola tulis-baca-tulis-balik (acknowledge): ESP32 menulis nilai perintah (1=NO/2=NC) saat menerima dari MQTT; PLC membaca lalu mengeksekusi ladder logic (dengan gerbang Hot Line=UNLOCK, LRUFail=NORMAL, COMFail=NORMAL); PLC **wajib** menulis-balik 0 ke register yang sama setelah eksekusi, agar perintah yang sama tidak tereksekusi berulang pada polling berikutnya. Ini perlu diimplementasikan pada ladder logic CX-Programmer sisi PLC — firmware ESP32 tidak melakukan auto-clear.

## Status Migrasi ADS1115

Migrasi dari ADC bawaan ESP32 ke ADS1115 16-bit sudah selesai di firmware.
ADS1115 memakai alamat I2C `0x48`, SDA GPIO8, dan SCL GPIO9. Pemetaan kanal
adalah A0=ZMPT sumber, A1=ZMPT beban, A2=ACS712 sumber, dan A3=ACS712 beban.
Format data MQTT tidak berubah. ADS1115 dikonfigurasi pada `GAIN_ONE` dan
`860 SPS`; kalibrasi sensor wajib diulang setelah migrasi.

## Asumsi yang Perlu Diverifikasi Sebelum Implementasi Akhir

- Pin UART2 (GPIO16/17) — cek terhadap board DevKit V4 fisik yang dipakai
- Koefisien kalibrasi ZMPT101B (`ZMPT_*_GAIN/OFFSET`) — isi ulang setelah Panduan Kalibrasi (dokumen 02) dijalankan
- Sensitivitas ACS712 (`ACS712_MV_PER_AMP`, `ACS712_ZERO_OFFSET_MV`) — nilai datasheet nominal, pertimbangkan kalibrasi serupa untuk akurasi lebih baik
- Nama fungsi callback `onGetIreg`/`onSetHreg` pada `modbus_slave.cpp` — cek terhadap API.md versi library yang benar-benar terpasang
- Ambang batas watchdog COMFail lokal (`AMBANG_WATCHDOG_MS`) dan ambang kewajaran kualitas data (`RMS_ADC_MIN_WAJAR`/`MAX_WAJAR`) — sesuaikan setelah pengamatan pola polling PLC aktual
- Pilihan `setCACert()` vs `setInsecure()` pada `mqtt_handler.cpp` — isi sertifikat CA asli, atau tetapkan sebagai keputusan sadar bila tetap memakai `setInsecure()` untuk tahap prototipe
