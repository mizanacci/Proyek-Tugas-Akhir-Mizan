warning: in the working copy of 'firmware_esp32/src/main.cpp', LF will be replaced by CRLF the next time Git touches it
[1mdiff --git a/firmware_esp32/src/main.cpp b/firmware_esp32/src/main.cpp[m
[1mindex a70ff18..0dd2f90 100644[m
[1m--- a/firmware_esp32/src/main.cpp[m
[1m+++ b/firmware_esp32/src/main.cpp[m
[36m@@ -1,143 +1,54 @@[m
[31m-/**[m
[31m- * main.cpp — Orkestrasi utama firmware ESP32[m
[31m- * Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)[m
[31m- *[m
[31m- * Arsitektur dual-core (mengikuti anggaran waktu proposal BAB 3.4.4):[m
[31m- *   - Core 1 ("Task ADC-Modbus"): pembacaan 4 kanal ADC, perhitungan RMS,[m
[31m- *     dan komunikasi Modbus RTU slave ke PLC. Bersifat time-critical —[m
[31m- *     TIDAK boleh terganggu oleh operasi jaringan yang lebih lambat dan[m
[31m- *     tidak deterministik.[m
[31m- *   - Core 0 ("Task WiFi-MQTT"): koneksi WiFi, MQTT (publish data sensor +[m
[31m- *     status, subscribe perintah remote). Termasuk task bawaan WiFi/BT[m
[31m- *     stack ESP-IDF sendiri yang memang dialokasikan di Core 0.[m
[31m- *[m
[31m- * Komunikasi antar-core memakai primitif pada shared_state.h — JANGAN[m
[31m- * memanggil fungsi modul Modbus dari Core 0 atau fungsi modul MQTT dari[m
[31m- * Core 1 secara langsung; selalu lewat queue/variabel shared yang sudah[m
[31m- * disediakan.[m
[31m- */[m
[31m-[m
 #include <Arduino.h>[m
[31m-#include <freertos/FreeRTOS.h>[m
[31m-#include <freertos/task.h>[m
[31m-#include "config.h"[m
[31m-#include "sensors.h"[m
[31m-#include "modbus_slave.h"[m
[31m-#include "mqtt_handler.h"[m
[31m-#include "shared_state.h"[m
[31m-[m
[31m-// Definisi aktual primitif shared (dideklarasikan extern di shared_state.h)[m
[31m-QueueHandle_t queueDataSensor = nullptr;[m
[31m-QueueHandle_t queuePerintahRemote = nullptr;[m
[31m-volatile bool statusMqttTerhubung = false;[m
[31m-volatile bool statusComFailEstimasiLokal = false;[m
[31m-[m
[31m-static TaskHandle_t handleTaskAdcModbus = nullptr;[m
[31m-static TaskHandle_t handleTaskWifiMqtt = nullptr;[m
[31m-[m
[31m-// =============================================================[m
[31m-// Task Core 1 — ADC + Modbus RTU slave (time-critical)[m
[31m-// =============================================================[m
[31m-static void taskAdcModbus(void* parameter) {[m
[31m-  sensorsInit();[m
[31m-  modbusSlaveInit();[m
[31m-[m
[31m-  unsigned long waktuSiklusTerakhir = 0;[m
[31m-[m
[31m-  for (;;) {[m
[31m-    // --- Proses request Modbus RTU masuk — dipanggil tiap iterasi loop,[m
[31m-    //     TANPA delay panjang, agar respons ke polling PLC tetap cepat ---[m
[31m-    modbusSlaveTask();[m
[32m+[m[32m#include <Wire.h>[m
[32m+[m[32m#include <Adafruit_ADS1X15.h>[m
 [m
[31m-    // --- Terima perintah remote dari Core 0 (jika ada) dan tuliskan ke[m
[31m-    //     register Modbus (hanya Core 1 yang menyentuh objek Modbus 'mb') ---[m
[31m-    uint16_t perintahBaru;[m
[31m-    if (xQueueReceive(queuePerintahRemote, &perintahBaru, 0) == pdTRUE) {[m
[31m-      modbusTulisPerintahRemote(perintahBaru);[m
[31m-    }[m
[31m-[m
[31m-    // --- Siklus RMS + update register + kirim ke Core 0, setiap[m
[31m-    //     TARGET_SIKLUS_MS (default 1 detik, sesuai anggaran waktu proposal) ---[m
[31m-    if (millis() - waktuSiklusTerakhir >= TARGET_SIKLUS_MS) {[m
[31m-      waktuSiklusTerakhir = millis();[m
[31m-[m
[31m-      HasilSensor hasil = bacaSemuaSensor();[m
[31m-      modbusUpdateHasilSensor(hasil);[m
[31m-      modbusUpdateLRUFail(statusMqttTerhubung);  // baca status dari Core 0 (volatile bool, aman)[m
[32m+[m[32m#define PIN_I2C_SDA 8[m
[32m+[m[32m#define PIN_I2C_SCL 9[m
[32m+[m[32m#define ADS1115_ADDR 0x48[m
 [m
[31m-      statusComFailEstimasiLokal = modbusEstimasiComFailLokal();[m
[31m-[m
[31m-      // Kirim salinan hasil ke Core 0 untuk dipublikasikan MQTT.[m
[31m-      // xQueueOverwrite: queue satu-slot, nilai lama (bila belum sempat[m
[31m-      // dibaca Core 0) ditimpa — hanya nilai TERBARU yang relevan untuk[m
[31m-      // use-case monitoring ini, bukan riwayat setiap sampel.[m
[31m-      xQueueOverwrite(queueDataSensor, &hasil);[m
[31m-    }[m
[31m-[m
[31m-    // Beri jeda singkat agar watchdog task FreeRTOS tidak trigger dan[m
[31m-    // task lain pada core yang sama (jika ada) tetap kebagian waktu CPU.[m
[31m-    vTaskDelay(pdMS_TO_TICKS(5));[m
[31m-  }[m
[31m-}[m
[31m-[m
[31m-// =============================================================[m
[31m-// Task Core 0 — WiFi + MQTT (tidak time-critical, boleh ada jeda jaringan)[m
[31m-// =============================================================[m
[31m-static void taskWifiMqtt(void* parameter) {[m
[31m-  mqttHandlerInit();[m
[31m-[m
[31m-  for (;;) {[m
[31m-    mqttHandlerTask();[m
[31m-    statusMqttTerhubung = mqttTerhubung();[m
[31m-    vTaskDelay(pdMS_TO_TICKS(50));[m
[31m-  }[m
[31m-}[m
[32m+[m[32mAdafruit_ADS1115 ads;[m
 [m
 void setup() {[m
   Serial.begin(115200);[m
[31m-  delay(300);[m
[31m-  Serial.println("\n=== Firmware SCADA Distribusi Listrik — Boot ===");[m
[32m+[m[32m  delay(1000);[m
 [m
[31m-  // Queue satu-slot (panjang 1) untuk masing-masing arah komunikasi[m
[31m-  // antar-core, sesuai desain di shared_state.h.[m
[31m-  queueDataSensor = xQueueCreate(1, sizeof(HasilSensor));[m
[31m-  queuePerintahRemote = xQueueCreate(1, sizeof(uint16_t));[m
[32m+[m[32m  Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL);[m
 [m
[31m-  if (queueDataSensor == nullptr || queuePerintahRemote == nullptr) {[m
[31m-    Serial.println("[FATAL] Gagal membuat queue FreeRTOS — periksa memori heap tersedia.");[m
[31m-    while (true) { delay(1000); }[m
[31m-  }[m
[31m-[m
[31m-  // xTaskCreatePinnedToCore: parameter terakhir menentukan core (0 atau 1).[m
[31m-  // Prioritas task ADC-Modbus dibuat lebih tinggi (2) daripada WiFi-MQTT[m
[31m-  // (1) agar penjadwalan FreeRTOS memprioritaskan proses time-critical[m
[31m-  // bila keduanya kebetulan siap berjalan bersamaan pada core masing-masing.[m
[31m-  xTaskCreatePinnedToCore([m
[31m-      taskAdcModbus, "Task-ADC-Modbus",[m
[31m-      8192,      // ukuran stack (byte) — [DRAF, pantau via uxTaskGetStackHighWaterMark saat pengujian, naikkan bila mendekati penuh][m
[31m-      nullptr,[m
[31m-      2,         // prioritas[m
[31m-      &handleTaskAdcModbus,[m
[31m-      1          // Core 1[m
[31m-  );[m
[32m+[m[32m  ads.setGain(GAIN_ONE);               // +/- 4.096 V[m
[32m+[m[32m  ads.setDataRate(RATE_ADS1115_860SPS);[m
 [m
[31m-  xTaskCreatePinnedToCore([m
[31m-      taskWifiMqtt, "Task-WiFi-MQTT",[m
[31m-      8192,      // [DRAF, sama seperti di atas — TLS/JSON cenderung butuh stack lebih besar, pantau saat pengujian][m
[31m-      nullptr,[m
[31m-      1,         // prioritas[m
[31m-      &handleTaskWifiMqtt,[m
[31m-      0          // Core 0[m
[31m-  );[m
[32m+[m[32m  if (!ads.begin(ADS1115_ADDR)) {[m
[32m+[m[32m    Serial.println("ADS1115 TIDAK TERDETEKSI!");[m
[32m+[m[32m    while (1) {[m
[32m+[m[32m      delay(1000);[m
[32m+[m[32m    }[m
[32m+[m[32m  }[m
 [m
[31m-  Serial.println("[OK] Kedua task dual-core berhasil dibuat.");[m
[32m+[m[32m  Serial.println();[m
[32m+[m[32m  Serial.println("=== TEST ACS712 + ADS1115 ===");[m
[32m+[m[32m  Serial.println("A2 = ACS712 sumber");[m
[32m+[m[32m  Serial.println("A3 = ACS712 beban");[m
[32m+[m[32m  Serial.println();[m
 }[m
 [m
 void loop() {[m
[31m-  // Sengaja dikosongkan — seluruh logika berjalan di dalam kedua task[m
[31m-  // FreeRTOS di atas (taskAdcModbus di Core 1, taskWifiMqtt di Core 0).[m
[31m-  // loop() Arduino secara default berjalan sebagai task tersendiri di[m
[31m-  // Core 1 dengan prioritas rendah; dibiarkan idle dengan delay panjang[m
[31m-  // agar tidak menyita waktu CPU dari task ADC-Modbus yang time-critical.[m
[31m-  vTaskDelay(pdMS_TO_TICKS(1000));[m
[31m-}[m
[32m+[m[32m  int16_t rawA2 = ads.readADC_SingleEnded(2);[m
[32m+[m[32m  int16_t rawA3 = ads.readADC_SingleEnded(3);[m
[32m+[m
[32m+[m[32m  float voltA2 = ads.computeVolts(rawA2);[m
[32m+[m[32m  float voltA3 = ads.computeVolts(rawA3);[m
[32m+[m
[32m+[m[32m  Serial.print("A2 raw=");[m
[32m+[m[32m  Serial.print(rawA2);[m
[32m+[m[32m  Serial.print("  voltage=");[m
[32m+[m[32m  Serial.print(voltA2, 4);[m
[32m+[m[32m  Serial.print(" V");[m
[32m+[m
[32m+[m[32m  Serial.print("    |    A3 raw=");[m
[32m+[m[32m  Serial.print(rawA3);[m
[32m+[m[32m  Serial.print("  voltage=");[m
[32m+[m[32m  Serial.print(voltA3, 4);[m
[32m+[m[32m  Serial.println(" V");[m
[32m+[m
[32m+[m[32m  delay(500);[m
[32m+[m[32m}[m
\ No newline at end of file[m
