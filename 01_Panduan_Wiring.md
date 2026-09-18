# Panduan Wiring Step-by-Step — Prototipe SCADA Distribusi Listrik

**Tugas Akhir:** Perancangan Prototipe Sistem SCADA Distribusi Listrik Berbasis PLC OMRON yang Terintegrasi dengan Platform Monitoring IoT
**Penyusun:** Almar'u Zaim Mizan (04231006) — Teknik Elektro, Institut Teknologi Kalimantan
**Revisi:** hardware final — ESP32-S3 DevKitC-1 (N8R2/N16R8) + ADS1115 (ADC eksternal 16-bit I2C) + ZMPT101B/ACS712 asli. *(Dokumen ini menggantikan revisi sebelumnya yang masih berbasis ESP32 DevKit V4 klasik dengan ADC bawaan.)*
**Status:** Draf implementasi — seluruh nilai yang ditandai *(perlu dikonfirmasi)* wajib diverifikasi terhadap datasheet komponen fisik sebelum eksekusi.

---

## 0. Ringkasan Referensi Cepat

| Bagian | Komponen | Alamat/Pin |
|---|---|---|
| Input digital | Push button LOCK | PLC input 0.00 |
| Input digital | Push button UNLOCK | PLC input 0.01 |
| Input digital | Push button NO | PLC input 0.02 |
| Input digital | Push button NC | PLC input 0.03 |
| Output digital | Koil relay MY2N | PLC output 100.00 |
| I2C (ESP32-S3 ↔ ADS1115) | SDA | GPIO8 |
| I2C (ESP32-S3 ↔ ADS1115) | SCL | GPIO9 |
| Analog (ADS1115) | ZMPT101B sisi sumber | Kanal A0 |
| Analog (ADS1115) | ZMPT101B sisi beban | Kanal A1 |
| Analog (ADS1115) | ACS712 sisi sumber | Kanal A2 |
| Analog (ADS1115) | ACS712 sisi beban | Kanal A3 |
| Serial (ESP32-S3 ↔ PLC) | MAX3232 TXD/RXD/GND | UART: TX=GPIO17, RX=GPIO18 |

> Alokasi input/output digital PLC mengikuti Tabel 3.9 pada proposal TA. Peta register Modbus dan penjelasan desain lengkap ada di `firmware_esp32/README.md`.

---

## 1. Keselamatan Kerja — WAJIB DIBACA SEBELUM MULAI

Prototipe ini melibatkan **tegangan AC 220V** pada sisi motor/beban. Kelalaian pada bagian ini berisiko sengatan listrik, korsleting, atau kerusakan komponen.

1. **Matikan seluruh catu daya AC sebelum menyentuh kabel apa pun.** Cabut steker dari sumber 220 VAC, jangan hanya mengandalkan saklar/relay dalam keadaan OFF.
2. **Kerjakan pengawatan sisi DC/logika (I2C, sensor, koil relay, ESP32, PLC) terlebih dahulu** dalam kondisi seluruh sistem tidak bertegangan. Baru sambungkan sisi AC 220V paling akhir, setelah seluruh pengawatan DC diperiksa ulang.
3. **Pisahkan secara fisik** jalur kabel AC 220V dari jalur sinyal DC bertegangan rendah (I2C, sensor, komunikasi serial, koil relay) — gunakan jalur kabel/duct terpisah, jangan diikat bersama.
4. **Gunakan alas kerja kering dan non-konduktif.** Jangan bekerja di lantai basah atau dengan tangan basah.
5. **Uji kontinuitas dan short-circuit dengan multimeter** (dalam keadaan tidak bertegangan) sebelum menyalakan sistem pertama kali.
6. **Nyalakan bertahap**: pertama catu daya DC saja (verifikasi ESP32-S3, ADS1115, dan PLC menyala normal, tanpa motor tersambung), baru kemudian sisi AC.
7. **GPIO ESP32-S3 hanya tahan tegangan maksimum 3,3V** — jangan sentuhkan sinyal apa pun di atas itu langsung ke pin GPIO (termasuk pin I2C SDA/SCL). ADS1115 sendiri dapat menerima input analog sesuai rentang gain yang dikonfigurasi firmware (±4,096V pada pengaturan `GAIN_ONE`) — tapi ini bukan alasan untuk sembarangan; tetap ikuti rentang keluaran sensor yang sudah dikondisikan modul ZMPT101B/ACS712.
8. Jika ragu pada satu langkah mana pun, hentikan dan konsultasikan ke pembimbing/laboran sebelum melanjutkan.

---

## 2. Urutan Kerja Keseluruhan

1. Siapkan seluruh komponen: PLC OMRON CP1E-N30DR-A, ESP32-S3 DevKitC-1, modul ADS1115, modul MAX3232, 2× ZMPT101B, 2× ACS712, relay MY2N, motor 1 fasa, 4 push button.
2. Rakit jalur catu daya DC (3,3V/5V ke sensor, ESP32-S3, dan ADS1115; 24VDC ke koil relay — *(perlu dikonfirmasi terhadap varian MY2N yang dipakai)*) — **tanpa AC tersambung**.
3. Pasang dan awat ADS1115 ke bus I2C ESP32-S3 (GPIO8/GPIO9).
4. Pasang dan awat keempat sensor (2× ZMPT101B, 2× ACS712) ke kanal A0-A3 ADS1115.
5. Pasang dan awat modul MAX3232 antara UART ESP32-S3 (GPIO17/GPIO18) dan port RS-232C bawaan PLC.
6. Pasang dan awat keempat push button ke input digital PLC.
7. Pasang dan awat koil relay MY2N ke output digital PLC, dengan kontak relay pada jalur AC yang **masih terputus**.
8. Periksa ulang seluruh sambungan DC dengan multimeter (kontinuitas, tidak ada short antar-jalur).
9. Nyalakan catu daya DC, verifikasi ESP32-S3, ADS1115 (LED indikator power bila ada), dan PLC boot normal.
10. Baru setelah langkah 9 berhasil, sambungkan jalur AC 220V ke motor melalui kontak relay.
11. Lakukan uji fungsi bertahap sesuai rencana pengujian pada Sub-bab 3.4.6 proposal.

---

## 3. Catu Daya

| Jalur | Tegangan | Tujuan | Catatan |
|---|---|---|---|
| DC logika | 3,3V (dari ESP32-S3) atau 5V terpisah | ADS1115, modul ZMPT101B ×2, ACS712 ×2 | ADS1115 mendukung 2,0–5,5V — sambungkan VDD ADS1115 ke **3,3V** ESP32-S3 agar level logika I2C konsisten, bukan 5V |
| DC koil relay | 24VDC *(perlu dikonfirmasi — sesuaikan varian MY2N, lihat proposal Tabel 3.6)* | Koil relay MY2N | **Jangan disatukan** dengan jalur 3,3V/5V logika — gunakan adaptor/regulator terpisah |
| AC beban | 220VAC | Motor listrik 1 fasa (melalui kontak relay) | Sambungkan **terakhir**, lihat Bagian 1 |
| Catu daya PLC | 100–240VAC | Unit CPU PLC OMRON CP1E-N30DR-A | Ikuti label rating pada body PLC |

---

## 4. ADS1115 ↔ ESP32-S3 (Bus I2C)

| Pin ADS1115 | Ke ESP32-S3 |
|---|---|
| VDD | 3,3V |
| GND | GND |
| SCL | GPIO9 |
| SDA | GPIO8 |
| ADDR | GND (alamat I2C default `0x48`) |
| ALRT | Tidak disambungkan (tidak dipakai firmware) |

**Langkah:**
1. Sambungkan VDD, GND, SCL, SDA, dan ADDR sesuai tabel di atas.
2. Bila di kemudian hari perlu menambah modul ADS1115 kedua (misalnya untuk sensor tambahan), ADDR dapat disambungkan ke VDD/SDA/SCL untuk mendapat alamat I2C berbeda (`0x49`/`0x4A`/`0x4B`) — di luar cakupan desain saat ini yang hanya memakai satu modul untuk 4 kanal.
3. Pin GPIO0 dan GPIO3 pada ESP32-S3 **sengaja dihindari** untuk keperluan apa pun di luar boot — keduanya pin *strapping* yang menentukan mode boot chip; memasang beban di situ saat power-on berisiko board gagal boot.

---

## 5. Sensor Tegangan & Arus → Kanal ADS1115

| Sensor | Posisi Pengukuran | Kanal ADS1115 |
|---|---|---|
| ZMPT101B #1 | Sisi sumber (sebelum relay MY2N) | A0 |
| ZMPT101B #2 | Sisi beban (sesudah relay MY2N) | A1 |
| ACS712 #1 | Sisi sumber (sebelum relay MY2N) | A2 |
| ACS712 #2 | Sisi beban (sesudah relay MY2N) | A3 |

**Langkah pengawatan per sensor:**
1. Sambungkan pin VCC modul ke jalur 3,3V/5V *(sesuai spesifikasi modul masing-masing — cek datasheet, ZMPT101B dan ACS712 umumnya toleran 3,3–5V)*, GND modul ke GND bersama (common ground dengan ESP32-S3 dan ADS1115 — **wajib**, tanpa ground bersama pembacaan ADC akan mengambang/tidak akurat).
2. Sambungkan pin output analog modul (label "Out"/"OUT" pada ACS712, output sekunder pada ZMPT101B) ke kanal A0-A3 ADS1115 sesuai tabel di atas — **bukan** langsung ke pin GPIO ESP32-S3.
3. Untuk ACS712: jalur konduktor yang arusnya diukur dilewatkan melalui lubang sensor pada modul (bukan disolder ke pin sensor) — pastikan arah arus sesuai tanda panah pada body modul agar pembacaan tidak terbalik polaritas.
4. Untuk ZMPT101B: sisi primer (tegangan tinggi) disambungkan paralel terhadap titik ukur (sumber/beban), **bukan** seri — modul ini adalah transformator step-down presisi, kesalahan menyambung seri dapat merusak modul dan/atau menyebabkan rangkaian terbuka pada jalur yang diukur.
5. Ulangi untuk seluruh 4 modul, dengan titik ukur sumber sebelum kontak relay dan titik ukur beban sesudah kontak relay.

⚠️ **ZMPT101B mengukur tegangan AC 220V pada sisi primer.** Ikuti prosedur keselamatan Bagian 1 — kerjakan sisi ini hanya setelah seluruh AC diputus, dan gunakan dokumen `02_Panduan_Kalibrasi_ZMPT101B.md` untuk prosedur kalibrasi amannya. **Kalibrasi wajib diulang** dengan setup ADS1115 ini — koefisien dari kalibrasi ADC bawaan ESP32 sebelumnya tidak berlaku lagi (resolusi dan rentang tegangan referensinya berbeda).

---

## 6. Modul MAX3232 ↔ ESP32-S3 ↔ PLC (Modbus RTU via RS-232C)

| Sisi TTL (ke ESP32-S3) | Sisi RS-232C (ke PLC, konektor DB9) |
|---|---|
| VCC → 3,3V ESP32-S3 | Pin 2 (RD/RXD PLC) ← TXD MAX3232 |
| GND → GND ESP32-S3 (common ground) | Pin 3 (SD/TXD PLC) → RXD MAX3232 |
| RXD (MAX3232) ← GPIO18 ESP32-S3 | Pin 5 (SG — signal ground PLC) — GND |
| TXD (MAX3232) → GPIO17 ESP32-S3 | — |

**Catatan penting:**
- **TXD sisi satu tersambung ke RXD sisi lain, dan sebaliknya** (silang, bukan lurus). Bila komunikasi Modbus RTU gagal total setelah pengawatan, ini penyebab tersering pertama untuk dicek.
- GPIO17/18 dipilih khusus karena berada di luar rentang I2C (GPIO8/9), di luar pin *strapping* (GPIO0/3/45/46), dan di luar pin USB native ESP32-S3 (GPIO19/20) — jangan dipindah ke pin lain tanpa mengecek ulang keempat kategori ini.
- Konektor DB9 PLC memakai pin 2 (RD), pin 3 (SD), dan pin 5 (SG) sesuai *CP1E CPU Unit Software User's Manual* (Cat. No. W480). Pin lain pada DB9 (RS/CS/DR/ER) tidak diperlukan untuk mode 3-kabel ini.
- Gunakan kabel pendek (idealnya <3 meter, sesuai batas jarak transmisi RS-232C ±15m pada datasheet Omron P061-E1-15) untuk keandalan sinyal.

---

## 7. Push Button dan Koil Relay → PLC

| Push Button | Warna (konvensi IEC 60204-1/60447) | Alamat Input PLC |
|---|---|---|
| LOCK | Merah | 0.00 |
| UNLOCK | Hijau | 0.01 |
| NC | Hijau | 0.02 |
| NO | Merah | 0.03 |

| Aktuator | Alamat Output PLC |
|---|---|
| Koil relay MY2N | 100.00 |

**Langkah pengawatan:**
1. Setiap push button disambungkan antara terminal input PLC yang sesuai dan terminal common (COM) input PLC — verifikasi konfigurasi sinking (NPN) atau sourcing (PNP) PLC sebelum menentukan sisi common yang benar *(perlu dikonfirmasi)*.
2. Push button NC dan NO terhubung **langsung** ke input PLC tanpa melalui ESP32-S3 (jalur lokal *hardwired*) — pastikan kabel ini tidak tercampur dengan jalur sinyal ESP32-S3/ADS1115.
3. Koil relay MY2N disambungkan ke output 100.00 PLC melalui catu daya DC koil (lihat Bagian 3) — **kontak** relay (yang menyambung/memutus 220VAC ke motor) adalah rangkaian fisik terpisah dari koil.

---

## 8. Tabel Ringkas Alokasi Pin/Alamat (Rekap Akhir)

| Kategori | Item | Alamat/Pin |
|---|---|---|
| PLC Input | LOCK | 0.00 |
| PLC Input | UNLOCK | 0.01 |
| PLC Input | NC | 0.02 |
| PLC Input | NO | 0.03 |
| PLC Output | Koil Relay MY2N | 100.00 |
| PLC Serial | RS-232C bawaan (DB9 pin 2/3/5) | Port bawaan CPU |
| ESP32-S3 I2C | SDA → ADS1115 | GPIO8 |
| ESP32-S3 I2C | SCL → ADS1115 | GPIO9 |
| ADS1115 | ZMPT101B sumber | A0 |
| ADS1115 | ZMPT101B beban | A1 |
| ADS1115 | ACS712 sumber | A2 |
| ADS1115 | ACS712 beban | A3 |
| ESP32-S3 UART | TX → MAX3232 RXD | GPIO17 |
| ESP32-S3 UART | RX ← MAX3232 TXD | GPIO18 |

---

## 9. Verifikasi Akhir Sebelum Uji Coba

- [ ] Seluruh sambungan DC diperiksa dengan multimeter (kontinuitas benar, tidak ada short)
- [ ] Ground bersama (common ground) antara ESP32-S3, ADS1115, sensor, dan MAX3232 terkonfirmasi
- [ ] Jalur AC 220V terpisah fisik dari jalur sinyal DC
- [ ] ADDR ADS1115 tersambung ke GND (alamat 0x48)
- [ ] Arah pemasangan ACS712 (panah arus) sesuai
- [ ] ZMPT101B tersambung paralel, bukan seri
- [ ] TXD/RXD MAX3232↔PLC tersambung silang
- [ ] Tidak ada sinyal >3,3V yang masuk langsung ke pin GPIO ESP32-S3
- [ ] Polaritas catu daya koil relay benar
- [ ] Sistem dinyalakan bertahap (DC dahulu, AC terakhir) sesuai Bagian 1
