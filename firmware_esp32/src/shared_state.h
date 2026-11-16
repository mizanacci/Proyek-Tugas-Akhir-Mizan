/**
 * shared_state.h — Primitif komunikasi antar-task/antar-core
 * Task Modbus, akuisisi ADS1115, dan WiFi/MQTT.
 */
#ifndef SHARED_STATE_H
#define SHARED_STATE_H

#include <Arduino.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include "sensors.h"

constexpr UBaseType_t REMOTE_COMMAND_QUEUE_LENGTH = 4;

extern QueueHandle_t queueDataSensor;        // Sensor -> MQTT (1 sampel terbaru)
extern QueueHandle_t queueDataSensorModbus;  // Sensor -> task Modbus (1 sampel terbaru)
extern QueueHandle_t queuePerintahRemote;    // MQTT -> task Modbus (FIFO command)

extern volatile bool statusSensorValid;      // false bila batch ADS1115 gagal
extern volatile bool statusMqttTerhubung;    // Core 0 -> task Modbus
extern volatile bool statusComFailEstimasiLokal; // task Modbus -> Core 0

#endif // SHARED_STATE_H
