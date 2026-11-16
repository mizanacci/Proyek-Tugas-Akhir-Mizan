# README — Firmware ESP32 SCADA Distribusi Listrik

Ringkasan desain untuk referensi cepat dan bahan BAB 4. Detail lengkap ada di komentar masing-masing file `src/*.cpp` dan `src/*.h`.

## Struktur File

| File | Isi |
|---|---|
| `src/config.h` | Konfigurasi lokal yang di-ignore; gunakan `src/config.h.example` sebagai template placeholder |
| `src/sensors.h/.cpp` | ADC internal ESP32-S3 pada GPIO4-GPIO7 + perhitungan RMS |
| `src/modbus_slave.h/.cpp` | Modbus RTU slave (library ModbusRTU/emelianov), termasuk watchdog estimasi COMFail lokal |
| `src/mqtt_handler.h/.cpp` | WiFi + MQTT (TLS, LWT, publish/subscribe) ke HiveMQ Cloud |
| `src/shared_state.h` | Primitif FreeRTOS (queue + volatile bool) untuk komunikasi aman Core 0 ↔ Core 1 |
| `src/main.cpp` | `setup()`/`loop()`, pembuatan dua task dual-core |

## Kontrak MQTT dan antrean command

Firmware menerima command hanya dari gateway pada
`scada/mizan/cmd/relay`, dengan payload `{"command":"NO"}` atau
`{"command":"NC"}`. Flutter tidak publish relay command langsung.
Antrean command antar-core memiliki kapasitas terbatas dan FIFO; command baru
ditolak dengan log jelas jika penuh, tidak menimpa command lama. MQTT belum
memiliki command ID atau correlated acknowledgement perangkat.

## Topic Status MQTT

| Topic | Perilaku |
|---|---|
| `scada/mizan/status/lrufail` | LRUFail/LWT, retained; `NORMAL` dipublikasikan setelah connect dan `FAIL` dikirim broker saat koneksi putus |
| `scada/mizan/status/comfail` | COMFail estimasi ESP32, retained; dikirim saat status berubah atau heartbeat setiap 5 detik |

## Peta Register Modbus RTU (Draf — lihat `config.h` untuk nilai definitif)

ESP32 = **slave**, PLC = **master**. Alamat 0-based sesuai konvensi library.

| Alamat | Nama | Tipe | Isi | Skala |
|---|---|---|---|---|
| 0 | `REG_RMS_V_SUMBER` | Input Register, FC04 | Tegangan RMS sisi sumber | ÷100 → Volt |
| 1 | `REG_RMS_V_BEBAN` | Input Register, FC04 | Tegangan RMS sisi beban | ÷100 → Volt |
| 2 | `REG_RMS_I_SUMBER` | Input Register, FC04 | Arus RMS sisi sumber | ÷1000 → Ampere |
| 3 | `REG_RMS_I_BEBAN` | Input Register, FC04 | Arus RMS sisi beban | ÷1000 → Ampere |
| 4 | `REG_KUALITAS_DATA` | Input Register, FC04 | Bitmask GOOD(0)/SUSPECT(1) per kanal (bit0-3) | — |
| 5 | `REG_LRUFAIL` | Input Register, FC04 | Status LRUFail (0=NORMAL, 1=FAIL) | — |
| 6 | `REG_CMD_REMOTE` | Holding Register, FC03/FC06 | Perintah remote (0=none, 1=NO, 2=NC) — PLC tulis-balik 0 setelah evaluasi | — |
| 7 | `REG_MODE_OPERASI_PLC` | Holding Register, FC06 | Heartbeat/status PLC: 0=UNKNOWN, 1=STANDBY, 2=RUN, 3=INVALID; write PLC memperbarui watchdog 5 s | — |

**Wajib dikonfirmasi**: atur port PLC secara manual ke *Modbus-RTU Easy Master*, 9600 8N1, serta cocokkan pemetaan alamat. CXT yang tersedia tidak menyimpan parameter serial.

Alamat pada tabel adalah indeks internal library mulai dari 0. Pada CX-Programmer,
ikuti notasi alamat yang ditampilkan konfigurasi Easy Master dan lakukan satu
uji baca terhadap register 0 sebelum mengisi seluruh map; jangan menambahkan
offset 30001/40001 tanpa memastikan konvensi perangkat lunak yang digunakan.

Firmware memakai 9600 baud, `SERIAL_8N1`, slave ID 1, UART2 TX GPIO17 dan RX
GPIO18 melalui MAX3232. Atur PLC ke Modbus-RTU Easy Master 9600 8N1, lalu
power-cycle PLC. Cocokkan DB9 pin 2 SD/TXD, pin 3 RD/RXD, dan pin 9 SG; pin 5
bukan signal ground. Wiring fisik belum diverifikasi.

Di CX-Programmer, buka PLC Settings untuk CP1E dan pilih port serial RS-232C
bawaan sebagai Modbus-RTU Easy Master. Tetapkan baud 9600, 8 data bit, parity
None, dan 1 stop bit; pastikan pengaturan sesuai varian CPU/port yang digunakan.
Transfer konfigurasi ke PLC lalu lakukan power-cycle agar serial setting berlaku.
File CXT yang tersedia tidak menyimpan atau membuktikan pengaturan ini.

**Mengapa "Arus Gangguan" tidak punya register sendiri**: nilai ini diusulkan dihitung di ladder logic PLC (bandingkan `REG_RMS_I_BEBAN` terhadap ambang batas), bukan dikirim terpisah dari ESP32 — karena secara fisik berasal dari sensor arus yang sama, dan sesuai Batasan Rancangan proposal (poin keterbatasan Trip Otomatis), nilai ini murni untuk tampilan SCADA/HMI, tidak memicu aksi apa pun di ESP32 maupun firmware.

## Dua Keputusan Desain yang Perlu Diklarifikasi (dari prompt awal)

### 1. Propagasi status COMFail ke aplikasi mobile

COMFail (kegagalan link Modbus RTU) dideteksi watchdog **di sisi PLC**. Secara prinsip, PLC tidak bisa memberi tahu ESP32 tentang status ini melalui link yang sedang gagal itu sendiri. Solusi yang diimplementasikan: ESP32 melakukan **estimasi mandiri** dengan watchdog terpisah di sisinya sendiri (`modbusEstimasiComFailLokal()` pada `modbus_slave.cpp`) — mengukur waktu sejak permintaan Modbus valid terakhir diterima dari PLC. Estimasi ini dipublikasikan ke topic `TOPIC_STATUS_COMF` dengan `"source":"esp32_watchdog_estimate"` agar jelas ini **bukan** pembacaan langsung status internal PLC. Perbedaan ini perlu divalidasi empiris pada pengujian Sub-bab 3.4.6 dan didokumentasikan sebagai keterbatasan desain di BAB 4.

### 2. Pola *handshake* command remote

Register `REG_CMD_REMOTE` dirancang dengan pola tulis-baca-tulis-balik (acknowledge): ESP32 menulis nilai perintah (1=NO/2=NC) saat menerima dari MQTT; PLC membaca lalu mengeksekusi ladder logic (dengan gerbang Hot Line=UNLOCK, LRUFail=NORMAL, COMFail=NORMAL); PLC **wajib** menulis-balik 0 ke register yang sama setelah eksekusi, agar perintah yang sama tidak tereksekusi berulang pada polling berikutnya. Ini perlu diimplementasikan pada ladder logic CX-Programmer sisi PLC — firmware ESP32 tidak melakukan auto-clear.

## Kalibrasi dan diagnostik sensor

Firmware memakai ADC internal ESP32-S3: GPIO4/5 untuk ZMPT sumber/beban dan
GPIO6/7 untuk ACS712 sumber/beban. Setiap kanal memakai 200 sampel dengan
interval target 500 us; RMS dihitung setelah bias DC dikurangi.

Rentang NORMAL tegangan adalah 200-230 V inklusif; nilai di luar rentang
menjadi SUSPECT lalu WARNING setelah 15 detik. Arus menjadi SUSPECT hanya pada
nilai strictly lebih besar dari 1.80 A atau ketika kanal tidak valid. Arus 0 A
yang valid tetap NORMAL/standby. Koefisien sensor tidak boleh diubah tanpa
hasil ukur aktual terhadap alat referensi dan persetujuan.

Aktifkan `MODE_DEBUG_SENSOR` hanya saat diagnosis. Serial Monitor akan
menampilkan rentang raw ADC, DC, RMS, nilai tegangan sebelum kalibrasi, nilai
setelah deadband/filter, serta arus hasil konversi. Jika tegangan ESP32
berbeda dari alat ukur true-RMS, catat pasangan `V_tampil` dan `V_ref` pada
kondisi yang sama sebelum menghitung koreksi gain. Jangan menetapkan gain baru
berdasarkan angka 320--330 V tanpa pengukuran referensi dan pemeriksaan
clipping/wiring.

## Checklist integrasi CP1E-N30DR-A

1. Pastikan port PLC yang dipakai benar-benar RS-232C bawaan dan MAX3232
   dipasang; jangan menghubungkan RS-232 langsung ke GPIO ESP32.
2. Cocokkan TX PLC ke RX MAX3232, RX PLC ke TX MAX3232, dan SG ke GND.
3. Cocokkan `PIN_MODBUS_RX2`/`PIN_MODBUS_TX2` dengan kabel fisik; workspace
   saat ini menggunakan RX GPIO18 dan TX GPIO17.
4. Di CX-Programmer 9.73, pastikan mode Easy Master, slave ID 1, parameter
   serial, FC04 untuk input register, dan FC03/FC06 untuk holding register.
5. Monitor register 0--5 saat ESP32 aktif. Jika tidak ada callback akses,
   COMFail lokal akan menjadi FAIL setelah 5 detik; angka ini adalah estimasi
   sisi ESP32, bukan status internal PLC.
6. Uji command dengan nilai 1/2, pastikan ladder membaca dan menulis balik 0
   setelah eksekusi. Firmware tidak menyatakan relay berubah hanya karena
   register berhasil ditulis.

## Baseline ADC Internal

ADC internal ESP32-S3 adalah satu-satunya jalur akuisisi sensor aktif; firmware
tidak memakai ADS1115 atau I2C. Telemetri MQTT dipublikasikan setiap 5 detik
atau segera ketika status sensor berubah.

## Mode Diagnosis

- `MODE_DIAG_UART` (default nonaktif) menonaktifkan sensor dan Modbus normal,
  lalu mengirim `ESP32-UART-TEST` tiap detik melalui UART2 dan mencetak byte
  yang diterima. Gunakan loopback MAX3232 sebelum menghubungkan PLC.
- `MODE_DEBUG_SENSOR` (default nonaktif) mencetak rata-rata DC, RMS, dan hasil
  konversi fisik setiap dua siklus pembacaan sensor.

## Status Integrasi

Gateway tetap DRY-RUN untuk dispatch command. Build dan simulasi software tidak
membuktikan komunikasi fisik ESP32-PLC atau operasi aktuator. Posisi fisik LBS
tetap UNKNOWN tanpa feedback auxiliary contact independen.

**Pelajaran untuk workflow ke depan**: perubahan besar (migrasi board/ADC) sebaiknya diverifikasi dengan membaca ulang kode yang benar-benar ter-commit, bukan hanya dari ringkasan "build sukses" — kompilasi berhasil tidak berarti logika/kalibrasinya benar.

## Asumsi yang Perlu Diverifikasi Sebelum Implementasi Akhir

- Verifikasi pin MAX3232 dan orientasi konektor DB9 pada perangkat fisik sebelum memasang kabel.
- Atur port CP1E ke Modbus-RTU Easy Master 9600 8N1 di CX-Programmer lalu power-cycle PLC; CXT tidak membuktikan setting serial.
- Validasi periode dan timeout heartbeat HREG7 pada PLC asli.
