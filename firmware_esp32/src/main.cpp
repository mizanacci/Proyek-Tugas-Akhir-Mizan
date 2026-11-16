/**
 * main.cpp — Orkestrasi SCADA ESP32-S3 dengan task sensor terpisah.
 * Core 1: task Modbus berprioritas tinggi + task akuisisi ADS1115.
 * Core 0: WiFi/MQTT. Kegagalan akuisisi ADC tidak boleh menghentikan Modbus.
 */
#include <Arduino.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <freertos/queue.h>
#include "config.h"
#include "sensors.h"
#include "modbus_slave.h"
#include "mqtt_handler.h"
#include "shared_state.h"

QueueHandle_t queueDataSensor = nullptr;
QueueHandle_t queueDataSensorModbus = nullptr;
QueueHandle_t queuePerintahRemote = nullptr;
volatile bool statusSensorValid = false;
volatile bool statusMqttTerhubung = false;
volatile bool statusComFailEstimasiLokal = true;

static TaskHandle_t handleTaskModbus = nullptr;
static TaskHandle_t handleTaskSensor = nullptr;
static TaskHandle_t handleTaskWifiMqtt = nullptr;

#ifdef MODE_DIAG_UART
static void jalankanDiagUart() {
  Serial2.begin(MODBUS_BAUDRATE, MODBUS_SERIAL_CONFIG,
                PIN_MODBUS_RX2, PIN_MODBUS_TX2);
  Serial.printf("[DIAG-UART] RX=GPIO%d TX=GPIO%d %d - sensor & Modbus dimatikan\n",
                PIN_MODBUS_RX2, PIN_MODBUS_TX2, MODBUS_BAUDRATE);
  unsigned long tKirim = 0;
  for (;;) {
    if (millis() - tKirim >= 1000) {
      tKirim = millis();
      Serial2.print("ESP32-UART-TEST\r\n");
    }
    while (Serial2.available()) Serial.printf("%02X ", Serial2.read());
    vTaskDelay(pdMS_TO_TICKS(5));
  }
}
#endif

// =============================================================
// Task Core 1 — Modbus RTU slave. Tidak mengakses ADC internal.
// Prioritas tertinggi pada Core 1 agar polling PLC tetap dilayani.
// =============================================================
static void taskModbus(void* parameter) {
  (void)parameter;
#ifdef MODE_DIAG_UART
  jalankanDiagUart();
#else
  modbusSlaveInit();
  modbusTandaiSensorTidakValid();
  bool registerSensorValid = false;
  unsigned long waktuDiagTerakhir = millis();

  for (;;) {
    modbusSlaveTask();

    // Command dari MQTT tetap hanya ditulis oleh task Modbus.
    if (modbusBacaRegisterCommand() == 0) {
      uint16_t perintahBaru = 0;
      if (xQueueReceive(queuePerintahRemote, &perintahBaru, 0) == pdTRUE) {
        if (perintahBaru == 1 || perintahBaru == 2) {
          modbusTulisPerintahRemote(perintahBaru);
        } else {
          Serial.printf("[MODBUS] Command ditolak: nilai tidak valid (%u)\n",
                        perintahBaru);
        }
      }
    }

    // Queue khusus ini hanya dikonsumsi task Modbus (bukan task MQTT).
    HasilSensor hasilModbus;
    if (xQueueReceive(queueDataSensorModbus, &hasilModbus, 0) == pdTRUE) {
      modbusUpdateHasilSensor(hasilModbus);
      registerSensorValid = true;
    }

    // Ketika pembacaan I2C gagal, tandai semua kanal INVALID tetapi pertahankan
    // angka terakhir. Ketika batch valid kembali, queue di atas memperbarui data.
    if (!statusSensorValid && registerSensorValid) {
      modbusTandaiSensorTidakValid();
      registerSensorValid = false;
      Serial.println("[SENSOR] ADC acquisition invalid: register kualitas Modbus = 0x0F; nilai terakhir dipertahankan.");
    }

    modbusUpdateLRUFail(!statusMqttTerhubung);
    statusComFailEstimasiLokal = modbusEstimasiComFailLokal();

    if (millis() - waktuDiagTerakhir >= 5000) {
      waktuDiagTerakhir = millis();
      Serial.printf("[MODBUS] akses=%lu, terakhir %lu ms lalu | COMFail(estimasi): %s | Sensor: %s\n",
                    modbusJumlahAksesRegister(),
                    modbusMsSejakAksesTerakhir(),
                    statusComFailEstimasiLokal ? "FAIL" : "NORMAL",
                    statusSensorValid ? "VALID" : "INVALID");
    }

    // Periodic yield: task sensor (prioritas di bawah) memperoleh slot CPU.
    vTaskDelay(pdMS_TO_TICKS(1));
  }
#endif
}

// =============================================================
// Task Core 1 — Akuisisi ADC internal. Tidak memanggil API Modbus.
// =============================================================
#ifndef MODE_DIAG_UART
static void taskSensorADC(void* parameter) {
  (void)parameter;
  const bool readyAtBoot = sensorsInit();
  unsigned long waktuSiklusTerakhir = readyAtBoot ? millis() : 0;
  unsigned int jumlahSiklusValid = 0;

  if (!readyAtBoot) {
    statusSensorValid = false;
    Serial.println("[SENSOR] ADC internal belum siap. Modbus dan MQTT tetap dijalankan; recovery dijadwalkan.");
  }

  for (;;) {
    if (!sensorsReady()) {
      if (sensorsService()) {
        // Ambil batch pertama segera setelah recovery berhasil.
        waktuSiklusTerakhir = millis() - TARGET_SIKLUS_MS;
      } else {
        vTaskDelay(pdMS_TO_TICKS(20));
        continue;
      }
    }

    if (millis() - waktuSiklusTerakhir >= TARGET_SIKLUS_MS) {
      waktuSiklusTerakhir = millis();
      const unsigned long mulaiBacaSensor = micros();
      HasilSensor hasil = {};

      if (bacaSemuaSensor(hasil)) {
        // Set status valid sebelum memberi kesempatan task Modbus berjalan.
        statusSensorValid = true;
        xQueueOverwrite(queueDataSensorModbus, &hasil);
        xQueueOverwrite(queueDataSensor, &hasil);

        if (++jumlahSiklusValid % 5 == 0) {
          const unsigned long durasi = micros() - mulaiBacaSensor;
          Serial.printf("[TIMING] bacaSemuaSensor=%.3f ms (target <1000 ms)\n",
                        durasi / 1000.0f);
          Serial.printf("[SENSOR] Batch valid; kualitas=0x%02X\n",
                        hasil.bitmask_kualitas);
        }
      } else {
        // Jangan publikasikan sampel parsial atau mempertahankan queue berisi
        // sampel lama seolah-olah sebagai telemetri baru.
        statusSensorValid = false;
        xQueueReset(queueDataSensor);
        xQueueReset(queueDataSensorModbus);
        Serial.println("[SENSOR] Batch dibatalkan akibat kegagalan ADC internal. Telemetri ditahan; recovery dimulai.");
      }
    }

    vTaskDelay(pdMS_TO_TICKS(1));
  }
}
#endif

// =============================================================
// Task Core 0 — WiFi + MQTT.
// =============================================================
static void taskWifiMqtt(void* parameter) {
  (void)parameter;
  mqttHandlerInit();
  for (;;) {
    mqttHandlerTask();
    statusMqttTerhubung = mqttTerhubung();
    vTaskDelay(pdMS_TO_TICKS(50));
  }
}

void setup() {
  Serial.begin(115200);
  delay(300);
  Serial.println("\n=== Firmware SCADA Distribusi Listrik — Boot (ADC internal) ===");

  queueDataSensor = xQueueCreate(1, sizeof(HasilSensor));
  queueDataSensorModbus = xQueueCreate(1, sizeof(HasilSensor));
  queuePerintahRemote = xQueueCreate(REMOTE_COMMAND_QUEUE_LENGTH,
                                     sizeof(uint16_t));

  if (queueDataSensor == nullptr || queueDataSensorModbus == nullptr ||
      queuePerintahRemote == nullptr) {
    Serial.println("[FATAL] Gagal membuat queue FreeRTOS.");
    while (true) delay(1000);
  }

#ifdef MODE_DIAG_UART
  if (xTaskCreatePinnedToCore(taskModbus, "Task-DIAG-UART", 4096, nullptr,
                              3, &handleTaskModbus, 1) != pdPASS) {
    Serial.println("[FATAL] Gagal membuat task diagnostik UART.");
    while (true) delay(1000);
  }
#else
  // Urutan dan prioritas memastikan Modbus siap sebelum ADS1115 berhasil.
  if (xTaskCreatePinnedToCore(taskModbus, "Task-Modbus-RTU", 8192, nullptr,
                              3, &handleTaskModbus, 1) != pdPASS) {
    Serial.println("[FATAL] Gagal membuat Task-Modbus-RTU.");
    while (true) delay(1000);
  }

  if (xTaskCreatePinnedToCore(taskSensorADC, "Task-Sensor-ADC", 8192, nullptr,
                              2, &handleTaskSensor, 1) != pdPASS) {
    Serial.println("[FATAL] Gagal membuat Task-Sensor-ADC.");
    while (true) delay(1000);
  }
#endif

  if (xTaskCreatePinnedToCore(taskWifiMqtt, "Task-WiFi-MQTT", 8192, nullptr,
                              1, &handleTaskWifiMqtt, 0) != pdPASS) {
    Serial.println("[FATAL] Gagal membuat Task-WiFi-MQTT.");
    while (true) delay(1000);
  }

  Serial.println("[OK] Task Modbus, Sensor-I2C, dan WiFi-MQTT dibuat.");
}

void loop() {
  vTaskDelay(pdMS_TO_TICKS(1000));
}
