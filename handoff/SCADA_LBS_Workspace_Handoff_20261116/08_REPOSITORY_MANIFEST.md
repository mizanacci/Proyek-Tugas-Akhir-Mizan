# Repository Manifest

## Branch and base

- Current branch: handoff/scada-lbs-workspace-20261116
- Base branch: release/scada-lbs-internal-adc-20261116
- Base commit: 92ec869ba368c6ee946af31c6b2860a1f25dd5d0
- Starting handoff commit: dd14e3ff50d0aae4a7d4e1799ea388943a8abf4d
- Date: 2026-11-16

## Folder structure

- firmware_esp32/
- backend/scada-gateway/
- flutter_app_skeleton/
- docs/
- review_claude_modbus/
- .github/
- handoff/SCADA_LBS_Workspace_Handoff_20261116/

## Important project files

- firmware_esp32/README.md
- firmware_esp32/src/config.h.example
- firmware_esp32/src/main.cpp
- firmware_esp32/src/modbus_slave.cpp
- firmware_esp32/src/sensors.cpp
- backend/scada-gateway/src/domain.js
- backend/scada-gateway/src/index.js
- backend/scada-gateway/src/telemetry-ingestor.js
- flutter_app_skeleton/lib/main.dart
- flutter_app_skeleton/lib/models/scada_data.dart
- flutter_app_skeleton/lib/screens/kontrol_monitoring_lbs_screen.dart
- docs/SCADA_CP1E_V4_MODBUS_CHANGELOG.md
- review_claude_modbus/uji_modbus_simulasi/SCADA_CP1E_Mizan_Modbus_Revision_V4_InternalADC.cxt

## Included files

Files included in handoff archive are the project source, documentation, and safe templates only. Build outputs, secrets, and local config remain excluded.

## Excluded files

- .git/
- .pio/
- .dart_tool/
- node_modules/
- build/
- .gradle/
- .env
- config.h
- service-account JSON
- Firebase private keys
- token / secret files
- generated APK/AAB
- backup files containing local secrets
- local logs and temp files

## CXT files included

- `review_claude_modbus/uji_modbus_simulasi/SCADA_CP1E_Mizan_Rev.cxt`
- `review_claude_modbus/uji_modbus_simulasi/SCADA_CP1E_Mizan_Modbus_Revision_V4_InternalADC.cxt`

The requested V2/V3/V3.1/V3.3 files were not present in the workspace at packaging time. V3.2 was no longer present in Downloads at the final check. No replacement files were fabricated.

SHA-256 values for the ZIP and primary handoff documents are recorded in the sibling `handoff/SHA256SUMS.txt` file after packaging.

## Notes

- The local workspace still includes some user-owned uncommitted files such as firebase rules, config.h, and backup files. Those are intentionally not committed in the handoff branch.
- This handoff is a packaging artifact, not a replacement for the original live workspace.
