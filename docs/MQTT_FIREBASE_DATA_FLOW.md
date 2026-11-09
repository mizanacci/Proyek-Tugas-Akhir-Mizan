# Alur Data SCADA ke Firebase

    ESP32-S3
      ├─ MQTT sensor: scada/mizan/data/sensor (QoS 0, setiap 5 detik)
      ├─ LRU status: scada/mizan/status/lrufail (retained)
      ├─ COM status: scada/mizan/status/comfail (retained + heartbeat)
      └─ subscribe command: scada/mizan/cmd/relay
                  │
                  ▼ TLS MQTT
             HiveMQ Cloud
                  │
                  ▼
       SCADA Gateway (Node.js worker)
        ├─ telemetry parser -> /telemetry/LBS_01/latest
        ├─ command validator <- /commands
        ├─ MQTT publisher -> command topic (disabled by default)
        ├─ command results -> /command_results
        └─ audit activity -> /data_activity
                  ▲
                  │ Firebase Admin SDK
             Firebase RTDB
                  ▲
                  │ read streams / pending request
             Flutter SCADA-LBS
       Firebase Auth + Manager/Operator roles

Flutter tidak subscribe HiveMQ dan tidak menulis telemetry, command results, atau Data Activity. Hanya Operator aktif yang dapat membuat request PENDING di /commands.

Gateway MVP berada di backend/scada-gateway. Default COMMAND_DISPATCH_ENABLED=false; valid request dicatat sebagai RECEIVED dengan dispatch_state dry_run dan tidak dipublikasikan. PUBLISH hanya dapat diaktifkan setelah mapping OPEN/CLOSE ke NO/NC dikonfirmasi dari ladder/wiring. Bahkan saat MQTT PUBLISH berhasil dikirim, result tetap EXECUTING sampai protokol acknowledgement dan feedback posisi aktual tersedia.

Status posisi LBS ditulis UNKNOWN karena firmware aktif belum mengirim auxiliary-contact feedback. LRUFail dan COMFail merupakan status link; COMFail dari firmware adalah estimasi watchdog ESP32, bukan status internal PLC.

Service harus berjalan terus sebagai satu instance worker. Firebase Admin credentials dan HiveMQ account hanya disimpan sebagai server secrets. Gateway belum dideploy atau diuji terhadap Firebase/HiveMQ live dalam perubahan ini.
