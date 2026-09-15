/**
 * shared_state.h — Primitif komunikasi antar-task/antar-core
 * Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)
 *
 * Firmware ini menjalankan dua task FreeRTOS pada core berbeda (lihat
 * main.cpp): task ADC+Modbus RTU (time-critical) di Core 1, dan task
 * WiFi+MQTT (lebih lambat, tidak deterministik) di Core 0. Data yang
 * mengalir ANTAR kedua task ini tidak boleh diakses lewat variabel biasa
 * tanpa proteksi, karena berisiko race condition / data tearing bila satu
 * core menulis saat core lain membaca di waktu bersamaan.
 *
 * File ini mendeklarasikan dua FreeRTOS Queue sebagai jalur komunikasi
 * resmi antar-core:
 *   - queueDataSensor : Core 1 -> Core 0 (hasil RMS terbaru, untuk di-
 *                        publish MQTT). Queue satu-slot dengan overwrite,
 *                        karena hanya nilai TERBARU yang relevan.
 *   - queuePerintahRemote : Core 0 -> Core 1 (perintah NO/NC dari
 *                        aplikasi mobile via MQTT, untuk ditulis ke
 *                        register Modbus REG_CMD_REMOTE oleh Core 1).
 *
 * Status koneksi MQTT (untuk mengisi REG_LRUFAIL) dilewatkan sebagai
 * variabel volatile sederhana (bukan queue) karena berupa satu bit
 * boolean — aman dibaca lintas-core pada arsitektur ESP32 (Xtensa,
 * akses 32-bit selaras bersifat atomik).
 */

#ifndef SHARED_STATE_H
#define SHARED_STATE_H

#include <Arduino.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include "sensors.h"

extern QueueHandle_t queueDataSensor;      // isi: struct HasilSensor
extern QueueHandle_t queuePerintahRemote;  // isi: uint16_t (0/1/2)
extern volatile bool statusMqttTerhubung;      // ditulis Core 0, dibaca Core 1 (-> REG_LRUFAIL)
extern volatile bool statusComFailEstimasiLokal; // ditulis Core 1, dibaca Core 0 (-> publish MQTT)

#endif // SHARED_STATE_H
