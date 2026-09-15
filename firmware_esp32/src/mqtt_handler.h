/**
 * mqtt_handler.h — Modul WiFi + MQTT client (HiveMQ Cloud, TLS, LWT)
 * Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)
 *
 * Berjalan di Core 0 (task WiFi+MQTT), terpisah dari Core 1 (task ADC+
 * Modbus RTU yang time-critical) — lihat main.cpp untuk pembagian task.
 *
 * LRUFail: status ini DITENTUKAN oleh mekanisme Last Will and Testament
 * (LWT) yang didaftarkan client ESP32 ke broker HiveMQ SAAT KONEKSI
 * DIBUAT. Broker akan mempublikasikan pesan LWT ke topic TOPIC_STATUS_LWT
 * secara OTOMATIS jika koneksi client terputus tanpa proses disconnect
 * yang bersih (mis. WiFi mati mendadak, ESP32 restart tanpa sempat
 * mengirim disconnect). Firmware ESP32 sendiri TIDAK mempublikasikan
 * LRUFail=FAIL secara langsung (karena jika ESP32 sudah terputus, ia
 * tidak bisa mempublikasikan apa pun) — firmware hanya bertanggung jawab
 * MENDAFTARKAN pesan LWT di awal, dan mempublikasikan LRUFail=NORMAL saat
 * koneksi berhasil/tetap terjaga sebagai sinyal "masih hidup".
 */

#ifndef MQTT_HANDLER_H
#define MQTT_HANDLER_H

#include <Arduino.h>
#include "sensors.h"

/**
 * Inisialisasi WiFi (mode STA) dan client MQTT (TLS, kredensial, LWT).
 * Panggil sekali di setup(), dari Core 0.
 */
void mqttHandlerInit();

/**
 * Harus dipanggil berulang di dalam loop task MQTT (Core 0). Menjaga
 * koneksi WiFi dan MQTT (auto-reconnect bila terputus), memproses pesan
 * masuk (subscribe callback dijalankan dari sini).
 */
void mqttHandlerTask();

/**
 * Mempublikasikan hasil pengukuran (4 RMS + kualitas data) sebagai JSON
 * ke TOPIC_DATA_SENSOR. Dipanggil setiap siklus (~1 detik) setelah data
 * terbaru tersedia dari task ADC+Modbus (melalui queue FreeRTOS, lihat
 * main.cpp).
 */
void mqttPublishDataSensor(const HasilSensor& hasil);

/**
 * Mempublikasikan estimasi status COMFail sisi ESP32 (lihat catatan
 * desain di modbus_slave.h) ke TOPIC_STATUS_COMF.
 */
void mqttPublishComFailEstimasi(bool statusFail);

/**
 * Mengembalikan true jika koneksi MQTT ke broker sedang aktif. Dipakai
 * task ADC+Modbus (melalui variabel shared) untuk mengisi REG_LRUFAIL.
 */
bool mqttTerhubung();

#endif // MQTT_HANDLER_H
