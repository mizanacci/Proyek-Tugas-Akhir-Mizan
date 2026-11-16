/**
 * modbus_slave.h — Modul Modbus RTU slave (ESP32 sebagai slave, PLC sebagai master)
 * Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)
 *
 * Memakai library ModbusRTU (emelianov/modbus-esp8266, PlatformIO lib ID
 * "modbus-esp8266"). Lihat platformio.ini untuk versi yang dikunci.
 *
 * CATATAN DESAIN — PROPAGASI STATUS COMFail KE APLIKASI MOBILE:
 * COMFail merupakan estimasi sisi ESP32 atas komunikasi Modbus RTU ESP32<->PLC.
 * Status COM hanya NORMAL jika PLC mengirim write heartbeat HREG7 (FC06)
 * dan heartbeat tersebut masih berumur paling lama MODE_OPERASI_PLC_TIMEOUT_MS.
 * Pembacaan IREG sensor atau register Modbus lain tidak cukup untuk menyatakan
 * integrasi PLC aktif. Tanpa write HREG7, termasuk sejak boot, status tetap FAIL.
 * Ini tetap estimasi komunikasi dari sisi ESP32, bukan pembacaan status internal
 * alarm PLC. Timeout harus divalidasi terhadap periode pengiriman HREG7 pada ladder.
 */

#ifndef MODBUS_SLAVE_H
#define MODBUS_SLAVE_H

#include <Arduino.h>
#include "sensors.h"

/**
 * Inisialisasi UART2 dan Modbus RTU slave, mendaftarkan seluruh register
 * pada peta register config.h. Panggil sekali dari task Modbus di Core 1,
 * terpisah dari task akuisisi sensor dan task WiFi+MQTT.
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
 * siklus RMS terbaru. Dipanggil hanya dari task Modbus setelah menerima
 * satu HasilSensor valid dari queue task akuisisi sensor.
 */
void modbusUpdateHasilSensor(const HasilSensor& hasil);

/** Menandai seluruh kanal sensor INVALID (0x0F) tanpa mengubah nilai numerik terakhir. */
void modbusTandaiSensorTidakValid();

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

/** Returns true while PLC has refreshed HREG7 within timeout. */
bool modbusModeOperasiPLCValid();
/** 0=UNKNOWN, 1=STANDBY, 2=RUN, 3=INVALID. */
uint16_t modbusBacaModeOperasiPLC();

/**
 * Mengisi register perintah remote (dipanggil dari task MQTT saat
 * menerima command dari aplikasi mobile — lihat mqtt_handler.cpp).
 * value: 0=tidak ada perintah, 1=NO, 2=NC.
 */
void modbusTulisPerintahRemote(uint16_t value);

/** Returns true unless a PLC HREG7 heartbeat was received within the 5 s timeout. */
bool modbusEstimasiComFailLokal();

/**
 * Mengembalikan durasi sejak akses Modbus RTU valid terakhir dari PLC.
 */
unsigned long modbusMsSejakAksesTerakhir();

/**
 * Jumlah akses register yang berhasil memicu callback library sejak boot.
 * Ini adalah indikator aktivitas polling, bukan jumlah frame mentah UART.
 */
unsigned long modbusJumlahAksesRegister();

#endif // MODBUS_SLAVE_H
