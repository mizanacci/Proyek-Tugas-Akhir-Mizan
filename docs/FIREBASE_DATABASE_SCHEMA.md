# Skema Firebase Realtime Database — SCADA LBS

Firebase options harus menunjuk project `scada-lbs` dan RTDB URL yang disepakati.
Options masih harus digenerate pemilik setelah Android app terdaftar.

## Users

```text
/users/{uid}
  email: string                 # informational; not an authorization key
  displayName: string
  role: "manager" | "operator"
  isActive: boolean
```

The UID is the Firebase Authentication UID. Flutter reads only its own profile;
profile creation and changes are owner/admin operations. No gateway identity is
stored under `/users`; the backend uses Firebase Admin SDK separately.

## Commands

```text
/commands/{commandId}
  target: "LBS_01"
  action: "OPEN" | "CLOSE"
  created_at: ServerValue.timestamp
  created_by_uid: Auth UID
  created_by_name: profile displayName
  status: "PENDING"
```

Only an active operator can append a new command. Managers can read commands but
cannot create or modify them. `PENDING` only means the request was recorded; it
is not an execution result or actual position. Gateway must validate identity,
target, expiry, idempotency, and policy again before forwarding to the control
interface. The PLC retains interlocks and protection.

## Backend-owned data

```text
/command_results/{commandId}
  command_id: string
  status: RECEIVED | EXECUTING | SUCCEEDED | FAILED | REJECTED | EXPIRED
  updated_at: server epoch milliseconds
  detail: string

/telemetry/{deviceId}/{entryId}
  device_id, timestamp, device_ts_ms, received_at
  v_sumber, v_beban, i_sumber, i_beban, kualitas
  status_lru, status_com, status_lbs

/data_activity/{entryId}
  timestamp, jenis, keterangan, oleh_uid, oleh_nama, sumber, command_id?
```

The separate gateway/backend writes telemetry, command results, and activity.
Flutter reads these paths through Realtime Database streams and never writes
them. Admin SDK bypasses RTDB Rules, so backend validation and service-account
handling remain server responsibilities. No gateway implementation exists in
this workspace.

The UI queries the newest telemetry entry by `timestamp` and the latest 100
activity entries. RTDB indexes are declared in `database.rules.json`.
