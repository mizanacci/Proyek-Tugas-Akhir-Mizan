# Diagnostik MQTT

Panel pada Monitoring dan Data Activity menampilkan status broker, ACK
subscription, jumlah payload sensor diterima/diproses, waktu pesan terakhir,
freshness, dan error parsing. MQTT `connected` tidak membuktikan Firebase write
berhasil.

Client ID memakai ID acak per instalasi yang disimpan di SharedPreferences.
ID stabil saat reconnect dan berbeda antar instalasi; UID/email/password tidak
dimasukkan ke Client ID. Kredensial tetap berasal dari konfigurasi lokal
`app_secrets.dart` dan tidak boleh dicetak ke log.

Flutter menggunakan TLS dengan trust store platform. Firmware memakai CA root
ISRG Root X1 dan TLS port 8883; pembaruan CA perlu dilakukan sebelum masa berlaku
sertifikat trust anchor berakhir. Keduanya tidak menonaktifkan verifikasi TLS.

Firmware mempublikasikan data sensor dengan PubSubClient QoS 0 tiap 5 detik.
`publish()` true hanya menunjukkan library menerima operasi publish; bukan bukti
subscriber Flutter menerima pesan. QoS 0 dapat kehilangan sampel ketika
subscriber tidak aktif. Auto-reconnect Flutter mengaktifkan resubscribe dan
memasang kembali listener `updates` setelah reconnect.

Log aman untuk troubleshooting: `[MQTT] Terhubung`, `Subscription aktif`,
`Payload sensor diproses`, `Auto-reconnect dimulai`, dan `PUBLISH SENSOR
ACCEPTED/FAILED`. Jangan mengaktifkan log payload lengkap atau kredensial.