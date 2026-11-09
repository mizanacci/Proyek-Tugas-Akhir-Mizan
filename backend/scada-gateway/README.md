# SCADA-LBS Gateway MVP

Long-running Node.js worker between Firebase Realtime Database and HiveMQ Cloud.

## Current scope

- Listens to new requests at /commands.
- Revalidates command shape, age, creator profile, active state, and Operator role.
- Writes backend-owned /command_results and /data_activity records.
- Subscribes to the existing ESP32 sensor, LRUFail, and COMFail MQTT topics.
- Writes one latest sample at /telemetry/LBS_01/latest (bounded storage).
- Keeps physical LBS position as UNKNOWN; the current firmware has no independent auxiliary-contact feedback topic.

## Safety default

Command dispatch is disabled by default. With COMMAND_DISPATCH_ENABLED=false, valid requests are validated and recorded as RECEIVED with dispatch_state=dry_run; no MQTT control message is sent.

Do not enable dispatch until the actual ladder/wiring truth table has confirmed whether OPEN maps to NO or NC. If enabled, both OPEN_COMMAND_VALUE and CLOSE_COMMAND_VALUE must be explicitly configured as NO or NC. The service requires fresh sensor data, NORMAL LRU status, fresh NORMAL COM status, and a live MQTT connection before attempting a publish.

Even when the MQTT PUBLISH callback succeeds, the result remains EXECUTING. It does not prove ESP32 receipt, PLC execution, or physical LBS movement. A publish interruption is recorded as INDETERMINATE and is never retried automatically. The current firmware does not publish a command ID acknowledgement or LBS auxiliary-contact feedback, so this MVP never writes SUCCEEDED.

The MVP is for one running instance only. Do not configure multiple replicas or autoscaling.

## Prerequisites

- Node.js 26 LTS.
- A Firebase Admin identity with database access to the scada-lbs RTDB only.
- A dedicated HiveMQ account with TLS access and ACLs limited to the three telemetry/status topics and the command topic.
- No credentials in the repository, APK, or chat.

Firebase Admin uses Application Default Credentials. For local development, create a service-account file in a private folder outside Git and point GOOGLE_APPLICATION_CREDENTIALS to it. On a host, use workload identity or a mounted secret file. The service account key must never be committed.

## Local run

From this directory:

1. Copy .env.example to .env.
2. Set FIREBASE_DATABASE_URL, GOOGLE_APPLICATION_CREDENTIALS, MQTT_URL, MQTT_USERNAME, MQTT_PASSWORD, and a unique MQTT_CLIENT_ID.
3. Leave COMMAND_DISPATCH_ENABLED=false.
4. Install dependencies with npm install.
5. Run unit tests with npm test.
6. Start the worker with node --env-file=.env src/index.js.

The service does not need a public HTTP endpoint. It must run continuously. Render Background Worker is one possible deployment target; use exactly one instance and store Firebase/MQTT secrets as platform secrets. Do not deploy from this PR.

## RTDB contract

- Reads /commands and /users/{created_by_uid}.
- Writes /command_results/{commandId}.
- Writes /telemetry/LBS_01/latest.
- Appends /data_activity/{pushId}.

The Flutter client reads these records. Firebase Admin SDK bypasses RTDB Rules, so the gateway revalidates authorization and validates every incoming record itself.

## Command result semantics

- RECEIVED: validated request received by gateway. In dry-run mode, no MQTT command is published.
- EXECUTING: gateway submitted the MQTT QoS 0 PUBLISH; device/PLC/position feedback is not confirmed.
- REJECTED: malformed request, invalid/inactive creator, non-Operator, or device readiness check failed.
- EXPIRED: request exceeded COMMAND_MAX_AGE_MS before gateway processing.
- INDETERMINATE: process restarted or connection failed during/after publish; delivery and physical state cannot be known. Verify the field device before issuing another request.
- SUCCEEDED is reserved for a future protocol with an independent, correlated device acknowledgement and confirmed auxiliary-contact position feedback.

## Next protocol work

The firmware currently accepts { "command": "NO" } or { "command": "NC" } on scada/mizan/cmd/relay. It does not accept/return a command ID, publish a PLC handshake acknowledgement, or publish actual LBS position. Do not infer any of those signals. A later firmware/PLC change must define a correlated acknowledgement and independent position feedback before SUCCEEDED is supported.
