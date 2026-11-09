import 'package:flutter_test/flutter_test.dart';
import 'package:scada_mizan_app/services/firebase_service.dart';
import 'package:scada_mizan_app/models/sensor_data.dart';

void main() {
  group('FirebaseService.roleDariNilai', () {
    test('menerima manager dan operator secara eksplisit', () {
      expect(FirebaseService.roleDariNilai('manager'), UserRole.manager);
      expect(FirebaseService.roleDariNilai('operator'), UserRole.operator);
    });

    test('menolak role kosong/tidak dikenal dan tipe non-string', () {
      expect(FirebaseService.roleDariNilai(null), isNull);
      expect(FirebaseService.roleDariNilai(1), isNull);
      expect(FirebaseService.roleDariNilai(''), isNull);
      expect(FirebaseService.roleDariNilai('admin'), isNull);
      expect(FirebaseService.roleDariNilai('guest'), isNull);
      expect(FirebaseService.roleDariNilai('MANAGER'), isNull);
      expect(FirebaseService.roleDariNilai('Operator'), isNull);
    });
  });
}
