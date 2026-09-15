# Panduan Wiring Step-by-Step — Prototipe SCADA Distribusi Listrik

**Tugas Akhir:** Perancangan Prototipe Sistem SCADA Distribusi Listrik Berbasis PLC OMRON yang Terintegrasi dengan Platform Monitoring IoT
**Penyusun:** Almar'u Zaim Mizan (04231006) — Teknik Elektro, Institut Teknologi Kalimantan
**Status:** Draf implementasi — seluruh nilai yang ditandai *(perlu dikonfirmasi)* wajib diverifikasi terhadap datasheet komponen fisik sebelum eksekusi.

---

## 0. Ringkasan Referensi Cepat

| Bagian | Komponen | Alamat/Pin PLC atau ESP32 |
|---|---|---|
| Input digital | Push button LOCK | PLC input 0.00 |
| Input digital | Push button UNLOCK | PLC input 0.01 |
| Input digital | Push button NO | PLC input 0.02 |
| Input digital | Push button NC | PLC input 0.03 |
| Output digital | Koil relay MY2N | PLC output 100.00 |
| Analog (ESP32) | ZMPT101B sisi sumber | GPIO32 (ADC1_CH4) |
| Analog (ESP32) | ZMPT101B sisi beban | GPIO33 (ADC1_CH5) |
| Analog (ESP32) | ACS712 sisi sumber | GPIO34 (ADC1_CH6) |
| Analog (ESP32) | ACS712 sisi beban | GPIO35 (ADC1_CH7) |
| Serial (ESP32↔PLC) | MAX3232 TXD/RXD/GND | UART2 ESP32 (GPIO17 TX2 → RXD MAX3232, GPIO16 RX2 ← TXD MAX3232) *(perlu dikonfirmasi — lihat Bagian 4)* |

> Alokasi input/output digital di atas mengikuti Tabel 3.9 pada proposal TA (Alokasi I/O PLC untuk Push Button dan Kendali Relay). Alokasi GPIO analog mengikuti Sub-bab 3.4.1 proposal (dikonfirmasi berada di ADC1, aman dari konflik radio WiFi).

---

## 1. Keselamatan Kerja — WAJIB DIBACA SEBELUM MULAI

Prototipe ini melibatkan **tegangan AC 220V** pada sisi motor/beban. Kelalaian pada bagian ini berisiko sengatan listrik, korsleting, atau kerusakan komponen.

1. **Matikan seluruh catu daya AC sebelum menyentuh kabel apa pun.** Cabut steker dari sumber 220 VAC, jangan hanya mengandalkan saklar/relay dalam keadaan OFF.
2. **Kerjakan pengawatan sisi DC (5V sensor, 24V koil relay, ESP32, PLC) terlebih dahulu** dalam kondisi seluruh sistem tidak bertegangan. Baru sambungkan sisi AC 220V paling akhir, setelah seluruh pengawatan DC diperiksa ulang.
3. **Pisahkan secara fisik** jalur kabel AC 220V dari jalur sinyal DC bertegangan rendah (sensor, komunikasi serial, koil relay) — gunakan jalur kabel/duct terpisah, jangan diikat bersama. Ini mengurangi risiko gangguan elektromagnetik sekaligus risiko keselamatan bila insulasi kabel AC rusak.
4. **Gunakan alas kerja kering dan non-konduktif.** Jangan bekerja di lantai basah atau dengan tangan basah.
5. **Uji kontinuitas dan short-circuit dengan multimeter** (dalam keadaan tidak bertegangan) sebelum menyalakan sistem pertama kali.
6. **Nyalakan bertahap**: pertama catu daya DC saja (verifikasi ESP32 dan PLC menyala normal, tanpa motor tersambung), baru kemudian sisi AC.
7. Jika ragu pada satu langkah mana pun, hentikan dan konsultasikan ke pembimbing/laboran sebelum melanjutkan.

---

## 2. Urutan Kerja Keseluruhan

1. Siapkan seluruh komponen sesuai Tabel 3.1–3.7 pada proposal TA (lihat juga Bagian 0 di atas).
2. Rakit jalur catu daya DC (5V ke sensor & ESP32, 24V ke koil relay) — **tanpa AC tersambung**.
3. Pasang dan awat keempat sensor (2× ZMPT101B, 2× ACS712) ke ADC1 ESP32.
4. Pasang dan awat modul MAX3232 antara UART2 ESP32 dan port RS-232C bawaan PLC.
5. Pasang dan awat keempat push button ke input digital PLC.
6. Pasang dan awat koil relay MY2N ke output digital PLC, dengan kontak relay pada jalur AC yang **masih terputus**.
7. Periksa ulang seluruh sambungan DC dengan multimeter (kontinuitas, tidak ada short antar-jalur).
8. Nyalakan catu daya DC, verifikasi ESP32 dan PLC boot normal (indikator power/run menyala, tidak ada asap/bau terbakar).
9. Baru setelah langkah 8 berhasil, sambungkan jalur AC 220V ke motor melalui kontak relay.
10. Lakukan uji fungsi bertahap (lihat Sub-bab 3.4.6 proposal untuk rencana pengujian lengkap).

---

## 3. Catu Daya

| Jalur | Tegangan | Tujuan | Catatan |
|---|---|---|---|
| DC sensor | 5V | Modul ZMPT101B ×2, ACS712 ×2 | Umumnya dari modul step-down/adaptor 5V terpisah dari power ESP32, atau dari pin 5V/VIN ESP32 jika arus mencukupi *(perlu dikonfirmasi terhadap datasheet adaptor yang dipakai)* |
| DC koil relay | 24VDC *(perlu dikonfirmasi — sesuaikan dengan varian MY2N yang dipakai; tersedia varian 12/24/48VDC, lihat proposal Tabel 3.6)* | Koil relay MY2N | **Jangan disatukan** dengan jalur 5V sensor — gunakan adaptor/regulator terpisah |
| AC beban | 220VAC | Motor listrik 1 fasa (melalui kontak relay) | Sambungkan **terakhir**, lihat Bagian 1 |
| DC PLC | 100–240VAC (bukan DC — PLC OMRON CP1E-N30DR-A memakai catu daya AC langsung) | Unit CPU PLC | Ikuti label rating pada body PLC; jangan disamakan dengan catu daya 24VDC koil relay |

---

## 4. Sensor Tegangan & Arus → ADC1 ESP32

Keempat sensor terhubung ke pin GPIO32–35 ESP32, seluruhnya pada ADC1 agar pembacaan tetap andal saat radio WiFi aktif (ADC2 tidak dapat dipakai bersamaan dengan WiFi pada ESP32).

| Sensor | Posisi Pengukuran | Pin GPIO ESP32 | Kanal ADC1 |
|---|---|---|---|
| ZMPT101B #1 | Sisi sumber (sebelum relay MY2N) | GPIO32 | ADC1_CH4 |
| ZMPT101B #2 | Sisi beban (sesudah relay MY2N) | GPIO33 | ADC1_CH5 |
| ACS712 #1 | Sisi sumber (sebelum relay MY2N) | GPIO34 | ADC1_CH6 |
| ACS712 #2 | Sisi beban (sesudah relay MY2N) | GPIO35 | ADC1_CH7 |

**Langkah pengawatan per sensor:**
1. Sambungkan pin VCC modul ke jalur 5V, GND modul ke GND bersama (common ground dengan ESP32 — **wajib**, tanpa ground bersama pembacaan ADC akan mengambang/tidak akurat).
2. Sambungkan pin output analog modul (label "Out"/"OUT" pada ACS712, output sekunder pada ZMPT101B) ke pin GPIO ADC1 sesuai tabel di atas.
3. Untuk ACS712: jalur konduktor yang arusnya diukur dilewatkan melalui lubang sensor pada modul (bukan disolder ke pin sensor) — pastikan arah arus sesuai tanda panah pada body modul agar pembacaan tidak terbalik polaritas.
4. Untuk ZMPT101B: sisi primer (tegangan tinggi) disambungkan paralel terhadap titik ukur (sumber/beban), **bukan** seri — modul ini adalah transformator step-down presisi, kesalahan menyambung seri dapat merusak modul dan/atau menyebabkan rangkaian terbuka pada jalur yang diukur.
5. Ulangi untuk seluruh 4 modul, dengan titik ukur sumber sebelum kontak relay dan titik ukur beban sesudah kontak relay (lihat Gambar 3.2/3.3 proposal untuk skema lengkap).

⚠️ **ZMPT101B mengukur tegangan AC 220V pada sisi primer.** Ikuti prosedur keselamatan Bagian 1 — kerjakan sisi ini hanya setelah seluruh AC diputus, dan gunakan Panduan Kalibrasi (dokumen terpisah, `02_Panduan_Kalibrasi_ZMPT101B.md`) untuk prosedur kalibrasi amannya.

---

## 5. Modul MAX3232 ↔ ESP32 ↔ PLC (Modbus RTU via RS-232C)

Modul MAX3232 mengonversi level logika TTL 3,3V (ESP32) ke level tegangan RS-232C yang disyaratkan port bawaan PLC CP1E-N30DR-A, memakai 3 jalur (TXD, RXD, GND) tanpa RTS/CTS.

| Sisi TTL (ke ESP32) | Sisi RS-232C (ke PLC, konektor DB9) |
|---|---|
| VCC → 3.3V ESP32 | Pin 2 (RD/RXD PLC) ← TXD MAX3232 |
| GND → GND ESP32 (common ground) | Pin 3 (SD/TXD PLC) → RXD MAX3232 |
| RXD (MAX3232) ← TX2 ESP32 *(perlu dikonfirmasi nomor GPIO UART2 — default umum GPIO17, cek board DevKit yang dipakai)* | Pin 5 (SG — signal ground PLC) — GND |
| TXD (MAX3232) → RX2 ESP32 *(perlu dikonfirmasi nomor GPIO UART2 — default umum GPIO16, cek board DevKit yang dipakai)* | — |

**Catatan penting:**
- **TXD sisi satu tersambung ke RXD sisi lain, dan sebaliknya** (silang, bukan lurus) — ini pola standar komunikasi serial point-to-point. Bila komunikasi Modbus RTU gagal total setelah pengawatan, ini adalah penyebab tersering pertama untuk dicek.
- Konektor DB9 PLC memakai pin 2 (RD), pin 3 (SD), dan pin 5 (SG) sesuai *CP1E CPU Unit Software User's Manual* (Cat. No. W480). Pin lain pada DB9 (RS/CS/DR/ER) tidak diperlukan untuk mode 3-kabel ini.
- Gunakan kabel pendek (idealnya <3 meter, sesuai batas jarak transmisi RS-232C ±15m pada datasheet Omron P061-E1-15) untuk keandalan sinyal.

---

## 6. Push Button dan Koil Relay → PLC

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
1. Setiap push button disambungkan antara terminal input PLC yang sesuai dan terminal common (COM) input PLC — verifikasi apakah PLC dikonfigurasi sebagai sinking (NPN) atau sourcing (PNP) sebelum menentukan sisi common yang benar *(perlu dikonfirmasi terhadap konfigurasi aktual PLC CP1E-N30DR-A yang dipakai)*.
2. Push button NC dan NO terhubung **langsung** ke input PLC tanpa melalui ESP32 (jalur lokal *hardwired* sesuai proposal Sub-bab 3.4.1) — pastikan kabel ini tidak tercampur dengan jalur sinyal ESP32.
3. Koil relay MY2N disambungkan ke output 100.00 PLC melalui catu daya DC koil (lihat Bagian 3) — **kontak** relay (yang menyambung/memutus 220VAC ke motor) adalah rangkaian fisik terpisah dari koil, sambungkan sesuai Gambar 3.3 proposal.

---

## 7. Tabel Ringkas Alokasi Pin/Alamat (Rekap Akhir)

| Kategori | Item | Alamat/Pin |
|---|---|---|
| PLC Input | LOCK | 0.00 |
| PLC Input | UNLOCK | 0.01 |
| PLC Input | NC | 0.02 |
| PLC Input | NO | 0.03 |
| PLC Output | Koil Relay MY2N | 100.00 |
| PLC Serial | RS-232C bawaan (DB9 pin 2/3/5) | Port bawaan CPU |
| ESP32 ADC1 | ZMPT101B sumber | GPIO32 |
| ESP32 ADC1 | ZMPT101B beban | GPIO33 |
| ESP32 ADC1 | ACS712 sumber | GPIO34 |
| ESP32 ADC1 | ACS712 beban | GPIO35 |
| ESP32 UART2 | TX2 → MAX3232 RXD | GPIO17 *(perlu dikonfirmasi)* |
| ESP32 UART2 | RX2 ← MAX3232 TXD | GPIO16 *(perlu dikonfirmasi)* |

---

## 8. Verifikasi Akhir Sebelum Uji Coba

- [ ] Seluruh sambungan DC diperiksa dengan multimeter (kontinuitas benar, tidak ada short)
- [ ] Ground bersama (common ground) antara ESP32, sensor, dan MAX3232 terkonfirmasi
- [ ] Jalur AC 220V terpisah fisik dari jalur sinyal DC
- [ ] Arah pemasangan ACS712 (panah arus) sesuai
- [ ] ZMPT101B tersambung paralel, bukan seri
- [ ] TXD/RXD MAX3232↔PLC tersambung silang
- [ ] Polaritas catu daya koil relay benar
- [ ] Sistem dinyalakan bertahap (DC dahulu, AC terakhir) sesuai Bagian 1
