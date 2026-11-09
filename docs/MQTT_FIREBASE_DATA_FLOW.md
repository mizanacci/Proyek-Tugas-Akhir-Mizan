# Alur Data SCADA ke Firebase

```mermaid
flowchart LR
  ESP[ESP32] -->|MQTT telemetry| Broker[HiveMQ Cloud]
  Broker -.->|subscriber belum tersedia| Gateway[SCADA Gateway]
  Gateway -.->|Firebase Admin SDK writes| RTDB[(Firebase RTDB)]
  App[Flutter] --> Auth[Firebase Auth]
  App -->|Manager/Operator reads| RTDB
  App -->|Operator only: PENDING OPEN/CLOSE| Commands[/commands]
  Commands -.->|processing belum tersedia| Gateway
  RTDB --> Telemetry[/telemetry]
  RTDB --> Results[/command_results]
  RTDB --> Activity[/data_activity]
```

Firmware mempertahankan MQTT untuk pertukaran data perangkat. Flutter tidak
subscribe HiveMQ dan tidak publish command relay. Runtime Flutter menggunakan
Firebase Authentication dan Realtime Database.

`EventLogger` hanya mengamati perubahan Firebase Auth dan validasi profil.
Monitoring membaca telemetry, Data Activity membaca activity, dan kedua role
membaca commands/results sesuai rules.

Hanya Operator aktif dapat membuat request baru pada `/commands` dengan status
`PENDING`. Flutter tidak menulis telemetry, command results, atau
`data_activity`; record tersebut harus ditulis backend tepercaya. `PENDING`
berarti request tercatat, bukan command dieksekusi. Backend/gateway belum
diimplementasikan atau diverifikasi dalam workspace ini.

Gateway dapat menjadi subscriber MQTT dan menggunakan Firebase Admin SDK untuk
menulis telemetry, command results, dan audit activity. Kredensial Admin dan
broker hanya berada di backend. PLC tetap memvalidasi interlock dan proteksi;
posisi aktual ditentukan oleh feedback telemetry, bukan status request.