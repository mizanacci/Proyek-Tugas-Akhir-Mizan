# SCADA LBS Migration Baseline

Audit date: 2026-11-09

## Workspace

- Workspace root: `D:\Proyek Tugas Akhir, Konversi Mata Kuliah dan Magang PLN UP2D\Proyek_TA_SCADA_LBS`
- Project root: `Proyek-Tugas-Akhir-Mizan-main`
- Flutter app root: `Proyek-Tugas-Akhir-Mizan-main/flutter_app_skeleton`
- Source snapshot and source repository are outside the edit scope. No ZIP or source repository files were changed.
- Git metadata is absent at both workspace root and project root; `git status --short --branch` cannot be used to distinguish pre-existing edits.

## Baseline findings and planned actions

| Area | Actual state before edits | Action |
|---|---|---|
| Firebase target | `.firebaserc` default is `scada-lbs`; `firebase_options.dart` is fail-fast placeholder; no app-specific options or `android/app/google-services.json` were found | Keep placeholder until owner registers Android app and runs FlutterFire; pin RTDB URL in app service and verify generated options before Firebase initialization |
| Android identity | Baseline Gradle namespace/applicationId and `MainActivity.kt` used `com.example.scada_mizan_app` | Updated Gradle identity and Kotlin package/path to `com.mizan.scada_lbs` |
| Authentication | Login UI uses Email/Password; service also contains unused Google Sign-In and account-creation methods; profile role is checked but profile email is not | Remove unused sign-in/sign-up code and dependency; require exact normalized Auth/profile email match and explicit manager/operator role |
| RTDB | Active paths are `/users/{uid}` and `/data_activity`; `/settings` and `/scada_data` occur only in unused compatibility methods | Keep default-deny rules for users and append-only Data Activity; document unused methods and rules coverage |
| MQTT | HiveMQ TLS port 8883; telemetry/status/relay topics and freshness/subscription gates are in `lib/services/mqtt_service.dart` and `event_logger.dart` | Preserve broker contract and control/PLC/firmware behavior; document that client-side credentials are extractable and logging is not 24/7 |
| Platforms | Android is present; iOS, macOS, Linux, Windows and Web contain Flutter scaffolding. iOS includes app icons and runner tests | No platform folders removed pending explicit confirmation because this would delete files; record as Android-only cleanup blocker |
| Local tooling | Flutter 3.47.5 / Dart 3.13.4, FlutterFire CLI, Firebase CLI and ADB are installed. Focused test could not start because Windows symlink support is disabled | Run prescribed checks; report any resulting toolchain blocker without claiming success |
| Live Firebase | Current Console state is not verified in this workspace; prior documentation refers to a supplied screenshot only | No Console, Auth, RTDB, rules deployment, or cloud deletion actions |

## Pre-edit SHA-256

Hashes were captured before workspace edits on 2026-11-09. Paths are relative to the project root.

| File | SHA-256 |
|---|---|
| `flutter_app_skeleton/pubspec.yaml` | `6640764557DD1101DAAB38130EE048EC970BE8EA03E3EA5CD205166207FE9A13` |
| `flutter_app_skeleton/pubspec.lock` | `B2B3B9C08FF5E455B1358046FA55ADB0AB37C55669CCE06D764DF60E72893C24` |
| `flutter_app_skeleton/database.rules.json` | `6376A4C89FDE0373713477C25ACCCFD4820DAF919486E720787D86DADFCBEF6A` |
| `flutter_app_skeleton/firebase.json` | `903DACC2D9FB8BC6E5DDF43287288E5A7A4222E24889A9533EA85685A3B6F6C3` |
| `flutter_app_skeleton/.firebaserc` | `521CB9C12EB2A463374218EE7A94C176EFDA9D766C4BE39EAD5626C963510909` |
| `flutter_app_skeleton/.gitignore` | `C69C05E4553423D856F58AF887F80543324D5B6AB1CD9261EEDFA172B4FCB1B9` |
| `flutter_app_skeleton/lib/main.dart` | `0B93979A87475554815012ED1E1E438000F4C44A1E6EC03F26B7075668C68898` |
| `flutter_app_skeleton/lib/firebase_options.dart` | `D1CAF47278E8176B5A46BC0B8F9C904E9F141E9ED3D75A99A8E664E704393D94` |
| `flutter_app_skeleton/lib/services/firebase_service.dart` | `3B1C06A99BF1B0FB49D410F269A379858A7442356AFBAFC94C90E410C0CD4C01` |
| `flutter_app_skeleton/lib/services/mqtt_service.dart` | `C67BB05B5C07DFF1CDFF7F759BAC07F85714CCF0A87011A7E8D1D8172E19CCEF` |
| `flutter_app_skeleton/lib/services/event_logger.dart` | `BB87E61BC344F5AFD246E1AAB4702717302E260845E315DB2B3B9851B973AE48` |
| `flutter_app_skeleton/test/firebase_role_test.dart` | `28F99BE9C92268C5CA09E5FB262A6E7ECC13A321C5676D4F35F681475AE0427E` |
| `flutter_app_skeleton/android/app/build.gradle.kts` | `F2946D7E5A8373D84E5459EE05262B16373A1724C9074EE6731832173ED84B64` |
| `flutter_app_skeleton/android/app/src/main/AndroidManifest.xml` | `E61C69A650073CA10724FBE6A37AE6DED515F154EEB8CFDECDA34DB516F85B16` |
| `flutter_app_skeleton/android/app/src/main/kotlin/com/example/scada_mizan_app/MainActivity.kt` | `73858FB4C7F1CB2D872A2DF7B77E0C3F19EC4B0D30EB117FD2E3E19CFF2FB81C` |
