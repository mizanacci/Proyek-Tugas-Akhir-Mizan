# SCADA LBS Firebase Rules

Rules file: `flutter_app_skeleton/database.rules.json`. This is a local proposal;
it has not been deployed or run in Firebase Rules Emulator. Review it against the
current project before manual publication.

## Profile and roles

`/users/{uid}` contains `email`, `displayName`, `role`, and `isActive`. The client
reads only its own UID. Client writes are always denied. Access requires
`isActive == true` and an exact role of `manager` or `operator`.

## Authorization matrix

| Path | Unauthenticated | Active manager | Active operator | Flutter write |
|---|---|---|---|---|
| `/users/{uid}` | Denied | Read own UID only | Read own UID only | Denied |
| `/commands/{commandId}` | Denied | Read | Read; create new request only | Operator create only |
| `/command_results/{commandId}` | Denied | Read | Read | Denied |
| `/telemetry/{deviceId}` | Denied | Read | Read | Denied |
| `/data_activity/{entryId}` | Denied | Read | Read | Denied |
| Any other path | Denied | Denied | Denied | Denied |

The command write rule allows only a new child, active operator UID, target
`LBS_01`, action `OPEN` or `CLOSE`, matching `created_by_name`, `PENDING`, and a
server timestamp equal to rules `now`. Unknown command fields are rejected.
Updates and deletes are denied. A successful client write means only that a
request was recorded; it does not mean the gateway or PLC executed it.

Telemetry, command results, and activity are backend-owned. No gateway identity
is added to `/users`; the Gateway Firebase app uses
`databaseAuthVariableOverride.uid = scada-lbs-gateway`, so its RTDB operations
are evaluated as that service identity. Backend code must independently validate
operator UID/role/active state, target, action, command age, idempotency,
duplicate handling, and gateway connectivity. PLC permissives, interlocks, and
protection remain authoritative.

Rules `.write` grants are separate from `.validate`; validation never grants
authorization. Parent root access stays denied. The scoped Gateway identity
must still use server-side validation and access controls.

## Manual test matrix

| Test | Expected result |
|---|---|
| Unauthenticated profile/data read | Denied |
| Active manager reads own profile, telemetry, results, commands and activity | Allowed |
| Active operator reads own profile, telemetry, results, commands and activity | Allowed |
| Inactive or unknown-role profile reads operational data | Denied |
| UID A reads `/users/{UID_B}` or changes any profile | Denied |
| Manager creates or changes a command | Denied |
| Active operator creates exact valid `LBS_01` OPEN/CLOSE request with own UID | Allowed |
| Operator uses another UID/name, target/action outside allowlist, non-PENDING state, bad timestamp, missing/extra field | Denied |
| Update/delete existing command | Denied |
| Flutter writes telemetry, command results, or activity | Denied |
| Read/write any unlisted path | Denied |

Run the cases with Firebase Emulator/Rules Unit Testing before the owner manually
publishes. No cloud deploy or live rules mutation was performed.
