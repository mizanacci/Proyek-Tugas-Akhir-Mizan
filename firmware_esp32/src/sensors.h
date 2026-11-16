/**
 * sensors.h - Internal ADC acquisition for ESP32-S3.
 * Four analog channels: ZMPT source/load and ACS712 source/load.
 * Interface retained for the separated FreeRTOS sensor/Modbus/MQTT tasks.
 */
#ifndef SENSORS_H
#define SENSORS_H

#include <Arduino.h>

#define ADC_MAX_VALUE 4095

enum SensorId : uint8_t {
  SENSOR_ZMPT_SUMBER = 0,
  SENSOR_ZMPT_BEBAN = 1,
  SENSOR_ACS712_SUMBER = 2,
  SENSOR_ACS712_BEBAN = 3,
  JUMLAH_SENSOR = 4
};

enum StatusTegangan : uint8_t {
  STATUS_V_NORMAL = 0,
  STATUS_V_AC_OFF = 1,
  STATUS_V_SUSPECT = 2,
  STATUS_V_WARNING = 3
};

struct HasilSensor {
  float tegangan_sumber;
  float tegangan_beban;
  float arus_sumber;
  float arus_beban;
  uint8_t bitmask_kualitas;       // bit 0..3: 1 = SUSPECT/invalid/un-calibrated
  uint8_t status_tegangan_sumber; // StatusTegangan
  uint8_t status_tegangan_beban;  // StatusTegangan
  bool warning_tegangan_sumber;
  bool warning_tegangan_beban;
  bool suspect_arus_sumber;       // true while calibration invalid or measurement suspect
  bool suspect_arus_beban;
};

// Internal ADC has no external sensor-bus recovery; these functions preserve
// the interface expected by main.cpp and the FreeRTOS task architecture.
bool sensorsInit();
bool sensorsService();
bool sensorsReady();

// Returns calibrated millivolts, or -1 for invalid SensorId/not initialized.
int readRawSensor(SensorId id);

// AC RMS at the sensor output, in mV.
float hitungRMS(SensorId id);

// Returns false only if a batch could not be acquired. Quality faults are
// reported in bitmask_kualitas while valid numeric samples remain available.
bool bacaSemuaSensor(HasilSensor& hasil);

#endif // SENSORS_H