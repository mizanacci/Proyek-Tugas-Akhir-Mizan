# Firebase Security Rules — SCADA LBS

This document is superseded by
[SCADA_LBS_FIREBASE_RULES.md](SCADA_LBS_FIREBASE_RULES.md), which matches the
current client/backend ownership model and `flutter_app_skeleton/database.rules.json`.

The current local rules keep root access denied, permit active manager/operator
reads, and allow only an active operator to append a constrained command request.
Flutter cannot write profiles, telemetry, command results, or activity. The
separate gateway uses Firebase Admin SDK and must enforce its own validation
because Admin SDK bypasses RTDB Rules.

No rules were deployed or tested against the live project. The project owner must
compare with current Console rules, run the Rules Emulator matrix, review the
command policy, and publish manually. Never make the database public to resolve
an integration error.
