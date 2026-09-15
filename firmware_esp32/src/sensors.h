/**
 * sensors.h — Modul pembacaan sensor & perhitungan RMS
 * Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)
 *
 * CATATAN DESAIN UNTUK MIGRASI ESP32-S3 + ADS1115 (iterasi berikutnya):
 * Seluruh akses ke ADC bawaan ESP32 dibungkus dalam satu fungsi
 * readRawSensor(id) di sensors.cpp. Saat pindah ke ADS1115 (ADC eksternal
 * 16-bit via I2C), HANYA fungsi ini dan bagian inisialisasi ADC di setup()
 * yang perlu diganti — seluruh logika RMS, kalibrasi, Modbus, dan MQTT di
 * modul lain tidak perlu disentuh, karena semuanya memanggil hitungRMS()
 * dan bacaSemuaSensor() di bawah ini, bukan analogRead() secara langsung.
 */

#ifndef SENSORS_H
#define SENSORS_H

#include <Arduino.h>

// Identitas kanal sensor — dipakai sebagai parameter id pada readRawSensor()
enum SensorId {
  SENSOR_ZMPT_SUMBER = 0,
  SENSOR_ZMPT_BEBAN  = 1,
  SENSOR_ACS712_SUMBER = 2,
  SENSOR_ACS712_BEBAN  = 3,
  JUMLAH_SENSOR = 4
};

// Hasil pembacaan satu siklus RMS untuk seluruh 4 kanal, sudah dikonversi
// ke satuan fisik (Volt / Ampere) memakai koefisien kalibrasi di config.h,
// beserta bit kualitas data (GOOD/SUSPECT) per kanal.
struct HasilSensor {
  float tegangan_sumber;   // Volt
  float tegangan_beban;    // Volt
  float arus_sumber;       // Ampere
  float arus_beban;        // Ampere
  uint8_t bitmask_kualitas; // bit0..3 sesuai REG_KUALITAS_DATA pada config.h
};

/**
 * Inisialisasi bus I2C dan ADS1115 yang dipakai sensor. Panggil sekali di
 * setup().
 */
void sensorsInit();

/**
 * Membaca SATU sampel mentah dari kanal sensor `id` (lihat SensorId).
 * Mengembalikan nilai ADC mentah efektif 0..32767 dari ADS1115 16-bit — kode
 * pemanggil TIDAK BOLEH mengasumsikan rentang nilai tertentu, gunakan
 * konstanta ADC_MAX_VALUE di bawah.
 *
 * Seluruh modul lain memakai fungsi ini, bukan membaca ADC secara langsung.
 */
int readRawSensor(SensorId id);

// Rentang nilai ADC mentah — dipakai modul lain untuk normalisasi.
// ADS1115 single-ended: rentang efektif 0-32767 pada pembacaan 16-bit.
#define ADC_MAX_VALUE 32767

/**
 * Menghitung RMS dari N sampel (JUMLAH_SAMPEL_RMS pada config.h) untuk satu
 * kanal sensor, dengan jarak antar-sampel INTERVAL_ADC_US. Mengembalikan
 * nilai RMS dalam satuan ADC mentah (belum dikonversi ke Volt/Ampere).
 */
float hitungRMS(SensorId id);

/**
 * Menjalankan satu siklus penuh: baca RMS keempat kanal, terapkan
 * kalibrasi (config.h), evaluasi kualitas data (GOOD/SUSPECT berbasis
 * ambang batas rentang wajar), dan kembalikan hasil terstruktur.
 * Dipanggil dari task ADC+Modbus (Core 1) setiap TARGET_SIKLUS_MS.
 */
HasilSensor bacaSemuaSensor();

#endif // SENSORS_H
