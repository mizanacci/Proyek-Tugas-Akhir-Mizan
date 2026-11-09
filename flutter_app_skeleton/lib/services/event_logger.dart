import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

class EventLogger extends ChangeNotifier {
  final FirebaseService _firebaseService;
  late final StreamSubscription<dynamic> _authSubscription;
  bool _aktif = false;
  int _authGeneration = 0;

  EventLogger(this._firebaseService) {
    _authSubscription = _firebaseService.perubahanUser.listen(
      (user) => unawaited(_tanganiPerubahanAuth(user)),
      onError: (Object error) {
        debugPrint('[Session] Auth stream failed.');
      },
    );
  }

  bool get aktif => _aktif;

  Future<void> _tanganiPerubahanAuth(User? user) async {
    final generation = ++_authGeneration;
    if (user == null) {
      _aktif = false;
      notifyListeners();
      return;
    }

    _aktif = false;
    try {
      final profile = await _firebaseService.getCurrentProfile();
      if (generation != _authGeneration ||
          _firebaseService.userSaatIni?.uid != user.uid) {
        return;
      }
      if (profile == null) {
        notifyListeners();
        await _firebaseService.logout();
        return;
      }
      _aktif = true;
      notifyListeners();
    } catch (error) {
      _aktif = false;
      notifyListeners();
      debugPrint('[Session] Profile validation failed: $error');
    }
  }

  @override
  void dispose() {
    unawaited(_authSubscription.cancel());
    super.dispose();
  }
}
