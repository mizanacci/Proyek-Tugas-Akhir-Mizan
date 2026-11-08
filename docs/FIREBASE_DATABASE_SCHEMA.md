# Skema Firebase Realtime Database

Database URL dikonfigurasi pada `firebase_options.dart`; `FirebaseService`
menggunakan `FirebaseDatabase.instance.ref()` agar Auth dan operasi data memakai
aplikasi Firebase yang sama.

## Profil pengguna

```text
/users/{uid}/{email,nama,role}
```

Role `manager`/`operator` dibuat oleh admin. Client hanya dapat membaca profil
milik UID yang sedang login dan tidak dapat menulis atau menaikkan role sendiri.

## Aktivitas dan snapshot

```text
/data_activity/{pushId}
  timestamp       Firebase ServerValue.timestamp (urutan utama)
  received_at     epoch milliseconds dari Flutter
  device_ts_ms    millis() dari ESP32; bukan epoch
  jenis           PERINTAH | ALARM | STATUS | SCADA_UPDATE
  keterangan      deskripsi/status command
  oleh_uid        UID Auth pembuat record
  oleh_nama       nama tampilan
  sumber          mobile | mqtt
  v_sumber/v_beban/i_sumber/i_beban  angka sensor (SCADA_UPDATE)
  kualitas        bitmask kualitas sensor
  status_lru/status_com/status_lbs  status saat snapshot
```

Event command dibedakan sebagai `PUBLISHED` atau `REJECTED`. `PUBLISHED` hanya
berarti client MQTT menerima publish lokal; itu bukan konfirmasi broker, ESP32,
atau relay PLC.

Data Activity membaca `/data_activity`, mengurutkan `timestamp`, lalu membatasi
hasil terbaru. Rules menyertakan `.indexOn: ["timestamp"]`.

## Path lain

`/settings` dipertahankan untuk konfigurasi yang hanya boleh diubah Manager.
`/scada_data` tetap tersedia untuk kompatibilitas API lama; snapshot aktif tetap
ditulis ke `/data_activity`.