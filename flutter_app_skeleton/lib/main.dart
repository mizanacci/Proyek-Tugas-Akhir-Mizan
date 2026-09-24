/// main.dart — Entry point aplikasi & routing berbasis role
/// Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'services/firebase_service.dart';
import 'services/mqtt_service.dart';
import 'screens/login_screen.dart';
import 'screens/menu_manager_screen.dart';
import 'screens/menu_operator_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ScadaMizanApp());
}

class ScadaMizanApp extends StatelessWidget {
  const ScadaMizanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FirebaseService()),
        ChangeNotifierProvider(create: (_) => MqttService()),
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
