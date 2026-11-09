/// main.dart — Entry point aplikasi & routing berbasis role
/// Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'config/firebase_config.dart';
import 'firebase_options.dart';
import 'services/firebase_service.dart';
import 'services/event_logger.dart';
import 'services/scada_service.dart';
import 'screens/login_screen.dart';
import 'screens/menu_manager_screen.dart';
import 'screens/menu_operator_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final options = DefaultFirebaseOptions.currentPlatform;
  if (options.projectId != firebaseProjectId ||
      options.databaseURL != firebaseDatabaseUrl) {
    throw StateError(
      'Firebase options harus menunjuk project $firebaseProjectId dan '
      'Realtime Database $firebaseDatabaseUrl. Jalankan FlutterFire CLI.',
    );
  }
  await Firebase.initializeApp(options: options);
  runApp(const ScadaMizanApp());
}

class ScadaMizanApp extends StatelessWidget {
  const ScadaMizanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FirebaseService()),
        ProxyProvider<FirebaseService, ScadaService>(
          update: (_, firebase, __) => ScadaService(
            loadCurrentProfile: firebase.getCurrentProfile,
          ),
        ),
        ProxyProvider<FirebaseService, EventLogger>(
          lazy: false,
          update: (_, firebase, previous) => previous ?? EventLogger(firebase),
          dispose: (_, logger) => logger.dispose(),
        ),
      ],
      child: MaterialApp(
        title: 'SCADA Distribusi Listrik',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
        ),
        // Routing sederhana berbasis nama — layar Menu Manager/Operator
        // dipilih dari hasil login (lihat login_screen.dart), BUKAN dari
        // rute statis, karena role hanya diketahui setelah autentikasi
        // berhasil dan field role dibaca dari /users/<uid>/role.
        home: const LoginScreen(),
        routes: {
          '/menu-manager': (context) => const MenuManagerScreen(),
          '/menu-operator': (context) => const MenuOperatorScreen(),
        },
      ),
    );
  }
}
