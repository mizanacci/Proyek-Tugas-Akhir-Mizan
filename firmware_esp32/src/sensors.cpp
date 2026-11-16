/**
 * sensors.cpp - Four-channel internal ADC acquisition for ESP32-S3.
 * GPIO4/5: ZMPT101B source/load; GPIO6/7: ACS712 source/load.
 * RMS is calculated after removing the DC bias of each sampling window.
 */
#include "sensors.h"
#include "config.h"
#include <math.h>
#include <stdint.h>
#include <limits.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

namespace {

const uint8_t PIN_MAP[JUMLAH_SENSOR] = {
  PIN_ADC_ZMPT_SUMBER,
  PIN_ADC_ZMPT_BEBAN,
  PIN_ADC_ACS_SUMBER,
  PIN_ADC_ACS_BEBAN
};

const float BASELINE_MAP_MV[JUMLAH_SENSOR] = {
  ZMPT_SUMBER_BASELINE_MV,
  ZMPT_BEBAN_BASELINE_MV,
  ACS712_SUMBER_BASELINE_MV,
  ACS712_BEBAN_BASELINE_MV
};

const char* const SENSOR_NAMES[JUMLAH_SENSOR] = {
  "ZMPT_SUMBER", "ZMPT_BEBAN", "ACS_SUMBER", "ACS_BEBAN"
};

struct RmsWindow {
  float meanMv = 0.0f;
  float rmsAcMv = 0.0f;
  float fundamentalRmsMv = 0.0f;
  float sampleRateHz = 0.0f;
  uint16_t minMv = UINT16_MAX;
  uint16_t maxMv = 0;
  bool rangeValid = false;
  bool baselineValid = false;
};

bool adcInitialized = false;

float idleFundamentalNoiseRmsMv[2] = {0.0f, 0.0f};
bool idleNoiseCalibrationValid[2] = {false, false};

struct VoltageStatusTracker {
  uint32_t outsideSinceMs = 0;
  bool timing = false;
};

VoltageStatusTracker warningSource;
VoltageStatusTracker warningLoad;

bool idValid(SensorId id) {
  return static_cast<uint8_t>(id) < JUMLAH_SENSOR;
}

bool coefficientValid(float coefficient) {
  return isfinite(coefficient) && coefficient > 0.0f;
}

float fundamentalRms50Hz(const uint16_t* samples,
                         uint16_t count,
                         float meanMv,
                         float sampleRateHz) {
  if (samples == nullptr || count < 8 ||
      !isfinite(sampleRateHz) || sampleRateHz <= (ACS712_FUNDAMENTAL_HZ * 2.0f)) {
    return 0.0f;
  }

  constexpr float kPi = 3.14159265358979323846f;
  const float omega = 2.0f * kPi * ACS712_FUNDAMENTAL_HZ / sampleRateHz;
  const float coeff = 2.0f * cosf(omega);
  const float windowStep = 2.0f * kPi / static_cast<float>(count - 1U);
  const float windowSum = 0.5f * static_cast<float>(count - 1U);

  float s1 = 0.0f;
  float s2 = 0.0f;
  for (uint16_t n = 0; n < count; ++n) {
    const float hann = 0.5f * (1.0f - cosf(windowStep * static_cast<float>(n)));
    const float x = (static_cast<float>(samples[n]) - meanMv) * hann;
    const float s0 = x + coeff * s1 - s2;
    s2 = s1;
    s1 = s0;
  }

  float magnitudeSquared = (s1 * s1) + (s2 * s2) - (coeff * s1 * s2);
  if (magnitudeSquared < 0.0f) magnitudeSquared = 0.0f;
  const float magnitude = sqrtf(magnitudeSquared);
  return (sqrtf(2.0f) * magnitude) / windowSum;
}

RmsWindow readWindow(SensorId id) {
  RmsWindow result;
  if (!adcInitialized || !idValid(id)) return result;

  uint16_t samples[JUMLAH_SAMPEL_RMS];
  double sum = 0.0;
  const uint8_t pin = PIN_MAP[static_cast<uint8_t>(id)];

  (void)analogReadMilliVolts(pin);
  delayMicroseconds(50);

  uint32_t firstSampleUs = 0;
  uint32_t lastSampleUs = 0;
  for (uint16_t i = 0; i < JUMLAH_SAMPEL_RMS; ++i) {
    const uint32_t sampleTimeUs = micros();
    if (i == 0U) firstSampleUs = sampleTimeUs;
    lastSampleUs = sampleTimeUs;

    const uint32_t measured = analogReadMilliVolts(pin);
    const uint16_t sample = static_cast<uint16_t>(
        measured > UINT16_MAX ? UINT16_MAX : measured);
    samples[i] = sample;

    if (sample < result.minMv) result.minMv = sample;
    if (sample > result.maxMv) result.maxMv = sample;
    sum += static_cast<double>(sample);

    if (i + 1U < JUMLAH_SAMPEL_RMS) {
      delayMicroseconds(INTERVAL_ADC_US);
      if ((i & 0x0FU) == 0x0FU) taskYIELD();
    }
  }

  result.meanMv = static_cast<float>(sum / JUMLAH_SAMPEL_RMS);
  double sumSquares = 0.0;
  for (uint16_t i = 0; i < JUMLAH_SAMPEL_RMS; ++i) {
    const double ac = static_cast<double>(samples[i]) - result.meanMv;
    sumSquares += ac * ac;
  }
  result.rmsAcMv = static_cast<float>(sqrt(sumSquares / JUMLAH_SAMPEL_RMS));

  const uint32_t elapsedUs = lastSampleUs - firstSampleUs;
  result.sampleRateHz = elapsedUs > 0U
      ? (static_cast<float>(JUMLAH_SAMPEL_RMS - 1U) * 1000000.0f /
         static_cast<float>(elapsedUs))
      : 0.0f;
  if (id == SENSOR_ACS712_SUMBER || id == SENSOR_ACS712_BEBAN) {
    result.fundamentalRmsMv = fundamentalRms50Hz(
        samples, JUMLAH_SAMPEL_RMS, result.meanMv, result.sampleRateHz);
  }

  result.rangeValid =
      result.minMv >= SENSOR_ADC_MIN_VALID_MV &&
      result.maxMv <= SENSOR_ADC_MAX_VALID_MV;
  result.baselineValid =
      fabsf(result.meanMv - BASELINE_MAP_MV[static_cast<uint8_t>(id)]) <=
      SENSOR_BASELINE_TOLERANCE_MV;
  return result;
}

float voltageFromSensorRms(float rmsSensorMv, float voltsPerMv) {
  if (!coefficientValid(voltsPerMv) || !isfinite(rmsSensorMv) ||
      rmsSensorMv <= SENSOR_ZERO_RMS_THRESHOLD_MV) {
    return 0.0f;
  }

  const float voltage = rmsSensorMv * voltsPerMv;
  if (!isfinite(voltage) || voltage <= BATAS_TEGANGAN_OFF) return 0.0f;
  return voltage;
}

float noiseCorrectedFundamentalRms(float measuredRmsMv, float idleNoiseRmsMv) {
  if (!isfinite(measuredRmsMv) || !isfinite(idleNoiseRmsMv) ||
      measuredRmsMv <= 0.0f || idleNoiseRmsMv < 0.0f) {
    return 0.0f;
  }
  const float netPower = (measuredRmsMv * measuredRmsMv) -
                         (idleNoiseRmsMv * idleNoiseRmsMv);
  return netPower > 0.0f ? sqrtf(netPower) : 0.0f;
}
float currentFromSensorRms(float rmsSensorMv, float ampsPerMv) {
  if (!coefficientValid(ampsPerMv) || !isfinite(rmsSensorMv) ||
      rmsSensorMv <= SENSOR_ZERO_RMS_THRESHOLD_MV) {
    return 0.0f;
  }

  const float current = rmsSensorMv * ampsPerMv;
  if (!isfinite(current) || current < 0.0f) return 0.0f;
  return current;
}

uint8_t voltageStatus(float voltage, VoltageStatusTracker& tracker) {
  const uint32_t now = millis();

  if (!isfinite(voltage) || voltage <= BATAS_TEGANGAN_OFF) {
    tracker.timing = false;
    tracker.outsideSinceMs = 0;
    return STATUS_V_AC_OFF;
  }

  // User-defined normal operating range: inclusive 200..230 VAC.
  if (voltage >= 200.0f && voltage <= 230.0f) {
    tracker.timing = false;
    tracker.outsideSinceMs = 0;
    return STATUS_V_NORMAL;
  }

  // Outside the configured range: suspect immediately, warning after 15 s.
  if (!tracker.timing) {
    tracker.timing = true;
    tracker.outsideSinceMs = now;
    return STATUS_V_SUSPECT;
  }

  if (static_cast<uint32_t>(now - tracker.outsideSinceMs) >= 15000UL) {
    return STATUS_V_WARNING;
  }

  return STATUS_V_SUSPECT;
}

void calibrateAcsIdleNoise() {
  const SensorId channels[2] = {SENSOR_ACS712_SUMBER, SENSOR_ACS712_BEBAN};
  const char* labels[2] = {"ACS_SUMBER", "ACS_BEBAN"};

  Serial.println("[ACS-ZERO] Boot noise calibration: BOTH primary paths must carry ZERO current.");
  for (uint8_t channel = 0; channel < 2U; ++channel) {
    long double noisePowerSum = 0.0L;
    bool valid = true;

    for (uint8_t frame = 0; frame < ACS712_IDLE_CALIBRATION_FRAMES; ++frame) {
      const RmsWindow sample = readWindow(channels[channel]);
      noisePowerSum += static_cast<long double>(sample.fundamentalRmsMv) *
                       static_cast<long double>(sample.fundamentalRmsMv);

      if (!sample.rangeValid || !sample.baselineValid ||
          !isfinite(sample.fundamentalRmsMv) ||
          sample.fundamentalRmsMv > ACS712_BOOT_IDLE_MAX_FUNDAMENTAL_MV) {
        valid = false;
      }
    }

    const float noiseRms = sqrtf(static_cast<float>(
        noisePowerSum / static_cast<long double>(ACS712_IDLE_CALIBRATION_FRAMES)));
    idleFundamentalNoiseRmsMv[channel] = noiseRms;
    idleNoiseCalibrationValid[channel] = valid && isfinite(noiseRms);

    Serial.printf("[ACS-ZERO] %s idle50=%.3f mV maxBoot=%.1f mV calibration=%s\n",
                  labels[channel], noiseRms,
                  ACS712_BOOT_IDLE_MAX_FUNDAMENTAL_MV,
                  idleNoiseCalibrationValid[channel] ? "VALID" : "INVALID");
  }
}
} // namespace

bool sensorsInit() {
  adcInitialized = false;
  analogReadResolution(12);

  for (uint8_t i = 0; i < JUMLAH_SENSOR; ++i) {
    pinMode(PIN_MAP[i], INPUT);
    analogSetPinAttenuation(PIN_MAP[i], ADC_11db);
  }

  delay(30);
  Serial.println("[ADC] ESP32-S3 internal ADC1 initialized; ADS1115/I2C disabled.");
  Serial.printf("[ADC] 12-bit, ADC_11db, samples=%u, interval=%u us\n",
                static_cast<unsigned>(JUMLAH_SAMPEL_RMS),
                static_cast<unsigned>(INTERVAL_ADC_US));
  Serial.printf("[ADC] Pins: ZMPT source=GPIO%u, ZMPT load=GPIO%u, ACS source=GPIO%u, ACS load=GPIO%u\n",
                PIN_MAP[0], PIN_MAP[1], PIN_MAP[2], PIN_MAP[3]);

  adcInitialized = true;

  for (uint8_t channel = 0; channel < JUMLAH_SENSOR; ++channel) {
    uint32_t total = 0;
    for (uint8_t i = 0; i < 16; ++i) {
      total += analogReadMilliVolts(PIN_MAP[channel]);
      delayMicroseconds(200);
    }
    const float startupMean = static_cast<float>(total) / 16.0f;
    Serial.printf("[ADC-BOOT] %s GPIO%u mean=%.1f mV expected=%.1f mV\n",
                  SENSOR_NAMES[channel], PIN_MAP[channel],
                  startupMean, BASELINE_MAP_MV[channel]);
  }

  Serial.printf("[ADC] ZMPT calibration: source=%.5f V/mV, load=%.5f V/mV\n",
                static_cast<double>(ZMPT_SUMBER_VOLTS_PER_MV_RMS),
                static_cast<double>(ZMPT_BEBAN_VOLTS_PER_MV_RMS));
Serial.printf("[ADC] ACS 50Hz sensitivities: source=71.6 mV/A, load=73.7 mV/A (provisional 2.00 A reference).\n");
  Serial.println("[ADC] No-load noise calibration begins; ensure no primary current is flowing.");
  calibrateAcsIdleNoise();
  return true;
}

bool sensorsService() {
  // No I2C bus or ADS1115 recovery is required for the internal ADC.
  return adcInitialized;
}

bool sensorsReady() {
  return adcInitialized;
}

int readRawSensor(SensorId id) {
  if (!adcInitialized || !idValid(id)) return -1;
  return static_cast<int>(analogReadMilliVolts(PIN_MAP[static_cast<uint8_t>(id)]));
}

float hitungRMS(SensorId id) {
  const RmsWindow window = readWindow(id);
  return window.rmsAcMv;
}

bool bacaSemuaSensor(HasilSensor& hasilOut) {
  if (!adcInitialized) return false;

  HasilSensor hasil{};
  const RmsWindow windows[JUMLAH_SENSOR] = {
    readWindow(SENSOR_ZMPT_SUMBER),
    readWindow(SENSOR_ZMPT_BEBAN),
    readWindow(SENSOR_ACS712_SUMBER),
    readWindow(SENSOR_ACS712_BEBAN)
  };

  // Voltage bits retain the existing range/baseline/coefficient validity rules.
  for (uint8_t i = 0; i < 2U; ++i) {
    const float coefficient = (i == 0U)
        ? ZMPT_SUMBER_VOLTS_PER_MV_RMS
        : ZMPT_BEBAN_VOLTS_PER_MV_RMS;
    if (!windows[i].rangeValid || !windows[i].baselineValid ||
        !coefficientValid(coefficient) || !isfinite(windows[i].rmsAcMv)) {
      hasil.bitmask_kualitas |= static_cast<uint8_t>(1U << i);
    }
  }

  hasil.tegangan_sumber = voltageFromSensorRms(
      windows[SENSOR_ZMPT_SUMBER].rmsAcMv,
      ZMPT_SUMBER_VOLTS_PER_MV_RMS);
  hasil.tegangan_beban = voltageFromSensorRms(
      windows[SENSOR_ZMPT_BEBAN].rmsAcMv,
      ZMPT_BEBAN_VOLTS_PER_MV_RMS);

  const RmsWindow& sourceWindow = windows[SENSOR_ACS712_SUMBER];
  const RmsWindow& loadWindow = windows[SENSOR_ACS712_BEBAN];
  const bool sourceCurrentValid = sourceWindow.rangeValid && sourceWindow.baselineValid &&
      idleNoiseCalibrationValid[0] && isfinite(sourceWindow.fundamentalRmsMv) &&
      coefficientValid(ACS712_SUMBER_AMPS_PER_MV_RMS);
  const bool loadCurrentValid = loadWindow.rangeValid && loadWindow.baselineValid &&
      idleNoiseCalibrationValid[1] && isfinite(loadWindow.fundamentalRmsMv) &&
      coefficientValid(ACS712_BEBAN_AMPS_PER_MV_RMS);

  const float sourceNetRmsMv = sourceCurrentValid
      ? noiseCorrectedFundamentalRms(sourceWindow.fundamentalRmsMv,
                                     idleFundamentalNoiseRmsMv[0])
      : 0.0f;
  const float loadNetRmsMv = loadCurrentValid
      ? noiseCorrectedFundamentalRms(loadWindow.fundamentalRmsMv,
                                     idleFundamentalNoiseRmsMv[1])
      : 0.0f;

  hasil.arus_sumber = sourceCurrentValid
      ? currentFromSensorRms(sourceNetRmsMv, ACS712_SUMBER_AMPS_PER_MV_RMS)
      : 0.0f;
  hasil.arus_beban = loadCurrentValid
      ? currentFromSensorRms(loadNetRmsMv, ACS712_BEBAN_AMPS_PER_MV_RMS)
      : 0.0f;

  // Suppress only the measured noise floor. 0 A is a valid standby state when
  // ADC range, DC baseline, and boot idle-noise calibration are all valid.
  if (sourceCurrentValid && hasil.arus_sumber < ACS712_MIN_DETECT_CURRENT_A) {
    hasil.arus_sumber = 0.0f;
  }
  if (loadCurrentValid && hasil.arus_beban < ACS712_MIN_DETECT_CURRENT_A) {
    hasil.arus_beban = 0.0f;
  }

  const bool sourceNoLoad = sourceCurrentValid &&
      hasil.arus_sumber < ACS712_MIN_DETECT_CURRENT_A;
  const bool loadNoLoad = loadCurrentValid &&
      hasil.arus_beban < ACS712_MIN_DETECT_CURRENT_A;

  // User-defined current status: >1.80 A = SUSPECT; <=1.80 A = NORMAL.
  // A channel with invalid ADC/baseline/idle calibration remains SUSPECT regardless of its numeric placeholder.
  hasil.suspect_arus_sumber = !sourceCurrentValid ||
      hasil.arus_sumber > ACS712_SUSPECT_CURRENT_A;
  hasil.suspect_arus_beban = !loadCurrentValid ||
      hasil.arus_beban > ACS712_SUSPECT_CURRENT_A;

  if (hasil.suspect_arus_sumber) hasil.bitmask_kualitas |= (1U << SENSOR_ACS712_SUMBER);
  if (hasil.suspect_arus_beban) hasil.bitmask_kualitas |= (1U << SENSOR_ACS712_BEBAN);

  hasil.status_tegangan_sumber = voltageStatus(hasil.tegangan_sumber, warningSource);
  hasil.status_tegangan_beban = voltageStatus(hasil.tegangan_beban, warningLoad);
  hasil.warning_tegangan_sumber = (hasil.status_tegangan_sumber == STATUS_V_WARNING);
  hasil.warning_tegangan_beban = (hasil.status_tegangan_beban == STATUS_V_WARNING);

#ifdef MODE_DEBUG_SENSOR
  for (uint8_t i = 0; i < JUMLAH_SENSOR; ++i) {
    Serial.printf("[ADC] %s GPIO%u DC=%.1f mV RMS_AC=%.2f mV FUND50=%.2f mV Fs=%.0f Hz MIN/MAX=%u/%u mV range=%s baseline=%s\n",
                  SENSOR_NAMES[i], PIN_MAP[i], windows[i].meanMv,
                  windows[i].rmsAcMv, windows[i].fundamentalRmsMv,
                  windows[i].sampleRateHz, windows[i].minMv, windows[i].maxMv,
                  windows[i].rangeValid ? "OK" : "SUSPECT",
                  windows[i].baselineValid ? "OK" : "SUSPECT");
  }
  Serial.printf("[ADC-ACS] source idle50=%.2f mV net50=%.2f mV status=%s | load idle50=%.2f mV net50=%.2f mV status=%s\n",
                idleFundamentalNoiseRmsMv[0], sourceNetRmsMv,
                hasil.suspect_arus_sumber ? "SUSPECT" : (sourceNoLoad ? "STANDBY" : "NORMAL"),
                idleFundamentalNoiseRmsMv[1], loadNetRmsMv,
                hasil.suspect_arus_beban ? "SUSPECT" : (loadNoLoad ? "STANDBY" : "NORMAL"));
  Serial.printf("[ADC-RESULT] Vsrc=%.2f V Vload=%.2f V Isrc=%.3f A Iload=%.3f A quality=0x%02X\n",
                hasil.tegangan_sumber, hasil.tegangan_beban,
                hasil.arus_sumber, hasil.arus_beban, hasil.bitmask_kualitas);
#endif

  hasilOut = hasil;
  return true;
}