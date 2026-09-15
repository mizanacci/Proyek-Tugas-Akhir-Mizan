# Panduan Kalibrasi Sensor Tegangan ZMPT101B

**Tugas Akhir:** Perancangan Prototipe Sistem SCADA Distribusi Listrik Berbasis PLC OMRON yang Terintegrasi dengan Platform Monitoring IoT
**Penyusun:** Almar'u Zaim Mizan (04231006) — Teknik Elektro, Institut Teknologi Kalimantan
**Target akurasi:** error kalibrasi <2%, mengikuti rujukan pengukuran RMS berbasis regresi pada Lazarević et al. (2022) sebagaimana dikutip pada proposal TA.

---

## ⚠️ Keselamatan Kerja Tegangan Tinggi

Kalibrasi ini melibatkan pengukuran **tegangan AC 220V secara langsung**. Ikuti seluruh poin berikut tanpa kecuali:

1. **Jangan bekerja sendirian.** Pastikan ada orang lain yang tahu Anda sedang melakukan pengujian bertegangan tinggi.
2. **Gunakan multimeter/alat ukur acuan yang sudah terverifikasi kalibrasinya** — jangan memakai alat yang tidak diketahui riwayat kalibrasinya sebagai acuan, karena seluruh proses ini akan mewarisi kesalahan alat acuan.
3. **Jangan menyentuh terminal ZMPT101B sisi primer saat bertegangan.** Sisi sekunder (output ke ESP32) aman disentuh, sisi primer tidak.
4. Jika memakai variabel transformer (variac) untuk memvariasikan titik tegangan uji, pastikan variac dalam kondisi baik dan diketahui riwayat perawatannya.
5. Matikan seluruh tegangan sebelum mengubah sambungan alat ukur.
6. Gunakan APD standar (alas kaki non-konduktif, hindari perhiasan logam) selama bekerja dengan tegangan AC.

---

## 1. Alat yang Diperlukan

| Alat | Fungsi |
|---|---|
| Multimeter AC True-RMS (atau alat ukur tegangan acuan lain yang terkalibrasi) | Referensi nilai tegangan aktual |
| Sumber tegangan AC variabel (variac) *(opsional, jika ingin banyak titik uji)*, atau beberapa titik tegangan tetap yang tersedia | Menghasilkan variasi titik uji |
| Laptop dengan Arduino IDE/PlatformIO tersambung ke ESP32 via USB | Membaca nilai ADC mentah dan menjalankan firmware uji |
| Trimmer/obeng kecil (bawaan modul ZMPT101B) | Kalibrasi hardware awal |
| Kabel jumper, breadboard (opsional untuk pengujian awal di luar panel) | Pengawatan sementara saat kalibrasi |

---

## 2. Tahap 1 — Kalibrasi Trimmer On-Board (Kalibrasi Kasar)

ZMPT101B dilengkapi trimmer on-board yang mengatur gain output sekunder. Tahap ini menyetel rentang keluaran modul secara kasar sebelum kalibrasi presisi via software.

1. Sambungkan ZMPT101B ke sumber AC yang diketahui nilainya (misalnya via variac disetel mendekati 220V, atau sumber tetap 220V jaringan lab) — **ikuti Bagian 1 keselamatan**.
2. Sambungkan output sekunder ZMPT101B ke osiloskop atau ke pin ADC ESP32 yang menjalankan firmware uji sederhana (baca `analogRead()` mentah, tampilkan lewat Serial Monitor).
3. Putar trimmer perlahan sambil mengamati amplitudo sinyal keluaran, sampai gelombang sinus keluaran berada dalam rentang yang memanfaatkan span ADC secara baik tanpa terpotong (*clipping*) — untuk ESP32 dengan ADC 12-bit (0–4095) dan tegangan referensi ~3,3V, target amplitudo puncak-ke-puncak sekitar 2,5–3,0V agar ada margin aman dari batas atas/bawah ADC.
4. Catat posisi trimmer (misal dengan foto atau tanda spidol) — hindari trimmer tergeser tanpa sengaja setelah tahap ini, karena akan mengubah seluruh hasil kalibrasi software di Tahap 2.

---

## 3. Tahap 2 — Kalibrasi Software (Regresi Least-Square)

### 3.1 Prinsip

Setelah gain hardware tetap (Tahap 1), hubungan antara nilai ADC mentah (atau nilai RMS ADC mentah) dan tegangan AC aktual pada umumnya **linear** dalam rentang kerja normal:

```
V_aktual ≈ a × RMS_ADC_mentah + b
```

dengan `a` (gain) dan `b` (offset) dicari melalui regresi *least-square* dari beberapa pasangan data (RMS ADC mentah, tegangan aktual). Bila hubungan tidak cukup linear pada seluruh rentang uji (terlihat dari residual regresi linear yang besar), pertimbangkan regresi polinomial orde-2 sebagai alternatif — dokumentasikan pilihan mana yang dipakai beserta alasannya di laporan BAB 4.

### 3.2 Langkah Kerja

1. **Siapkan firmware uji kalibrasi** — versi sederhana dari firmware utama yang hanya membaca ADC kanal ZMPT101B yang dikalibrasi, menghitung RMS dari 50 sampel (mengikuti parameter anggaran waktu proposal), dan mencetak nilai RMS ADC mentah ke Serial Monitor setiap ~1 detik.
2. **Variasikan titik tegangan uji.** Kumpulkan minimal 8–10 titik data tersebar merata pada rentang kerja yang relevan bagi prototipe (contoh: 180V, 190V, 200V, 210V, 220V, 230V, 240V — sesuaikan dengan rentang yang benar-benar bisa diakses dengan aman di lab). Semakin banyak dan tersebar titik data, semakin baik kualitas regresi.
3. **Untuk setiap titik uji:**
   a. Setel sumber tegangan pada nilai target.
   b. Catat nilai tegangan **aktual** dari multimeter acuan (bukan nilai yang "disetel", karena keduanya bisa sedikit berbeda).
   c. Catat nilai RMS ADC mentah dari Serial Monitor ESP32 (ambil rata-rata dari beberapa pembacaan berturut-turut untuk mengurangi noise, misal 5–10 kali baca lalu dirata-rata).
   d. Masukkan pasangan data ke tabel pencatatan (lihat Bagian 4 / template terpisah `Template_Kalibrasi_ZMPT101B.xlsx`).
4. **Lakukan regresi linear** (`V_aktual = a × RMS_ADC + b`) dari seluruh pasangan data — bisa memakai Excel (fungsi `SLOPE`/`INTERCEPT` atau *trendline* pada grafik sebar), Python (`numpy.polyfit`), atau kalkulator regresi manual.
5. **Hitung error tiap titik**: `error% = |V_prediksi − V_aktual| / V_aktual × 100%`, dengan `V_prediksi` dihitung memakai koefisien `a, b` hasil regresi. Verifikasi seluruh titik berada di bawah target 2%; jika ada titik yang jauh melampaui, periksa kemungkinan kesalahan pencatatan pada titik tersebut atau pertimbangkan regresi polinomial.
6. **Masukkan koefisien `a` dan `b` ke firmware** (lihat `config.h` pada kode firmware — konstanta `ZMPT_SUMBER_GAIN`, `ZMPT_SUMBER_OFFSET`, dan pasangannya untuk sisi beban). **Ulangi seluruh Tahap 2 secara terpisah untuk modul ZMPT101B sisi sumber dan sisi beban** — kedua modul fisik yang berbeda hampir pasti memiliki koefisien kalibrasi yang sedikit berbeda meski tipe/modelnya sama.
7. **Verifikasi akhir**: setelah koefisien dimasukkan ke firmware, uji ulang pada beberapa titik tegangan (boleh titik yang sama atau titik baru sebagai validasi independen) dan bandingkan pembacaan akhir firmware (dalam satuan Volt, bukan ADC mentah) terhadap multimeter acuan.

---

## 4. Template Tabel Pencatatan Data

Salin tabel berikut untuk **setiap modul ZMPT101B** (sumber dan beban dicatat terpisah).

**Modul: ☐ Sisi Sumber ☐ Sisi Beban**

| No. | Tegangan Disetel (V) | Tegangan Aktual — Multimeter (V) | RMS ADC Mentah (rata-rata n bacaan) | V Prediksi (setelah regresi) | Error (%) |
|---|---|---|---|---|---|
| 1 | | | | | |
| 2 | | | | | |
| 3 | | | | | |
| 4 | | | | | |
| 5 | | | | | |
| 6 | | | | | |
| 7 | | | | | |
| 8 | | | | | |
| 9 | | | | | |
| 10 | | | | | |

**Hasil regresi:** a (gain) = _______  b (offset) = _______
**Error rata-rata seluruh titik:** _______ %  (target: <2%)

> Template siap-isi dalam format Excel (dengan rumus regresi otomatis) tersedia terpisah di `Template_Kalibrasi_ZMPT101B.xlsx`.

---

## 5. Catatan untuk BAB 4

- Dokumentasikan **kedua** modul (sumber dan beban) sebagai dua proses kalibrasi terpisah dengan koefisien masing-masing — jangan mengasumsikan keduanya identik.
- Jika error di beberapa titik konsisten lebih besar pada rentang tegangan tertentu (misal selalu lebih besar di ujung bawah/atas rentang uji), catat sebagai keterbatasan linearitas sensor pada laporan, bukan dianggap kesalahan pengukuran.
- Simpan seluruh data mentah (bukan hanya koefisien akhir) sebagai lampiran BAB 4 — ini mendukung keterulangan (*reproducibility*) hasil kalibrasi jika sewaktu-waktu perlu diverifikasi ulang oleh penguji.
