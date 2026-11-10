# Physical IoT Test Readiness

Status target tahap ini: telemetry ESP32-S3 ke Firebase melalui Gateway. Kontrol fisik LBS tetap dilarang.

## Checklist

- [ ] Build firmware ESP32-S3 berhasil.
- [ ] `config.h` lokal cocok dengan ESP32-S3 yang digunakan.
- [ ] Pin WiFi, MQTT, dan serial tidak diubah.
- [ ] MQTT Client ID ESP32 dan Gateway berbeda.
- [ ] HiveMQ ACL mengizinkan ESP32 publish sensor dan status.
- [ ] HiveMQ ACL mengizinkan ESP32 subscribe command.
- [ ] HiveMQ ACL mengizinkan Gateway subscribe telemetry.
- [ ] HiveMQ ACL mengizinkan Gateway publish command, walaupun dispatch tetap nonaktif.
- [ ] Tidak ada retained payload lama pada `scada/mizan/cmd/relay`.
- [ ] Gateway memiliki kredensial service account lokal di luar Git.
- [ ] `.env` Gateway berisi URL database dan kredensial HiveMQ yang benar.
- [ ] `COMMAND_DISPATCH_ENABLED=false`.
- [ ] Serial Monitor 115200 siap digunakan.
- [ ] ESP32 dapat publish telemetry sekitar setiap 5 detik.
- [ ] Gateway dapat memperbarui `/telemetry/LBS_01/latest`.
- [ ] Status LRU, COM, dan LBS ditafsirkan sesuai makna sebenarnya.
- [ ] Pengujian pertama tidak mengaktifkan output aktuator/LBS.
- [ ] Sistem kelistrikan dan pengkabelan mengikuti prosedur isolasi dan keselamatan tempat pengujian.

## Safety gates

Firmware berlangganan `scada/mizan/cmd/relay`. Hapus atau verifikasi retained command lama sebelum ESP32 dinyalakan karena callback PubSubClient belum memeriksa flag retained.

Tahap pertama hanya menguji telemetry dan status komunikasi. Jangan mengirim command `OPEN` atau `CLOSE`.

Sebelum checklist di atas lengkap, jangan menghubungkan output aktuator/LBS. Build firmware dan verifikasi wiring harus dilakukan pada perangkat yang benar-benar digunakan.
