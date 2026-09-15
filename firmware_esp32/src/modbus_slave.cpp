/**
 * modbus_slave.cpp — Implementasi Modbus RTU slave
 * Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)
 *
 * Library: ModbusRTU (emelianov/modbus-esp8266). Lihat modbus_slave.h untuk
 * catatan desain lengkap soal estimasi COMFail sisi ESP32.
 */

#include "modbus_slave.h"
#include "config.h"
#include <ModbusRTU.h>

static ModbusRTU mb;

// Watchdog lokal: dicatat setiap kali register kita diakses (dibaca/ditulis)
// oleh master (PLC). volatile karena diakses dari callback (konteks mirip
// interrupt pada beberapa implementasi library) sekaligus dari task loop.
static volatile unsigned long waktuAksesTerakhir = 0;

// Ambang batas watchdog: beberapa kali lipat interval polling normal PLC
// (asumsi ~1 detik per proposal), diberi margin agar tidak terlalu sensitif
// terhadap jitter satu-dua siklus. [DRAF — sesuaikan setelah pengujian
// empiris Sub-bab 3.4.6 mengamati pola polling aktual dari ladder logic PLC]
#define AMBANG_WATCHDOG_MS  5000

// --- Callback dipanggil library saat register Input kita DIBACA master ---
// CATATAN VERIFIKASI: nama fungsi callback (onGetIreg) mengikuti pola
// penamaan library versi 4.x saat dokumen ini ditulis. Periksa API.md pada
// versi library yang benar-benar terpasang di lib_deps (platformio.ini) —
// beberapa versi menggunakan nama berbeda (mis. cbEnable dengan pola
// berbeda). Jika nama fungsi ini tidak dikenali compiler, cek
// https://github.com/emelianov/modbus-esp8266/blob/master/API.md
// pada versi yang terpasang.
static uint16_t cbAksesRegister(TRegister* reg, uint16_t val) {
  waktuAksesTerakhir = millis();
  return val;
}

void modbusSlaveInit() {
  Serial2.begin(MODBUS_BAUDRATE, SERIAL_8N1, PIN_MODBUS_RX2, PIN_MODBUS_TX2);
  mb.begin(&Serial2);   // tanpa pin DIR — RS-232C 3-kabel point-to-point,
                          // beda dengan RS-485 half-duplex yang perlu kontrol arah
  mb.slave(MODBUS_SLAVE_ID);

  // Input Register — hasil pengukuran, read-only dari sisi PLC
  mb.addIreg(REG_RMS_V_SUMBER);
  mb.addIreg(REG_RMS_V_BEBAN);
  mb.addIreg(REG_RMS_I_SUMBER);
  mb.addIreg(REG_RMS_I_BEBAN);
  mb.addIreg(REG_KUALITAS_DATA);
  mb.addIreg(REG_LRUFAIL);

  // Holding Register — perintah remote, PLC baca DAN tulis-balik (acknowledge)
  mb.addHreg(REG_CMD_REMOTE, 0);

  // Daftarkan callback watchdog pada tiap register agar AKSES APA PUN
  // (baca register manapun) memperbarui waktuAksesTerakhir.
  mb.onGetIreg(REG_RMS_V_SUMBER, cbAksesRegister, 1);
  mb.onGetIreg(REG_RMS_V_BEBAN, cbAksesRegister, 1);
  mb.onGetIreg(REG_RMS_I_SUMBER, cbAksesRegister, 1);
  mb.onGetIreg(REG_RMS_I_BEBAN, cbAksesRegister, 1);
  mb.onGetIreg(REG_KUALITAS_DATA, cbAksesRegister, 1);
  mb.onGetIreg(REG_LRUFAIL, cbAksesRegister, 1);
  mb.onGetHreg(REG_CMD_REMOTE, cbAksesRegister, 1);
  mb.onSetHreg(REG_CMD_REMOTE, cbAksesRegister, 1);  // PLC menulis-balik 0 di sini

  waktuAksesTerakhir = millis();  // inisialisasi agar tidak langsung FAIL saat boot
}

void modbusSlaveTask() {
  mb.task();
  // task() bersifat non-blocking (event-driven internal); yield() sekadar
  // menjaga scheduler FreeRTOS tetap responsif untuk task lain pada core
  // yang sama.
  yield();
}

void modbusUpdateHasilSensor(const HasilSensor& hasil) {
  mb.Ireg(REG_RMS_V_SUMBER, (uint16_t)(hasil.tegangan_sumber * SKALA_TEGANGAN));
  mb.Ireg(REG_RMS_V_BEBAN,  (uint16_t)(hasil.tegangan_beban  * SKALA_TEGANGAN));
  mb.Ireg(REG_RMS_I_SUMBER, (uint16_t)(hasil.arus_sumber     * SKALA_ARUS));
  mb.Ireg(REG_RMS_I_BEBAN,  (uint16_t)(hasil.arus_beban      * SKALA_ARUS));
  mb.Ireg(REG_KUALITAS_DATA, hasil.bitmask_kualitas);
}

void modbusUpdateLRUFail(bool statusFail) {
  mb.Ireg(REG_LRUFAIL, statusFail ? 1 : 0);
}

uint16_t modbusBacaRegisterCommand() {
  return mb.Hreg(REG_CMD_REMOTE);
}

void modbusTulisPerintahRemote(uint16_t value) {
  mb.Hreg(REG_CMD_REMOTE, value);
}

bool modbusEstimasiComFailLokal() {
  return (millis() - waktuAksesTerakhir) > AMBANG_WATCHDOG_MS;
}
