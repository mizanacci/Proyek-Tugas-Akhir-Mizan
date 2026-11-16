# Next Steps

## Prioritas 1 — CXT and hardware

1. Cari file V3 SingleCoil asli di folder proyek, cloud drive, atau mesin lain.
2. Jika tersedia, salin ke folder PLC handoff dan buat checksum.
3. Buka file V3 dengan CX-Programmer, bandingkan rungs error V3.2, dan fokus pada operand memory area tidak valid.
4. Tetapkan ulang alamat D dan W hanya jika ada definisi valid dari manual perangkat dan hasil program check.
5. Jangan mengubah alamat hanya demi membuat file V3.3 terlihat "selesai".

## Prioritas 2 — hardware validation

1. Verifikasi DB9 CP1E, MAX3232, power, ground, dan serial port.
2. Pastikan pin 2/3/9 sesuai dengan model CP1E N30.
3. Uji komunikasi Modbus RTU ESP32 ↔ PLC.
4. Pastikan HREG7 TTL/heartbeat berfungsi pada PLC actual.
5. Uji LRUFail vs COMFail secara terpisah.

## Prioritas 3 — firmware and sensor

1. Jaga baseline ADC internal.
2. Jangan mengembalikan ADS1115 tanpa kebutuhan dan pembuktian.
3. Validasi hasil RMS ZMPT101B dan ACS712 dengan alat ukur yang sah.
4. Catat setiap perubahan koefisien sensor dengan data pengukuran.

## Prioritas 4 — Gateway and Firebase

1. Tetap dry-run.
2. Jangan melakukan command dispatch live.
3. Pastikan status LBS tidak diinfer dari command ke relay.
4. Simpan data raw dan status yang diperlakukan secara eksplisit.

## Prioritas 5 — Flutter and UI

1. Pertahankan arsitektur minimal dan mengadopsi logika status sensor yang jelas.
2. Tambahkan status `NORMAL|SUSPECT|UNKNOWN` di UI bila diperlukan.
3. Hindari perubahan visual besar tanpa kebutuhan.

## Prioritas 6 — handoff and documentation

1. Simpan semua catatan validasi di docs/.
2. Simpan file CXT asli dan hasil checksum.
3. Selalu jelaskan mana yang sudah dibuktikan dan mana yang belum.
4. Jaga kualitas ketelitian pada semua perubahan.
