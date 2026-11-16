import 'package:flutter_test/flutter_test.dart';
import 'package:scada_mizan_app/models/scada_data.dart';

Map<String, Object?> telemetryPayload([
  Map<String, Object?> overrides = const {},
]) {
  return {
    'device_id': 'LBS_01',
    'timestamp': 1000,
    'device_ts_ms': 900,
    'received_at': 950,
    'v_sumber': 220.0,
    'v_beban': 219.0,
    'i_sumber': 0.0,
    'i_beban': 0.0,
    'kualitas': 0,
    'status_lru': 'NORMAL',
    'status_com': 'NORMAL',
    'status_lbs': 'UNKNOWN',
    ...overrides,
  };
}

void main() {
  test('accepts all four PLC operation modes', () {
    const modes = ['UNKNOWN', 'STANDBY', 'RUN', 'INVALID'];

    for (final mode in modes) {
      final telemetry = ScadaTelemetry.fromValue(
        'LBS_01',
        telemetryPayload({
          'mode_operasi': mode,
          'mode_operasi_valid': true,
        }),
      );

      expect(telemetry.operationMode, mode);
      expect(telemetry.operationModeValid, isTrue);
    }
  });

  test('legacy telemetry defaults to UNKNOWN and invalid mode', () {
    final telemetry = ScadaTelemetry.fromValue(
      'LBS_01',
      telemetryPayload(),
    );

    expect(telemetry.operationMode, 'UNKNOWN');
    expect(telemetry.operationModeValid, isFalse);
  });

  test('accepts UNKNOWN while PLC mode update is not valid', () {
    final telemetry = ScadaTelemetry.fromValue(
      'LBS_01',
      telemetryPayload({
        'mode_operasi': 'UNKNOWN',
        'mode_operasi_valid': false,
      }),
    );

    expect(telemetry.operationMode, 'UNKNOWN');
    expect(telemetry.operationModeValid, isFalse);
  });

  test('rejects unsupported or incorrectly typed operation modes', () {
    expect(
      () => ScadaTelemetry.fromValue(
        'LBS_01',
        telemetryPayload({
          'mode_operasi': 'MAINTENANCE',
          'mode_operasi_valid': true,
        }),
      ),
      throwsFormatException,
    );

    expect(
      () => ScadaTelemetry.fromValue(
        'LBS_01',
        telemetryPayload({
          'mode_operasi': 2,
          'mode_operasi_valid': true,
        }),
      ),
      throwsFormatException,
    );

    expect(
      () => ScadaTelemetry.fromValue(
        'LBS_01',
        telemetryPayload({
          'mode_operasi': 'RUN',
          'mode_operasi_valid': 'true',
        }),
      ),
      throwsFormatException,
    );

    expect(
      () => ScadaTelemetry.fromValue(
        'LBS_01',
        telemetryPayload({
          'mode_operasi': null,
          'mode_operasi_valid': true,
        }),
      ),
      throwsFormatException,
    );
  });

  test('rejects unknown device identity even with valid HREG7 fields', () {
    expect(
      () => ScadaTelemetry.fromValue(
        'LBS_01',
        telemetryPayload({
          'device_id': 'OTHER_DEVICE',
          'mode_operasi': 'RUN',
          'mode_operasi_valid': true,
        }),
      ),
      throwsFormatException,
    );
  });

  test('preserves current NORMAL and SUSPECT statuses', () {
      final telemetry = ScadaTelemetry.fromValue(
        'LBS_01',
        telemetryPayload({
          'status_i_sumber': 'NORMAL',
          'status_i_beban': 'SUSPECT',
        }),
      );

      expect(telemetry.sourceCurrentStatus, 'NORMAL');
      expect(telemetry.loadCurrentStatus, 'SUSPECT');
    });

  test('legacy telemetry defaults current status to UNKNOWN', () {
    final telemetry = ScadaTelemetry.fromValue('LBS_01', telemetryPayload());

    expect(telemetry.sourceCurrentStatus, 'UNKNOWN');
    expect(telemetry.loadCurrentStatus, 'UNKNOWN');
  });
}
