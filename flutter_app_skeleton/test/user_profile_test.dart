import 'package:flutter_test/flutter_test.dart';
import 'package:scada_mizan_app/models/sensor_data.dart';
import 'package:scada_mizan_app/models/user_profile.dart';

void main() {
  const profileUid = 'auth-uid';

  test('parses active manager and operator profiles', () {
    final manager = UserProfile.tryParse(
      uid: profileUid,
      value: {'role': 'manager', 'isActive': true, 'displayName': 'Manager'},
    );
    final operatorProfile = UserProfile.tryParse(
      uid: profileUid,
      value: {'role': 'operator', 'isActive': true, 'displayName': 'Operator'},
    );

    expect(manager?.role, UserRole.manager);
    expect(operatorProfile?.role, UserRole.operator);
  });

  test('rejects missing profile, inactive account, unknown role, or bad name',
      () {
    expect(UserProfile.tryParse(uid: profileUid, value: null), isNull);
    expect(
      UserProfile.tryParse(
        uid: profileUid,
        value: {
          'role': 'operator',
          'isActive': false,
          'displayName': 'Operator'
        },
      ),
      isNull,
    );
    expect(
      UserProfile.tryParse(
        uid: profileUid,
        value: {'role': 'admin', 'isActive': true, 'displayName': 'Admin'},
      ),
      isNull,
    );
    expect(
      UserProfile.tryParse(
        uid: profileUid,
        value: {'role': 'operator', 'isActive': true, 'displayName': '  '},
      ),
      isNull,
    );
  });
}
