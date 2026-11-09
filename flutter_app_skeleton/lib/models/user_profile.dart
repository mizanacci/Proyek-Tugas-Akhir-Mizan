import 'sensor_data.dart';

class UserProfile {
  final String uid;
  final String displayName;
  final UserRole role;
  final bool isActive;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.role,
    required this.isActive,
  });

  static UserProfile? tryParse({required String uid, required Object? value}) {
    if (uid.isEmpty || value is! Map) return null;

    final role = switch (value['role']) {
      'manager' => UserRole.manager,
      'operator' => UserRole.operator,
      _ => null,
    };
    final displayName = value['displayName'];

    if (role == null ||
        value['isActive'] != true ||
        displayName is! String ||
        displayName.trim().isEmpty) {
      return null;
    }

    return UserProfile(
      uid: uid,
      displayName: displayName.trim(),
      role: role,
      isActive: true,
    );
  }
}
