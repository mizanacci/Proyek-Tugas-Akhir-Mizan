# Decisions That Must Not Change Without Evidence

## 1. Baseline ADC internal

Aktif dan tidak boleh diubah ke ADS1115 tanpa pembuktian hardware dan pengukuran baru.

## 2. Tegangan dan arus

- Tegangan normal: 200–230 V inklusif.
- Di luar rentang: SUSPECT.
- AC_OFF: standby, bukan gangguan otomatis.
- Arus SUSPECT hanya > 1.80 A.
- 1.80 A tetap NORMAL.
- 0 A valid tetap NORMAL/STANDBY.

## 3. Modbus

- ESP32 slave ID 1.
- UART2 9600 8N1.
- TX GPIO17, RX GPIO18.
- IREG0–IREG5 adalah offset 0–5.
- HREG6 = offset 6.
- HREG7 = offset 7.

## 4. PLC registers

- D110 = IREG0 tegangan sumber ×100.
- D111 = IREG1 tegangan beban ×100.
- D112 = IREG2 arus sumber ×1000.
- D113 = IREG3 arus beban ×1000.
- D114 = IREG4 quality/status bitmask.
- D115 = IREG5 LRUFail.
- D116 = HREG6 remote command.

## 5. HREG6 and HREG7

- 0 = no command / UNKNOWN.
- 1 = NO/OPEN.
- 2 = NC/CLOSE.
- PLC harus mengirim FC06 0 sebagai ACK setelah mengevaluasi command.
- HREG7 harus ditulis secara periodik.
- COM valid hanya bila heartbeat HREG7 diterima dalam timeout 5 detik.

## 6. Dry-run and safety

- COMMAND_DISPATCH_ENABLED harus false.
- Gateway harus DRY-RUN.
- Tidak mengaktifkan control relay lewat MQTT.
- Status LBS aktual tetap UNKNOWN tanpa auxiliary contact independen.

## 7. Firmware and config

- Jangan mengubah pin sensor, port UART, atau register tanpa mereview kebutuhan dan validasi hardware.
- Gunakan template `.env.example` dan `config.h.example` bukan konfigurasi secret/local.
- Jangan menambahkan file secret ke repositori.

## 8. Scope of changes

Perubahan yang bersifat teknis dan materially besar harus disertai bukti dari alat ukur, program check PLC, atau output build yang dapat dipercaya. Jangan mencampur perubahan karena alasan estetika saja.
