import 'package:flutter_test/flutter_test.dart';
import 'package:scada_mizan_app/models/sensor_data.dart';

void main() {
  test('parses the firmware sensor payload', () {
    final data = SensorData.fromJson({
      'v_sumber': 220.5,
      'v_beban': 219,
      'i_sumber': 0,
      'i_beban': 0.1,
      'kualitas': 0,
      'ts': 12345,
    });

    expect(data.teganganSumber, 220.5);
    expect(data.teganganBeban, 219);
    expect(data.timestampMs, 12345);
  });

  test('rejects a payload with a missing required field', () {
    expect(
      () => SensorData.fromJson({
        'v_sumber': 220,
        'v_beban': 220,
        'i_sumber': 0,
        'i_beban': 0,
        'kualitas': 0,
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a payload with a non-numeric field', () {
    expect(
      () => SensorData.fromJson({
        'v_sumber': '220',
        'v_beban': 220,
        'i_sumber': 0,
        'i_beban': 0,
        'kualitas': 0,
        'ts': 12345,
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects null and non-finite numeric values', () {
    for (final invalid in <Object?>[null, double.nan, double.infinity]) {
      expect(
        () => SensorData.fromJson({
          'v_sumber': invalid,
          'v_beban': 220,
          'i_sumber': 0,
          'i_beban': 0,
          'kualitas': 0,
          'ts': 12345,
        }),
        throwsA(isA<FormatException>()),
      );
    }
  });
}
