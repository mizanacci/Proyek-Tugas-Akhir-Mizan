# Hardware and Safety

## Pin ESP32-S3 aktif

- GPIO4 = ZMPT tegangan sumber
- GPIO5 = ZMPT tegangan beban
- GPIO6 = ACS712 arus sumber
- GPIO7 = ACS712 arus beban
- GPIO17 = UART2 TX ke MAX3232
- GPIO18 = UART2 RX dari MAX3232

## RS-232C CP1E

Sesuai baseline validasi yang ada, pin DB9 CP1E harus diperiksa secara manual:

- pin 2 = SD/TXD PLC
- pin 3 = RD/RXD PLC
- pin 9 = SG signal ground
- pin 5 bukan SG dan bukan ground sinyal yang aman dipakai untuk jalur 3-kabel.

Belum ada bukti hardware real yang mengonfirmasi konektor yang dipakai secara final. Semua wiring yang disarankan harus diverifikasi sebelum daya dihidupkan.

## Safety notes

- GPIO ESP32-S3 hanya untuk tegangan 3.3 V maksimum.
- Output sensor harus dijaga agar tidak melebihi batas pin ADC.
- Sensor AC harus dipasang hanya setelah seluruh sisi AC diputus dan zona aman.
- ACS712 harus diperlakukan sebagai sensor arus AC dan tidak boleh langsung dipastikan tanpa pembacaan referensi.
- MAX3232 harus dibumikan dengan benar dan ground sinyal harus konsisten.

## Batasan belum diverifikasi

- Konektor DB9 yang actual pada PLC dan modul MAX3232.
- Program ladder final V3 yang benar-benar lolos Program Check.
- Pengujian relay aktual dan auxiliary contact.
- Posisi LBS aktual di perangkat nyata.

## Status safety

- Baseline sensor internal ADC tetap dipertahankan.
- ADS1115 lama tidak dipakai lagi.
- Tidak ada upload firmware ke hardware aktual dalam paket handoff ini.
- Semua kegiatan hardware yang belum valid tetap harus dianggap sebagai pekerjaan lapangan berikutnya.
