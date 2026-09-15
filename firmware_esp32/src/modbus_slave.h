/**
 * modbus_slave.h — Modul Modbus RTU slave (ESP32 sebagai slave, PLC sebagai master)
 * Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)
 *
 * Memakai library ModbusRTU (emelianov/modbus-esp8266, PlatformIO lib ID
 * "modbus-esp8266"). Lihat platformio.ini untuk versi yang dikunci.
 *
 * CATATAN DESAIN — PROPAGASI STATUS COMFail KE APLIKASI MOBILE:
 * COMFail (kegagalan link Modbus RTU ESP32<->PLC) dideteksi oleh WATCHDOG
 * DI SISI PLC (PLC sebagai master menghitung kegagalan poll berturut-turut).
 * Karena itu, PLC TIDAK BISA "memberitahu" ESP32 tentang status COMFail
 * miliknya sendiri melalui link Modbus RTU yang sama yang sedang gagal —
 * ini secara prinsip tidak mungkin (link yang sedang down tidak bisa
 * dipakai untuk mengabarkan bahwa link itu sedang down).
 *
 * Solusi yang diusulkan di sini: ESP32 melakukan estimasi MANDIRI di sisi
 * SLAVE, independen dari status internal PLC yang sebenarnya, dengan
 * memantau "waktu sejak permintaan Modbus RTU valid terakhir diterima dari
 * PLC". Jika melampaui ambang batas (lebih lama dari beberapa kali interval
 * polling normal PLC), ESP32 menyimpulkan link kemungkinan terputus dari
 * sisinya sendiri, dan mempublikasikan estimasi ini via MQTT (topic
 * TOPIC_STATUS_COMF) agar aplikasi mobile punya indikasi, TANPA mengklaim
 * ini adalah pembacaan langsung status internal PLC yang sebenarnya.
 * Perbedaan ini WAJIB dijelaskan di BAB 4 sebagai keterbatasan desain, dan
 * divalidasi secara empiris pada tahap pengujian (Sub-bab 3.4.6 proposal)
 * apakah estimasi ESP32 ini cukup akurat/responsif dibanding status
 * COMFail asli pada ladder logic PLC.
 */

#ifndef MODBUS_SLAVE_H
#define MODBUS_SLAVE_H

#include <Arduino.h>
#include "sensors.h"

/**
 * Inisialisasi UART2 dan Modbus RTU slave, mendaftarkan seluruh register
 * pada peta register config.h. Panggil sekali di setup(), dari Core 1
 * (task ADC+Modbus), BUKAN dari Core 0 (task WiFi+MQTT).
 */
void modbusSlaveInit();

/**
 * Harus dipanggil berulang (non-blocking) di dalam loop task Modbus —
 * memproses request masuk dari PLC dan menjalankan watchdog lokal untuk
 * estimasi status COMFail (lihat catatan desain di atas).
 */
void modbusSlaveTask();

/**
 * Memperbarui register hasil pengukuran (Input Register) dengan hasil
 * siklus RMS terbaru. Dipanggil dari task ADC+Modbus setelah
 * bacaSemuaSensor() selesai.
 */
void modbusUpdateHasilSensor(const HasilSensor& hasil);

/**
 * Memperbarui register status LRUFail (Input Register). Nilai sebenarnya
 * berasal dari status koneksi MQTT (dikelola task WiFi+MQTT di Core 0) —
 * fungsi ini dipanggil lintas-task memakai mekanisme yang aman (lihat
 * implementasi main.cpp: nilai di-passing melalui variabel volatile /
 * queue FreeRTOS, BUKAN dipanggil langsung dari Core 0).
 */
void modbusUpdateLRUFail(bool statusFail);

/**
 * Membaca nilai register perintah remote (REG_CMD_REMOTE) yang terakhir
 * ditulis oleh task MQTT (lihat main.cpp) agar tersedia untuk dibaca PLC.
 * PLC bertanggung jawab menulis-balik 0 ke register ini via Modbus write
 * (fungsi 06) setelah perintah dieksekusi ladder logic — firmware ESP32
 * TIDAK melakukan auto-clear, karena akan berpotensi race condition
 * dengan proses pembacaan/eksekusi PLC (lihat catatan handshake di
 * config.h). Fungsi ini disediakan bila BAB 4 perlu menampilkan log
 * nilai register command untuk keperluan debug/dokumentasi.
 */
uint16_t modbusBacaRegisterCommand();

/**
 * Mengisi register perintah remote (dipanggil dari task MQTT saat
 * menerima command dari aplikasi mobile — lihat mqtt_handler.cpp).
 * value: 0=tidak ada perintah, 1=NO, 2=NC.
 */
void modbusTulisPerintahRemote(uint16_t value);

/**
 * Mengembalikan true bila watchdog lokal mendeteksi tidak ada permintaan
 * Modbus RTU valid dari PLC melebihi ambang batas — estimasi COMFail
 * sisi ESP32 (lihat catatan desain di atas, BUKAN pembacaan langsung
 * status internal PLC).
 */
bool modbusEstimasiComFailLokal();

#endif // MODBUS_SLAVE_H
