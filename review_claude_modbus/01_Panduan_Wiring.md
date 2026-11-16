# Panduan Wiring Step-by-Step — Prototipe SCADA Distribusi Listrik

**Tugas Akhir:** Perancangan Prototipe Sistem SCADA Distribusi Listrik Berbasis PLC OMRON yang Terintegrasi dengan Platform Monitoring IoT
**Penyusun:** Almar'u Zaim Mizan (04231006) — Teknik Elektro, Institut Teknologi Kalimantan
**Revisi:** ESP32-S3 DevKitC-1 dengan ADC internal, 2× ZMPT101B, 2× ACS712, dan MAX3232. ADS1115 tidak digunakan pada firmware aktif.
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
| ADC internal ESP32-S3 | ZMPT101B sisi sumber | GPIO4 |
| ADC internal ESP32-S3 | ZMPT101B sisi beban | GPIO5 |
| ADC internal ESP32-S3 | ACS712 sisi sumber | GPIO6 |
| ADC internal ESP32-S3 | ACS712 sisi beban | GPIO7 |
| Serial (ESP32-S3 ↔ PLC) | MAX3232 TXD/RXD/GND | UART: TX=GPIO17, RX=GPIO18 |

> Alokasi input/output digital PLC mengikuti Tabel 3.15 dan 3.16 pada draft TA versi 2. Peta register Modbus dan penjelasan desain lengkap ada di `firmware_esp32/README.md`.

---

## 1. Keselamatan Kerja — WAJIB DIBACA SEBELUM MULAI

Prototipe ini melibatkan **tegangan AC 220V** pada sisi motor/beban. Kelalaian pada bagian ini berisiko sengatan listrik, korsleting, atau kerusakan komponen.

1. **Matikan seluruh catu daya AC sebelum menyentuh kabel apa pun.** Cabut steker dari sumber 220 VAC, jangan hanya mengandalkan saklar/relay dalam keadaan OFF.
2. **Kerjakan pengawatan sisi DC/logika (I2C, sensor, koil relay, ESP32, PLC) terlebih dahulu** dalam kondisi seluruh sistem tidak bertegangan. Baru sambungkan sisi AC 220V paling akhir, setelah seluruh pengawatan DC diperiksa ulang.
3. **Pisahkan secara fisik** jalur kabel AC 220V dari jalur sinyal DC bertegangan rendah (I2C, sensor, komunikasi serial, koil relay) — gunakan jalur kabel/duct terpisah, jangan diikat bersama.
4. **Gunakan alas kerja kering dan non-konduktif.** Jangan bekerja di lantai basah atau dengan tangan basah.
5. **Uji kontinuitas dan short-circuit dengan multimeter** (dalam keadaan tidak bertegangan) sebelum menyalakan sistem pertama kali.
6. **Nyalakan bertahap**: pertama catu daya DC saja (verifikasi ESP32-S3 dan PLC menyala normal, tanpa motor tersambung), baru kemudian sisi AC.
7. **GPIO ESP32-S3 hanya tahan tegangan maksimum 3,3V** — pastikan keluaran analog setiap modul sensor tetap dalam rentang ADC dan jangan melebihi batas pin GPIO.
8. Jika ragu pada satu langkah mana pun, hentikan dan konsultasikan ke pembimbing/laboran sebelum melanjutkan.

---

## 2. Urutan Kerja Keseluruhan

1. Siapkan PLC OMRON CP1E-N30DR-A, ESP32-S3 DevKitC-1, MAX3232, 2× ZMPT101B, 2× ACS712, relay MY2N, motor 1 fasa, dan 4 push button.
2. Rakit jalur catu daya DC sensor/logika serta catu koil relay sesuai rating komponen — **tanpa AC tersambung**.
3. Hubungkan output analog ke GPIO4-GPIO7 sesuai tabel di atas.
5. Pasang dan awat modul MAX3232 antara UART ESP32-S3 (GPIO17/GPIO18) dan port RS-232C bawaan PLC.
6. Pasang dan awat keempat push button ke input digital PLC.
7. Pasang dan awat koil relay MY2N ke output digital PLC, dengan kontak relay pada jalur AC yang **masih terputus**.
8. Periksa ulang seluruh sambungan DC dengan multimeter (kontinuitas, tidak ada short antar-jalur).
9. Nyalakan catu daya DC, verifikasi ESP32-S3 dan PLC boot normal.
10. Baru setelah langkah 9 berhasil, sambungkan jalur AC 220V ke motor melalui kontak relay.
11. Lakukan uji fungsi bertahap sesuai rencana pengujian pada Sub-bab 3.4.6 proposal.

---

## 3. Catu Daya

| Jalur | Tegangan | Tujuan | Catatan |
|---|---|---|---|
| DC logika | Sesuai rating tiap modul | ESP32-S3 dan sensor | Pastikan keluaran analog sensor tidak melebihi rentang aman ADC ESP32-S3 |
| DC koil relay | 24VDC *(perlu dikonfirmasi — sesuaikan varian MY2N, lihat proposal Tabel 3.6)* | Koil relay MY2N | **Jangan disatukan** dengan jalur 3,3V/5V logika — gunakan adaptor/regulator terpisah |
| AC beban | 220VAC | Motor listrik 1 fasa (melalui kontak relay) | Sambungkan **terakhir**, lihat Bagian 1 |
| Catu daya PLC | 100–240VAC | Unit CPU PLC OMRON CP1E-N30DR-A | Ikuti label rating pada body PLC |

---

## 4. ADC Internal ESP32-S3

Firmware aktif menggunakan `analogReadMilliVolts()` pada ADC internal 12-bit. Jalur pembacaan sensor tidak menggunakan I2C atau ADS1115.

| Sensor | Pin ADC |
|---|---|
| ZMPT101B sumber | GPIO4 |
| ZMPT101B beban | GPIO5 |
| ACS712 sumber | GPIO6 |
| ACS712 beban | GPIO7 |

Periksa tegangan keluaran analog dan ground setiap modul terhadap rangkaian aktual sebelum menyambungkan ke GPIO.
3. Pin GPIO0 dan GPIO3 pada ESP32-S3 **sengaja dihindari** untuk keperluan apa pun di luar boot — keduanya pin *strapping* yang menentukan mode boot chip; memasang beban di situ saat power-on berisiko board gagal boot.

---

## 5. Sensor Tegangan & Arus → ADC Internal

| Sensor | Posisi Pengukuran | GPIO ESP32-S3 |
|---|---|---|
| ZMPT101B #1 | Sisi sumber (sebelum relay MY2N) | GPIO4 |
| ZMPT101B #2 | Sisi beban (sesudah relay MY2N) | GPIO5 |
| ACS712 #1 | Sisi sumber (sebelum relay MY2N) | GPIO6 |
| ACS712 #2 | Sisi beban (sesudah relay MY2N) | GPIO7 |

**Langkah pengawatan per sensor:**
1. Sambungkan catu dan ground setiap modul sesuai datasheet dan rangkaian isolasi yang digunakan.
2. Sambungkan output analog sensor ke GPIO4-GPIO7 sesuai tabel dan pastikan level sinyal aman untuk ADC ESP32-S3.
3. Untuk ACS712: jalur konduktor yang arusnya diukur dilewatkan melalui lubang sensor pada modul (bukan disolder ke pin sensor) — pastikan arah arus sesuai tanda panah pada body modul agar pembacaan tidak terbalik polaritas.
4. Untuk ZMPT101B: sisi primer (tegangan tinggi) disambungkan paralel terhadap titik ukur (sumber/beban), **bukan** seri — modul ini adalah transformator step-down presisi, kesalahan menyambung seri dapat merusak modul dan/atau menyebabkan rangkaian terbuka pada jalur yang diukur.
5. Ulangi untuk seluruh 4 modul, dengan titik ukur sumber sebelum kontak relay dan titik ukur beban sesudah kontak relay.

⚠️ **ZMPT101B mengukur tegangan AC pada sisi primer.** Ikuti prosedur keselamatan Bagian 1 dan dokumen `02_Panduan_Kalibrasi_ZMPT101B.md`. Jangan ubah koefisien firmware tanpa hasil ukur aktual dan persetujuan.

---

## 6. Modul MAX3232 ↔ ESP32-S3 ↔ PLC (Modbus RTU via RS-232C)

| Sisi TTL (ke ESP32-S3) | Sisi RS-232C (ke PLC, konektor DB9) |
|---|---|
| VCC → 3,3V ESP32-S3 | Pin 2 (SD/TXD PLC) → sisi terima RS-232 modul MAX3232 (R1IN) |
| GND → GND ESP32-S3 (common ground) | Pin 3 (RD/RXD PLC) ← sisi kirim RS-232 modul MAX3232 (T1OUT) |
| GPIO17 (TX ESP32-S3) → pin RXD modul (T1IN) | Pin 9 (SG — signal ground PLC) — GND modul |
| GPIO18 (RX ESP32-S3) ← pin TXD modul (R1OUT) | — |

**Catatan penting:**
- **TXD sisi satu tersambung ke RXD sisi lain, dan sebaliknya** (silang, bukan lurus). Bila komunikasi Modbus RTU gagal total setelah pengawatan, ini penyebab tersering pertama untuk dicek.
- GPIO17/18 dipilih khusus karena berada di luar rentang I2C (GPIO8/9), di luar pin *strapping* (GPIO0/3/45/46), dan di luar pin USB native ESP32-S3 (GPIO19/20) — jangan dipindah ke pin lain tanpa mengecek ulang keempat kategori ini.
- Konektor DB9 PLC (RS-232C bawaan CP1E-N30DR-A) memakai pin 2 (SD), pin 3 (RD), dan pin 9 (SG) sesuai datasheet CP1E Omron (P061); pin 5 adalah CS (CTS) dan **bukan** SG. Cocokkan sekali lagi dengan *CP1E CPU Unit Hardware User's Manual* (Cat. No. W479) sebelum menyolder. Pin lain (RS/CS/DR/ER) tidak diperlukan untuk mode 3-kabel ini.
- Label RXD/TXD pada modul MAX3232 mengikuti sudut pandang mikrokontroler: pin RXD modul menerima dari TX ESP32-S3 (GPIO17), pin TXD modul mengirim ke RX ESP32-S3 (GPIO18). Bila modulmu berlabel sebaliknya, ikuti aturannya: TX ESP32-S3 masuk ke input TTL modul, RX ESP32-S3 datang dari output TTL modul.
- Gunakan kabel pendek (idealnya <3 meter, sesuai batas jarak transmisi RS-232C ±15m pada datasheet Omron P061-E1-15) untuk keandalan sinyal.

---

## 7. Push Button dan Koil Relay → PLC

| Push Button | Warna (konvensi IEC 60204-1/60447) | Alamat Input PLC |
|---|---|---|
| LOCK | Merah | 0.00 |
| UNLOCK | Hijau | 0.01 |
| NO (buka) | Merah | 0.02 |
| NC (tutup) | Hijau | 0.03 |

| Aktuator | Alamat Output PLC |
|---|---|
| Koil relay MY2N | 100.00 |

**Langkah pengawatan:**
1. Setiap push button disambungkan antara terminal input PLC yang sesuai dan terminal common (COM) input PLC — verifikasi konfigurasi sinking (NPN) atau sourcing (PNP) PLC sebelum menentukan sisi common yang benar *(perlu dikonfirmasi)*.
2. Push button NC dan NO terhubung **langsung** ke input PLC tanpa melalui ESP32-S3 (jalur lokal *hardwired*) — pisahkan pengawatan sinyal dari jalur AC.
3. Koil relay MY2N disambungkan ke output 100.00 PLC melalui catu daya DC koil (lihat Bagian 3) — **kontak** relay (yang menyambung/memutus 220VAC ke motor) adalah rangkaian fisik terpisah dari koil.

---

## 8. Tabel Ringkas Alokasi Pin/Alamat (Rekap Akhir)

| Kategori | Item | Alamat/Pin |
|---|---|---|
| PLC Input | LOCK | 0.00 |
| PLC Input | UNLOCK | 0.01 |
| PLC Input | NO (buka) | 0.02 |
| PLC Input | NC (tutup) | 0.03 |
| PLC Output | Koil Relay MY2N | 100.00 |
| PLC Serial | RS-232C bawaan (DB9: pin 2 SD, pin 3 RD, pin 9 SG) | Port bawaan CPU |
| ESP32-S3 ADC internal | ZMPT101B sumber | GPIO4 |
| ESP32-S3 ADC internal | ZMPT101B beban | GPIO5 |
| ESP32-S3 ADC internal | ACS712 sumber | GPIO6 |
| ESP32-S3 ADC internal | ACS712 beban | GPIO7 |
| ESP32-S3 UART | TX → MAX3232 RXD | GPIO17 |
| ESP32-S3 UART | RX ← MAX3232 TXD | GPIO18 |

---

## 9. Verifikasi Akhir Sebelum Uji Coba

- [ ] Seluruh sambungan DC diperiksa dengan multimeter (kontinuitas benar, tidak ada short)
- [ ] Ground/reference dan batas tegangan ADC sudah diperiksa untuk modul aktual
- [ ] Jalur AC 220V terpisah fisik dari jalur sinyal DC
- [ ] Arah pemasangan ACS712 (panah arus) sesuai
- [ ] ZMPT101B tersambung paralel, bukan seri
- [ ] TXD/RXD MAX3232↔PLC tersambung silang: pin 2 PLC (SD) ke sisi terima modul, pin 3 PLC (RD) dari sisi kirim modul, pin 9 PLC (SG) ke GND (bukan pin 5)
- [ ] GPIO17 (TX ESP32-S3) ke pin RXD modul dan GPIO18 (RX ESP32-S3) dari pin TXD modul
- [ ] Uji loopback Modbus dari PC (QModMaster atau Modbus Poll, 9600 8N1, slave 1, Input Register 0-5) berhasil sebelum PLC disambungkan
- [ ] Tidak ada sinyal >3,3V yang masuk langsung ke pin GPIO ESP32-S3
- [ ] Polaritas catu daya koil relay benar
- [ ] Sistem dinyalakan bertahap (DC dahulu, AC terakhir) sesuai Bagian 1
