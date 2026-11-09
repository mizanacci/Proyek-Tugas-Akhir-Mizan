# SCADA LBS Firebase/Android Implementation Report

Date: 2026-11-09

## Scope and current architecture

- Workspace: `Proyek_TA_SCADA_LBS`; project: `Proyek-Tugas-Akhir-Mizan-main`.
- Flutter app: `Proyek-Tugas-Akhir-Mizan-main/flutter_app_skeleton`.
- Android ID: `com.example.scada_mizan_app` → `com.mizan.scada_lbs`.
- Target project: `scada-lbs`; RTDB URL:
  `https://scada-lbs-default-rtdb.asia-southeast1.firebasedatabase.app`;
  region `asia-southeast1`. Owner-provided values, not live Console verification.
- Git metadata is absent at workspace and project roots. The original migration
  pre-edit hashes are in `SCADA_LBS_MIGRATION_BASELINE.md`.

Flutter authenticates with Email/Password, reads its own `/users/{uid}` profile,
and requires exact `manager`/`operator`, `isActive == true`, and non-empty
`displayName`. Email is informational, not the authorization key. User UIDs and
emails are not hardcoded in application code or the seed example.

`ScadaService` reads latest telemetry, command results, and activity from RTDB.
An active operator can append a `PENDING` command request for `LBS_01`; managers
cannot create commands. Flutter no longer publishes a relay command directly or
writes telemetry, command results, or activity. Legacy writer API signatures
remain deprecated and throw `UnsupportedError`; direct MQTT relay API remains
deprecated and always returns false.

## Files changed

- `flutter_app_skeleton/lib/models/user_profile.dart` and
  `lib/models/scada_data.dart`: active profile, telemetry, and command result models.
- `flutter_app_skeleton/lib/services/firebase_service.dart`:
  UID/profile session checks and legacy write denial.
- `flutter_app_skeleton/lib/services/scada_service.dart`: role-gated command
  request creation and RTDB read streams.
- `flutter_app_skeleton/lib/services/event_logger.dart` and `lib/main.dart`:
  active-profile session validation; no MQTT connection or backend-owned writes.
- `flutter_app_skeleton/lib/screens/monitoring_screen.dart`,
  `kontrol_monitoring_lbs_screen.dart`, and `data_activity_screen.dart`:
  Firebase telemetry/results/activity integration while retaining existing screens.
- `flutter_app_skeleton/lib/widgets/integration_diagnostics_panel.dart`:
  Firebase-only status; removed client write-test control.
- `flutter_app_skeleton/lib/services/mqtt_service.dart`: old relay publisher is
  fail-closed; firmware/topic/payload code was not changed.
- `flutter_app_skeleton/database.rules.json`: default-deny; active-role reads;
  operator-only create command; no client writes to telemetry/results/activity.
- `flutter_app_skeleton/database.users.seed.example.json`: schema placeholders only.
- `flutter_app_skeleton/test/user_profile_test.dart` and
  `test/scada_service_test.dart`: profile, command policy, connection, telemetry,
  result, and stream tests.
- Setup/schema/security docs and app README were aligned to the gateway model.
- `ios/`, `macos/`, `linux/`, `windows/`, and `web/` were removed after owner
  approval: 119 scaffold files. Android, shared Dart/assets/tests, documentation,
  firmware, and PLC files remain.
- Flutter `.metadata` remains unchanged because it is tool-managed and explicitly
  says not to edit manually; its migration history still records the original
  platform scaffolds, but those target directories are absent.

No gateway/backend code exists in this workspace. Firebase Admin SDK credentials,
service accounts, and broker credentials are not part of the Flutter app. PLC
interlocks, permissives, and protection remain authoritative and were not changed.

## Security and backend boundary

RTDB rules are local only and have not been deployed or run in Firebase Rules
Emulator. They allow only active manager/operator reads and active operator
creation of an exact `LBS_01` OPEN/CLOSE request with `PENDING` and server time.
Admin SDK bypasses these rules; backend must repeat authorization, expiry,
idempotency, duplicate, target, action, and connectivity checks. A successful
Firebase write means only that a request was recorded, not that the gateway or
PLC executed it. Actual position is shown separately from command result status.

## Validation

Flutter 3.47.5 / Dart 3.13.4: `flutter pub get` PASS, `flutter analyze` PASS
(no issues), `flutter test` PASS (23 tests), and `flutter build apk --debug` PASS.
The APK manifest is package `com.mizan.scada_lbs`, activity
`com.mizan.scada_lbs.MainActivity`; artifact:
`flutter_app_skeleton/build/app/outputs/flutter-apk/app-debug.apk` (182,383,249
bytes). Firebase rules/config/seed files parse as JSON; no emulator validation
was run.

`flutter doctor -v` detects Android SDK 36/JDK 17 but reports Android licenses
not accepted. No Android device/emulator is connected, so the APK was not
installed and runtime was not tested. No command was sent to an LBS. Firebase
options remain a placeholder, app registration is unverified, and live Auth,
RTDB, Rules deployment, gateway/Admin SDK, and device feedback remain untested.

## Owner actions

1. Recheck Firebase Console values and confirm/register Android app
   `com.mizan.scada_lbs`.
2. Download its `google-services.json` and run
   `flutterfire configure --project=scada-lbs --platforms=android` locally.
3. Verify the existing manager/operator Auth users and create/update their
   `/users/{uid}` profiles with `displayName`, exact role, and `isActive: true`.
4. Review/test rules and publish manually.
5. Implement/review the separate gateway/backend, then verify command lifecycle,
   telemetry, results, and activity on a selected device.

Do not delete the old Firebase project until the new system passes login, RTDB,
backend, and device tests. Deleting it removes associated resources and data.
No cloud action, rules deployment, or project deletion was performed.
