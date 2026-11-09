# Skema Firebase Realtime Database — SCADA LBS

Firebase options Flutter menunjuk project scada-lbs dan RTDB URL yang disepakati. Backend gateway memakai Firebase Admin SDK dari lingkungan server; service-account tidak boleh disimpan di repository atau APK.

## Users

    /users/{uid}
      email: string
      displayName: string
      role: "manager" | "operator"
      isActive: boolean

UID adalah Firebase Authentication UID. Flutter hanya membaca profil UID sendiri. Profil dibuat/diubah pemilik/admin. Gateway tidak memakai profil gateway di node users.

## Commands

    /commands/{commandId}
      target: "LBS_01"
      action: "OPEN" | "CLOSE"
      created_at: Firebase ServerValue.timestamp
      created_by_uid: Auth UID
      created_by_name: profile displayName
      status: "PENDING"

Hanya Operator aktif yang dapat menambahkan request. Request bersifat immutable dari sisi Flutter. PENDING berarti hanya request tercatat, bukan perintah diterima ESP32 atau posisi LBS berubah.

## Command results

    /command_results/{commandId}
      command_id: string
      status: RECEIVED | EXECUTING | SUCCEEDED | FAILED | REJECTED | EXPIRED | INDETERMINATE
      updated_at: server epoch milliseconds
      detail: string
      dispatch_state: validating | dry_run | publishing | sent | interrupted | rejected

RECEIVED pada mode dry-run berarti gateway memvalidasi request tetapi tidak mempublikasikan perintah. EXECUTING berarti gateway mengirim MQTT PUBLISH; itu bukan acknowledgement perangkat. INDETERMINATE berarti hasil pengiriman tidak dapat dipastikan setelah gangguan/restart. SUCCEEDED hanya boleh digunakan setelah acknowledgement berkorelasi dan feedback posisi aktual dikonfirmasi oleh auxiliary contact melalui PLC.

## Telemetry

    /telemetry/{deviceId}/latest
      device_id, timestamp, device_ts_ms, received_at
      v_sumber, v_beban, i_sumber, i_beban, kualitas
      status_lru, status_com, status_lbs

Gateway MVP menimpa satu record latest agar RTDB tidak tumbuh tanpa batas dari telemetry setiap 5 detik. Status LBS tetap UNKNOWN karena firmware saat ini belum mempublikasikan independent auxiliary-contact feedback. Gateway tidak boleh menyimpulkan status posisi dari command terakhir atau register request.

## Data activity

    /data_activity/{entryId}
      timestamp, jenis, keterangan, oleh_uid, oleh_nama, sumber, command_id?

Data Activity, telemetry, dan command results adalah backend-owned. Flutter hanya membaca ketiganya. Firebase Admin SDK melewati RTDB Security Rules; karena itu gateway melakukan validasi ulang UID, role, isActive, target, action, timestamp/expiry, dan idempotency.

Rules lokal berada di flutter_app_skeleton/database.rules.json. File lokal bukan aturan live sampai pemilik menguji Rules Emulator dan mempublikasikannya secara manual.
