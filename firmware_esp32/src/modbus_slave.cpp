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
#include <freertos/FreeRTOS.h>

static ModbusRTU mb;

// Watchdog lokal: dicatat setiap kali register kita diakses (dibaca/ditulis)
// oleh master (PLC). volatile karena diakses dari callback (konteks mirip
// interrupt pada beberapa implementasi library) sekaligus dari task loop.
static volatile unsigned long waktuAksesTerakhir = 0;
static volatile unsigned long jumlahAksesRegister = 0;

// Ambang batas watchdog: beberapa kali lipat interval polling normal PLC
// (asumsi ~1 detik per proposal), diberi margin agar tidak terlalu sensitif
// terhadap jitter satu-dua siklus. [DRAF — sesuaikan setelah pengujian
// empiris Sub-bab 3.4.6 mengamati pola polling aktual dari ladder logic PLC]
#define AMBANG_WATCHDOG_MS  5000

// HREG7 ditulis periodik oleh PLC.
static portMUX_TYPE muxModeOperasiPLC = portMUX_INITIALIZER_UNLOCKED;
static uint16_t modeOperasiPLC = MODE_OPERASI_UNKNOWN;
static uint32_t waktuModeOperasiPLC = 0;


// --- Callback dipanggil library saat register Input kita DIBACA master ---
// CATATAN VERIFIKASI: nama fungsi callback (onGetIreg) mengikuti pola
// penamaan library versi 4.x saat dokumen ini ditulis. Periksa API.md pada
// versi library yang benar-benar terpasang di lib_deps (platformio.ini) —
// beberapa versi menggunakan nama berbeda (mis. cbEnable dengan pola
// berbeda). Jika nama fungsi ini tidak dikenali compiler, cek
// https://github.com/emelianov/modbus-esp8266/blob/master/API.md
// pada versi yang terpasang.
static uint16_t cbAksesRegister(TRegister* reg, uint16_t val) {
  (void)reg;
  waktuAksesTerakhir = millis();
  jumlahAksesRegister++;
  return val;
}

// Callback ketika PLC menulis HREG7.
static uint16_t cbSetModeOperasiPLC(TRegister* reg, uint16_t val) {
  (void)reg;
  const uint32_t now = millis();
  waktuAksesTerakhir = now;
  jumlahAksesRegister++;
  const uint16_t mode = (val <= MODE_OPERASI_INVALID)
      ? val : MODE_OPERASI_INVALID;
  portENTER_CRITICAL(&muxModeOperasiPLC);
  modeOperasiPLC = mode;
  waktuModeOperasiPLC = now;
  portEXIT_CRITICAL(&muxModeOperasiPLC);
  return val;
}

void modbusSlaveInit() {
  Serial2.begin(
      MODBUS_BAUDRATE,
      MODBUS_SERIAL_CONFIG,
      PIN_MODBUS_RX2,
      PIN_MODBUS_TX2);
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
  mb.Ireg(REG_KUALITAS_DATA, 0x000F); // belum ada batch sensor valid sejak boot

  // Holding Register — perintah remote, PLC baca DAN tulis-balik (acknowledge)
  mb.addHreg(REG_CMD_REMOTE, 0);
  mb.addHreg(REG_MODE_OPERASI_PLC, MODE_OPERASI_UNKNOWN);

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
  mb.onGetHreg(REG_MODE_OPERASI_PLC, cbAksesRegister, 1);
  mb.onSetHreg(REG_MODE_OPERASI_PLC, cbSetModeOperasiPLC, 1);

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
  const auto keRegister = [](float nilai, float skala) -> uint16_t {
    if (!isfinite(nilai) || nilai <= 0.0f) return 0;
    const float terskala = roundf(nilai * skala);
    return (uint16_t)constrain(terskala, 0.0f, 65535.0f);
  };
  mb.Ireg(REG_RMS_V_SUMBER, keRegister(hasil.tegangan_sumber, SKALA_TEGANGAN));
  mb.Ireg(REG_RMS_V_BEBAN, keRegister(hasil.tegangan_beban, SKALA_TEGANGAN));
  mb.Ireg(REG_RMS_I_SUMBER, keRegister(hasil.arus_sumber, SKALA_ARUS));
  mb.Ireg(REG_RMS_I_BEBAN, keRegister(hasil.arus_beban, SKALA_ARUS));
  // IREG4 bits 0..3 = kualitas sensor; 4..11 = status sumber/beban.
  // Bit 4/5 warning V; 6/7 suspect V; 8/9 AC_OFF; 10/11 suspect I.
  uint16_t statusWord = static_cast<uint16_t>(hasil.bitmask_kualitas & 0x000F);
  if (hasil.warning_tegangan_sumber) statusWord |= (1U << 4);
  if (hasil.warning_tegangan_beban) statusWord |= (1U << 5);
  if (hasil.status_tegangan_sumber == STATUS_V_SUSPECT) statusWord |= (1U << 6);
  if (hasil.status_tegangan_beban == STATUS_V_SUSPECT) statusWord |= (1U << 7);
  if (hasil.status_tegangan_sumber == STATUS_V_AC_OFF) statusWord |= (1U << 8);
  if (hasil.status_tegangan_beban == STATUS_V_AC_OFF) statusWord |= (1U << 9);
  if (hasil.suspect_arus_sumber) statusWord |= (1U << 10);
  if (hasil.suspect_arus_beban) statusWord |= (1U << 11);
  mb.Ireg(REG_KUALITAS_DATA, statusWord);
}

void modbusTandaiSensorTidakValid() {
  // Empat bit kualitas = 1 menandakan semua kanal tidak valid.
  // Nilai numerik register dibiarkan pada sampel valid terakhir.
  mb.Ireg(REG_KUALITAS_DATA, 0x000F);
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

// Status PLC valid selama HREG7 diperbarui dalam batas waktu.
bool modbusModeOperasiPLCValid() {
  uint32_t waktuUpdate = 0;
  portENTER_CRITICAL(&muxModeOperasiPLC);
  waktuUpdate = waktuModeOperasiPLC;
  portEXIT_CRITICAL(&muxModeOperasiPLC);
  return waktuUpdate != 0 &&
      static_cast<uint32_t>(millis() - waktuUpdate) <= MODE_OPERASI_PLC_TIMEOUT_MS;
}

uint16_t modbusBacaModeOperasiPLC() {
  uint16_t mode = MODE_OPERASI_UNKNOWN;
  uint32_t waktuUpdate = 0;
  portENTER_CRITICAL(&muxModeOperasiPLC);
  mode = modeOperasiPLC;
  waktuUpdate = waktuModeOperasiPLC;
  portEXIT_CRITICAL(&muxModeOperasiPLC);
  if (waktuUpdate == 0 ||
      static_cast<uint32_t>(millis() - waktuUpdate) > MODE_OPERASI_PLC_TIMEOUT_MS) {
    return MODE_OPERASI_UNKNOWN;
  }
  return mode;
}

bool modbusEstimasiComFailLokal() {
  // Fail-safe: COM stays FAIL until PLC has written HREG7 in the current timeout window.
  // Reads of sensor registers or other Modbus traffic alone do not prove the HREG7 integration.
  return !modbusModeOperasiPLCValid();
}

unsigned long modbusMsSejakAksesTerakhir() {
  return millis() - waktuAksesTerakhir;
}

unsigned long modbusJumlahAksesRegister() {
  return jumlahAksesRegister;
}
