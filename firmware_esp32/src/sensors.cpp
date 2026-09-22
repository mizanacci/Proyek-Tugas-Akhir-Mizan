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

static const int PIN_MAP[JUMLAH_SENSOR] = {
  0, // ZMPT sumber -> A0
  1, // ZMPT beban  -> A1
  2, // ACS712 sumber -> A2
  3  // ACS712 beban  -> A3
};

void sensorsInit() {
  Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL);
  ads.setGain(GAIN_ONE);  // +/-4.096V, sesuai sinyal analog sensor
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
 * Hitung RMS sinyal AC setelah menghilangkan DC bias sensor.
 *
 * PENTING:
 * Sebelumnya semua sensor diasumsikan memiliki titik tengah ADC = 16383.5.
 * Itu tidak benar untuk hardware ini.
 *
 * Hasil pengukuran tanpa sinyal:
 *   ZMPT101B = 1.5 V
 *   ACS712   = 0.9 V
 *
 * Karena itu setiap kanal memakai zero-offset aktual dari config.h.
 */
static float hitungRMSDenganOffset(SensorId id, float offset_mv) {
  const float mv_per_count = 4096.0f / 32768.0f;
  const float offset_count = offset_mv / mv_per_count;

  double akumulasi_kuadrat = 0.0;

  for (int i = 0; i < JUMLAH_SAMPEL_RMS; i++) {
    int mentah = readRawSensor(id);
    float selisih = (float)mentah - offset_count;
    akumulasi_kuadrat += (double)selisih * (double)selisih;
  }

  return sqrt(akumulasi_kuadrat / JUMLAH_SAMPEL_RMS);
}

float hitungRMS(SensorId id) {
  float offset_mv = 0.0f;

  switch (id) {
    case SENSOR_ZMPT_SUMBER:
      offset_mv = ZMPT_SUMBER_ZERO_OFFSET_MV;
      break;

    case SENSOR_ZMPT_BEBAN:
      offset_mv = ZMPT_BEBAN_ZERO_OFFSET_MV;
      break;

    case SENSOR_ACS712_SUMBER:
    case SENSOR_ACS712_BEBAN:
      offset_mv = ACS712_ZERO_OFFSET_MV;
      break;
  }

  return hitungRMSDenganOffset(id, offset_mv);
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

HasilSensor bacaSemuaSensor() {
  HasilSensor hasil;
  hasil.bitmask_kualitas = 0;

#ifdef MODE_UJI_SENSOR_DC_SUMBER
  float adc_dc_sumber = bacaRataRataSensorDCSumber();
#else
  float rms_zmpt_sumber = hitungRMS(SENSOR_ZMPT_SUMBER);
#endif

  float rms_zmpt_beban = hitungRMS(SENSOR_ZMPT_BEBAN);
  float rms_acs_sumber = hitungRMS(SENSOR_ACS712_SUMBER);
  float rms_acs_beban  = hitungRMS(SENSOR_ACS712_BEBAN);

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
  hasil.tegangan_sumber =
      ZMPT_SUMBER_GAIN * rms_zmpt_sumber + ZMPT_SUMBER_OFFSET;
#endif

  hasil.tegangan_beban =
      ZMPT_BEBAN_GAIN * rms_zmpt_beban + ZMPT_BEBAN_OFFSET;

  /*
   * ACS712-20A:
   * sensitivitas nominal = 100 mV/A.
   *
   * RMS dihitung setelah DC offset 0 A dihilangkan, sehingga pada kondisi
   * tanpa beban arus idealnya mendekati 0 A.
   */
  const float referensi_mv = 4096.0f;
  const float mv_per_langkah = referensi_mv / ADC_MAX_VALUE;

  hasil.arus_sumber =
      (rms_acs_sumber * mv_per_langkah) / ACS712_MV_PER_AMP;

  hasil.arus_beban =
      (rms_acs_beban * mv_per_langkah) / ACS712_MV_PER_AMP;

  return hasil;
}
