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

#ifndef BATAS_NOISE_ARUS_A
#define BATAS_NOISE_ARUS_A 3.0f
#endif

#ifndef BATAS_TEGANGAN_OFF
#define BATAS_TEGANGAN_OFF 20.0f
#endif

static const int PIN_MAP[JUMLAH_SENSOR] = {
  0, // ZMPT sumber -> A0
  1, // ZMPT beban  -> A1
  2, // ACS712 sumber -> A2
  3  // ACS712 beban  -> A3
};

void sensorsInit() {
  Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL);
  Wire.setClock(400000);
  ads.setGain(GAIN_ONE);
  ads.setDataRate(RATE_ADS1115_860SPS);

  if (!ads.begin(ADS1115_I2C_ADDR)) {
    Serial.println("[FATAL] ADS1115 tidak terdeteksi - cek wiring I2C.");
    while (true) { delay(1000); }
  }
}

int readRawSensor(SensorId id) {
  return (int)ads.readADC_SingleEnded(PIN_MAP[id]);
}

/*
 * RMS AC yang benar:
 *
 * 1. Ambil N sampel.
 * 2. Hitung rata-rata (DC bias) dari batch tersebut.
 * 3. Kurangi setiap sampel dengan rata-rata.
 * 4. Hitung RMS dari komponen AC.
 *
 * Dengan cara ini kita tidak lagi mengasumsikan zero point = ADC/2.
 * Ini penting karena pengukuran aktual Anda menunjukkan:
 *   ZMPT tanpa AC  ~= 1.5 V
 *   ACS712 0 A    ~= 0.9 V
 *
 * Estimasi offset per batch juga lebih baik daripada hard-code karena
 * offset sensor dapat berubah akibat suhu dan tegangan suplai.
 */
static float hitungRMSDenganDc(SensorId id, float* rataRataDc) {
    float sampel[JUMLAH_SAMPEL_RMS];
    double jumlah = 0.0;

    // Ambil seluruh sampel dan hitung rata-rata DC/bias.
    for (int i = 0; i < JUMLAH_SAMPEL_RMS; i++) {
        sampel[i] = (float)readRawSensor(id);
        jumlah += sampel[i];
    }

    const float rata_rata = (float)(jumlah / JUMLAH_SAMPEL_RMS);
    if (rataRataDc != nullptr) {
      *rataRataDc = rata_rata;
    }

    // Hilangkan komponen DC/bias, kemudian hitung RMS komponen AC.
    double jumlah_kuadrat_ac = 0.0;

    for (int i = 0; i < JUMLAH_SAMPEL_RMS; i++) {
        const float ac = sampel[i] - rata_rata;
        jumlah_kuadrat_ac += (double)ac * (double)ac;
    }

    return sqrt(jumlah_kuadrat_ac / JUMLAH_SAMPEL_RMS);
}

float hitungRMS(SensorId id) {
    return hitungRMSDenganDc(id, nullptr);
}

#define RMS_ADC_MIN_WAJAR (ADC_MAX_VALUE * 0.0001f)
#define RMS_ADC_MAX_WAJAR (ADC_MAX_VALUE * 0.98f)

static bool nilaiWajar(float rms_adc_mentah) {
  return (rms_adc_mentah >= RMS_ADC_MIN_WAJAR) &&
         (rms_adc_mentah <= RMS_ADC_MAX_WAJAR);
}

#ifdef MODE_UJI_SENSOR_DC_SUMBER
static float bacaRataRataSensorDCSumber() {
  const int jumlah_sampel_dc = 10;
  long total_sampel = 0;

  for (int i = 0; i < jumlah_sampel_dc; i++) {
    total_sampel += readRawSensor(SENSOR_ZMPT_SUMBER);
  }

  return (float)total_sampel / jumlah_sampel_dc;
}
#endif

// Filter tegangan untuk mengurangi fluktuasi antar-batch RMS.
// Alpha kecil = lebih stabil tetapi respons perubahan tegangan lebih lambat.
static float filterTegangan(float nilaiBaru, float &nilaiFilter, bool &sudahAdaData) {
  const float ALPHA = 0.20f;

  // Jangan biarkan sisa nilai tegangan AC tetap turun perlahan setelah sumber
  // diputus. Kondisi tanpa AC harus dipublikasikan sebagai tepat 0 V.
  if (nilaiBaru <= 0.0f) {
    nilaiFilter = 0.0f;
    sudahAdaData = true;
    return 0.0f;
  }

  if (!sudahAdaData) {
    nilaiFilter = nilaiBaru;
    sudahAdaData = true;
    return nilaiFilter;
  }

  nilaiFilter = (ALPHA * nilaiBaru) +
                ((1.0f - ALPHA) * nilaiFilter);

  return nilaiFilter;
}

HasilSensor bacaSemuaSensor() {
  HasilSensor hasil;
  hasil.bitmask_kualitas = 0;

  static float tegangan_sumber_filter = 0.0f;
  static float tegangan_beban_filter = 0.0f;
  static bool sumber_sudah_ada_data = false;
  static bool beban_sudah_ada_data = false;

  float adc_dc_sumber = 0.0f;
  float rms_zmpt_sumber = 0.0f;
  float dc_zmpt_sumber = 0.0f;
  float dc_zmpt_beban = 0.0f;
  float dc_acs_sumber = 0.0f;
  float dc_acs_beban = 0.0f;
#ifdef MODE_DEBUG_SENSOR
  rms_zmpt_sumber = hitungRMSDenganDc(SENSOR_ZMPT_SUMBER, &dc_zmpt_sumber);
  float rms_zmpt_beban = hitungRMSDenganDc(SENSOR_ZMPT_BEBAN, &dc_zmpt_beban);
  float rms_acs_sumber = hitungRMSDenganDc(SENSOR_ACS712_SUMBER, &dc_acs_sumber);
  float rms_acs_beban  = hitungRMSDenganDc(SENSOR_ACS712_BEBAN, &dc_acs_beban);
#else
  #ifdef MODE_UJI_SENSOR_DC_SUMBER
  adc_dc_sumber = bacaRataRataSensorDCSumber();
  #else
  rms_zmpt_sumber = hitungRMS(SENSOR_ZMPT_SUMBER);
  #endif
  float rms_zmpt_beban = hitungRMS(SENSOR_ZMPT_BEBAN);
  float rms_acs_sumber = hitungRMS(SENSOR_ACS712_SUMBER);
  float rms_acs_beban  = hitungRMS(SENSOR_ACS712_BEBAN);
#endif

#ifndef MODE_UJI_SENSOR_DC_SUMBER
  if (!nilaiWajar(rms_zmpt_sumber)) hasil.bitmask_kualitas |= (1 << 0);
#endif
  if (!nilaiWajar(rms_zmpt_beban))  hasil.bitmask_kualitas |= (1 << 1);
  if (!nilaiWajar(rms_acs_sumber))  hasil.bitmask_kualitas |= (1 << 2);
  if (!nilaiWajar(rms_acs_beban))   hasil.bitmask_kualitas |= (1 << 3);

#ifdef MODE_UJI_SENSOR_DC_SUMBER
  hasil.tegangan_sumber =
      (adc_dc_sumber / ADC_MAX_VALUE) * 4.096f * RASIO_PEMBAGI_SENSOR_DC;
#else
  float tegangan_sumber_baru =
    ZMPT_SUMBER_GAIN * rms_zmpt_sumber + ZMPT_SUMBER_OFFSET;

  float tegangan_beban_baru =
    ZMPT_BEBAN_GAIN * rms_zmpt_beban + ZMPT_BEBAN_OFFSET;

  // Deadband untuk menghilangkan residual/noise saat tidak ada AC.
  if (tegangan_sumber_baru <= BATAS_TEGANGAN_OFF) {
    tegangan_sumber_baru = 0.0f;
  }

  if (tegangan_beban_baru <= BATAS_TEGANGAN_OFF) {
    tegangan_beban_baru = 0.0f;
  }

  // Filtering untuk menstabilkan pembacaan tegangan.
  hasil.tegangan_sumber =
      filterTegangan(
          tegangan_sumber_baru,
          tegangan_sumber_filter,
          sumber_sudah_ada_data
      );

  hasil.tegangan_beban =
      filterTegangan(
          tegangan_beban_baru,
          tegangan_beban_filter,
          beban_sudah_ada_data
      );
#endif

  // ACS712: konversi RMS-ADC -> mV -> Ampere memakai sensitivitas datasheet.
  // ACS712_MV_PER_AMP = 100.0 (varian 20A @5V) x (Vcc_terukur/5) x
  // rasio_pembagi_bila_ada. Modul ACS712 bersifat ratiometric: titik nol =
  // Vcc/2 dan sensitivitas proporsional terhadap Vcc; rentang suplai
  // terjamin 4,5-5,5 V. Jangan ubah konstanta sebelum Vcc dan tegangan OUT
  // saat 0 A diukur.
  // Referensi 4096 mV mengikuti rentang penuh
  // ADS1115 pada pengaturan GAIN_ONE (+/-4,096V, lihat sensorsInit()) —
  // BUKAN 3,3V seperti asumsi ADC bawaan ESP32 sebelumnya. Bila suatu saat
  // setGain() diubah ke pengaturan lain, angka 4096.0f ini WAJIB
  // disesuaikan mengikuti rentang penuh gain yang baru, atau meleset.
  // TITIK INI JUGA PERLU DIVERIFIKASI ULANG bila memakai kalibrasi regresi
  // seperti ZMPT101B untuk akurasi lebih baik (opsional, di luar cakupan
  // Panduan Kalibrasi ZMPT101B yang sudah dibuat).
  const float referensi_mv = 4096.0f;
  float mv_per_langkah = referensi_mv / ADC_MAX_VALUE;
  float arus_sumber = (rms_acs_sumber * mv_per_langkah) / ACS712_MV_PER_AMP;
  float arus_beban  = (rms_acs_beban  * mv_per_langkah) / ACS712_MV_PER_AMP;

  hasil.arus_sumber = (arus_sumber <= BATAS_NOISE_ARUS_A) ? 0.0f : arus_sumber;
  hasil.arus_beban  = (arus_beban  <= BATAS_NOISE_ARUS_A) ? 0.0f : arus_beban;

#ifdef MODE_DEBUG_SENSOR
  static unsigned int jumlahSiklusDebug = 0;
  if (++jumlahSiklusDebug % 2 == 0) {
    const float adcKeVolt = 4.096f / ADC_MAX_VALUE;
    const float adcKeMv = 4096.0f / ADC_MAX_VALUE;
    Serial.printf("[SENSOR] ZMPT_sumber dc=%.3fV rms=%.1fmV -> %.2fV\n",
                  dc_zmpt_sumber * adcKeVolt, rms_zmpt_sumber * adcKeMv,
                  hasil.tegangan_sumber);
    Serial.printf("[SENSOR] ZMPT_beban dc=%.3fV rms=%.1fmV -> %.2fV\n",
                  dc_zmpt_beban * adcKeVolt, rms_zmpt_beban * adcKeMv,
                  hasil.tegangan_beban);
    Serial.printf("[SENSOR] ACS_sumber dc=%.3fV rms=%.1fmV -> %.2fA\n",
                  dc_acs_sumber * adcKeVolt, rms_acs_sumber * adcKeMv,
                  hasil.arus_sumber);
    Serial.printf("[SENSOR] ACS_beban dc=%.3fV rms=%.1fmV -> %.2fA\n",
                  dc_acs_beban * adcKeVolt, rms_acs_beban * adcKeMv,
                  hasil.arus_beban);
  }
#endif

  return hasil;
}
