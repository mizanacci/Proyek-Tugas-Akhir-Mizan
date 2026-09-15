/**
 * main.cpp — Orkestrasi utama firmware ESP32
 * Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)
 *
 * Arsitektur dual-core (mengikuti anggaran waktu proposal BAB 3.4.4):
 *   - Core 1 ("Task ADC-Modbus"): pembacaan 4 kanal ADC, perhitungan RMS,
 *     dan komunikasi Modbus RTU slave ke PLC. Bersifat time-critical —
 *     TIDAK boleh terganggu oleh operasi jaringan yang lebih lambat dan
 *     tidak deterministik.
 *   - Core 0 ("Task WiFi-MQTT"): koneksi WiFi, MQTT (publish data sensor +
 *     status, subscribe perintah remote). Termasuk task bawaan WiFi/BT
 *     stack ESP-IDF sendiri yang memang dialokasikan di Core 0.
 *
 * Komunikasi antar-core memakai primitif pada shared_state.h — JANGAN
 * memanggil fungsi modul Modbus dari Core 0 atau fungsi modul MQTT dari
 * Core 1 secara langsung; selalu lewat queue/variabel shared yang sudah
 * disediakan.
 */

#include <Arduino.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include "config.h"
#include "sensors.h"
#include "modbus_slave.h"
#include "mqtt_handler.h"
#include "shared_state.h"

// Definisi aktual primitif shared (dideklarasikan extern di shared_state.h)
QueueHandle_t queueDataSensor = nullptr;
QueueHandle_t queuePerintahRemote = nullptr;
volatile bool statusMqttTerhubung = false;
volatile bool statusComFailEstimasiLokal = false;

static TaskHandle_t handleTaskAdcModbus = nullptr;
static TaskHandle_t handleTaskWifiMqtt = nullptr;

// =============================================================
// Task Core 1 — ADC + Modbus RTU slave (time-critical)
// =============================================================
static void taskAdcModbus(void* parameter) {
  sensorsInit();
  modbusSlaveInit();

  unsigned long waktuSiklusTerakhir = 0;

  for (;;) {
    // --- Proses request Modbus RTU masuk — dipanggil tiap iterasi loop,
    //     TANPA delay panjang, agar respons ke polling PLC tetap cepat ---
    modbusSlaveTask();

    // --- Terima perintah remote dari Core 0 (jika ada) dan tuliskan ke
    //     register Modbus (hanya Core 1 yang menyentuh objek Modbus 'mb') ---
    uint16_t perintahBaru;
    if (xQueueReceive(queuePerintahRemote, &perintahBaru, 0) == pdTRUE) {
      modbusTulisPerintahRemote(perintahBaru);
    }

    // --- Siklus RMS + update register + kirim ke Core 0, setiap
    //     TARGET_SIKLUS_MS (default 1 detik, sesuai anggaran waktu proposal) ---
    if (millis() - waktuSiklusTerakhir >= TARGET_SIKLUS_MS) {
      waktuSiklusTerakhir = millis();

      HasilSensor hasil = bacaSemuaSensor();
      modbusUpdateHasilSensor(hasil);
      modbusUpdateLRUFail(statusMqttTerhubung);  // baca status dari Core 0 (volatile bool, aman)

      statusComFailEstimasiLokal = modbusEstimasiComFailLokal();

      // Kirim salinan hasil ke Core 0 untuk dipublikasikan MQTT.
      // xQueueOverwrite: queue satu-slot, nilai lama (bila belum sempat
      // dibaca Core 0) ditimpa — hanya nilai TERBARU yang relevan untuk
      // use-case monitoring ini, bukan riwayat setiap sampel.
      xQueueOverwrite(queueDataSensor, &hasil);
    }

    // Beri jeda singkat agar watchdog task FreeRTOS tidak trigger dan
    // task lain pada core yang sama (jika ada) tetap kebagian waktu CPU.
    vTaskDelay(pdMS_TO_TICKS(5));
  }
}

// =============================================================
// Task Core 0 — WiFi + MQTT (tidak time-critical, boleh ada jeda jaringan)
// =============================================================
static void taskWifiMqtt(void* parameter) {
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
  Serial.println("\n=== Firmware SCADA Distribusi Listrik — Boot ===");

  // Queue satu-slot (panjang 1) untuk masing-masing arah komunikasi
  // antar-core, sesuai desain di shared_state.h.
  queueDataSensor = xQueueCreate(1, sizeof(HasilSensor));
  queuePerintahRemote = xQueueCreate(1, sizeof(uint16_t));

  if (queueDataSensor == nullptr || queuePerintahRemote == nullptr) {
    Serial.println("[FATAL] Gagal membuat queue FreeRTOS — periksa memori heap tersedia.");
    while (true) { delay(1000); }
  }

  // xTaskCreatePinnedToCore: parameter terakhir menentukan core (0 atau 1).
  // Prioritas task ADC-Modbus dibuat lebih tinggi (2) daripada WiFi-MQTT
  // (1) agar penjadwalan FreeRTOS memprioritaskan proses time-critical
  // bila keduanya kebetulan siap berjalan bersamaan pada core masing-masing.
  xTaskCreatePinnedToCore(
      taskAdcModbus, "Task-ADC-Modbus",
      8192,      // ukuran stack (byte) — [DRAF, pantau via uxTaskGetStackHighWaterMark saat pengujian, naikkan bila mendekati penuh]
      nullptr,
      2,         // prioritas
      &handleTaskAdcModbus,
      1          // Core 1
  );

  xTaskCreatePinnedToCore(
      taskWifiMqtt, "Task-WiFi-MQTT",
      8192,      // [DRAF, sama seperti di atas — TLS/JSON cenderung butuh stack lebih besar, pantau saat pengujian]
      nullptr,
      1,         // prioritas
      &handleTaskWifiMqtt,
      0          // Core 0
  );

  Serial.println("[OK] Kedua task dual-core berhasil dibuat.");
}

void loop() {
  // Sengaja dikosongkan — seluruh logika berjalan di dalam kedua task
  // FreeRTOS di atas (taskAdcModbus di Core 1, taskWifiMqtt di Core 0).
  // loop() Arduino secara default berjalan sebagai task tersendiri di
  // Core 1 dengan prioritas rendah; dibiarkan idle dengan delay panjang
  // agar tidak menyita waktu CPU dari task ADC-Modbus yang time-critical.
  vTaskDelay(pdMS_TO_TICKS(1000));
}
