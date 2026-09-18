/**
 * sensors.cpp — Implementasi pembacaan sensor & perhitungan RMS
 * Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)
 */

#include "sensors.h"
#include "config.h"
#include <Wire.h>
#include <Adafruit_ADS1X15.h>
#include <math.h>

static Adafruit_ADS1115 ads;

// Pemetaan SensorId -> kanal ADS1115 A0-A3 sesuai wiring fisik.
static const int PIN_MAP[JUMLAH_SENSOR] = {
  0, // ZMPT sumber -> A0
  1, // ZMPT beban  -> A1
  2, // ACS712 sumber -> A2
  3  // ACS712 beban  -> A3
};

void sensorsInit() {
  Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL);
  ads.setGain(GAIN_ONE);  // rentang +/-4.096V, sesuai untuk sinyal sensor 0-3.3V
  ads.setDataRate(RATE_ADS1115_860SPS);
  if (!ads.begin(ADS1115_I2C_ADDR)) {
    Serial.println("[FATAL] ADS1115 tidak terdeteksi - cek wiring I2C.");
    while (true) { delay(1000); }
  }
}

int readRawSensor(SensorId id) {
  return (int)ads.readADC_SingleEnded(PIN_MAP[id]);
}

float hitungRMS(SensorId id) {
  // Perhitungan RMS: akumulasi kuadrat dari N sampel berturut-turut,
  // dengan sinyal AC diasumsikan berosilasi di sekitar titik tengah ADC
  // (ADC_MAX_VALUE/2) — asumsi ini berlaku untuk sensor yang sudah
  // dikondisikan sinyalnya (ZMPT101B dan ACS712 keduanya mengeluarkan
  // sinyal AC yang di-bias ke titik tengah oleh rangkaian on-board modul).
  const float titik_tengah = ADC_MAX_VALUE / 2.0f;
  double akumulasi_kuadrat = 0.0;

  for (int i = 0; i < JUMLAH_SAMPEL_RMS; i++) {
    int mentah = readRawSensor(id);
    float selisih = (float)mentah - titik_tengah;
    akumulasi_kuadrat += (double)(selisih * selisih);
    // Catatan: TIDAK ada delayMicroseconds(INTERVAL_ADC_US) di sini lagi.
    // ads.readADC_SingleEnded() di dalam readRawSensor() SUDAH menunggu
    // (blocking) sampai konversi ADS1115 selesai sesuai data rate yang
    // diset di sensorsInit() (860 SPS -> ~1,16 ms/konversi) — delay
    // tambahan di sini dulu redundan dan nyaris menggandakan waktu per
    // sampel (dulu diperlukan untuk ADC bawaan ESP32 yang hampir instan,
    // TIDAK berlaku lagi untuk ADS1115). INTERVAL_ADC_US di config.h tetap
    // dipertahankan untuk kemungkinan kembali ke ADC bawaan di masa depan.
  }

  return sqrt(akumulasi_kuadrat / JUMLAH_SAMPEL_RMS);
}

// Ambang batas kewajaran (plausibility) untuk penandaan kualitas data
// GOOD/SUSPECT — [DRAF, nilai perlu disesuaikan setelah kalibrasi fisik
// dan pengamatan rentang normal operasi prototipe]. Nilai RMS ADC mentah
// yang berada jauh di luar rentang ini (mendekati batas ADC, atau nol
// total) dianggap tidak wajar/kemungkinan sensor lepas atau jenuh.
#define RMS_ADC_MIN_WAJAR   (ADC_MAX_VALUE * 0.0012f)  // setara ~5 dari skala lama 4095 (proporsional, bukan hardcode absolut)
#define RMS_ADC_MAX_WAJAR   (ADC_MAX_VALUE / 2.0f * 0.98f)  // 98% dari setengah rentang, margin dari saturasi

static bool nilaiWajar(float rms_adc_mentah) {
  return (rms_adc_mentah >= RMS_ADC_MIN_WAJAR) && (rms_adc_mentah <= RMS_ADC_MAX_WAJAR);
}

#ifdef MODE_UJI_SENSOR_DC_SUMBER
static float bacaRataRataSensorDCSumber() {
  const int jumlah_sampel_dc = 10;
  long total_sampel = 0;

  for (int i = 0; i < jumlah_sampel_dc; i++) {
    total_sampel += readRawSensor(SENSOR_ZMPT_SUMBER);
    // Lihat catatan di hitungRMS() — delay eksplisit dihapus, konversi
    // ADS1115 sendiri sudah memberi jeda yang cukup antar-sampel.
  }

  return (float)total_sampel / jumlah_sampel_dc;
}
#endif

HasilSensor bacaSemuaSensor() {
  HasilSensor hasil;
  hasil.bitmask_kualitas = 0;

#ifdef MODE_UJI_SENSOR_DC_SUMBER
  // Sensor DC menghasilkan level stabil, jadi gunakan rata-rata ADC, bukan RMS.
  float adc_dc_sumber = bacaRataRataSensorDCSumber();
#else
  float rms_zmpt_sumber = hitungRMS(SENSOR_ZMPT_SUMBER);
#endif
  float rms_zmpt_beban  = hitungRMS(SENSOR_ZMPT_BEBAN);
  float rms_acs_sumber  = hitungRMS(SENSOR_ACS712_SUMBER);
  float rms_acs_beban   = hitungRMS(SENSOR_ACS712_BEBAN);

  // Evaluasi kualitas data SEBELUM konversi ke satuan fisik, karena ambang
  // batas kewajaran didefinisikan dalam domain ADC mentah.
#ifndef MODE_UJI_SENSOR_DC_SUMBER
  if (!nilaiWajar(rms_zmpt_sumber)) hasil.bitmask_kualitas |= (1 << 0);
#endif
  if (!nilaiWajar(rms_zmpt_beban))  hasil.bitmask_kualitas |= (1 << 1);
  if (!nilaiWajar(rms_acs_sumber))  hasil.bitmask_kualitas |= (1 << 2);
  if (!nilaiWajar(rms_acs_beban))   hasil.bitmask_kualitas |= (1 << 3);

  // Konversi ke satuan fisik memakai koefisien kalibrasi (config.h).
  // ZMPT101B: hubungan linear langsung dari hasil regresi kalibrasi.
#ifdef MODE_UJI_SENSOR_DC_SUMBER
  // Pengecualian kualitas bit0 sementara; ambang RMS tidak berlaku untuk DC.
  // Catatan: referensi 4,096V (bukan 3,3V) mengikuti rentang penuh ADS1115
  // pada GAIN_ONE — lihat penjelasan lengkap di konversi ACS712 di bawah.
  hasil.tegangan_sumber = (adc_dc_sumber / ADC_MAX_VALUE) * 4.096f * RASIO_PEMBAGI_SENSOR_DC;
#else
  hasil.tegangan_sumber = ZMPT_SUMBER_GAIN * rms_zmpt_sumber + ZMPT_SUMBER_OFFSET;
#endif
  hasil.tegangan_beban  = ZMPT_BEBAN_GAIN  * rms_zmpt_beban  + ZMPT_BEBAN_OFFSET;

  // ACS712: konversi RMS-ADC -> mV -> Ampere memakai sensitivitas datasheet
  // (185 mV/A untuk varian 5A). Referensi 4096 mV mengikuti rentang penuh
  // ADS1115 pada pengaturan GAIN_ONE (+/-4,096V, lihat sensorsInit()) —
  // BUKAN 3,3V seperti asumsi ADC bawaan ESP32 sebelumnya. Bila suatu saat
  // setGain() diubah ke pengaturan lain, angka 4096.0f ini WAJIB
  // disesuaikan mengikuti rentang penuh gain yang baru, atau meleset.
  // TITIK INI JUGA PERLU DIVERIFIKASI ULANG bila memakai kalibrasi regresi
  // seperti ZMPT101B untuk akurasi lebih baik (opsional, di luar cakupan
  // Panduan Kalibrasi ZMPT101B yang sudah dibuat).
  const float referensi_mv = 4096.0f;
  float mv_per_langkah = referensi_mv / ADC_MAX_VALUE;
  hasil.arus_sumber = (rms_acs_sumber * mv_per_langkah) / ACS712_MV_PER_AMP;
  hasil.arus_beban  = (rms_acs_beban  * mv_per_langkah) / ACS712_MV_PER_AMP;

  return hasil;
}
