/// login_screen.dart — Layar Login (Gambar 3.9 mock-up proposal)
/// Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../models/sensor_data.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _pesanError;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _pesanError = null;
    });

    try {
      final firebaseService = context.read<FirebaseService>();
      final role = await firebaseService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;
      setState(() => _loading = false);

      if (role == null) {
        setState(() => _pesanError = firebaseService.pesanLoginTerakhir ??
            'Login gagal — periksa email/kata sandi dan akses Firebase.');
        return;
      }

      // Routing berdasarkan role — lihat main.dart untuk daftar rute.
      // Session listener revalidates the UID profile and active state.
      if (role == UserRole.manager) {
        Navigator.of(context).pushReplacementNamed('/menu-manager');
      } else {
        Navigator.of(context).pushReplacementNamed('/menu-operator');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _pesanError =
            'Tidak dapat terhubung ke Firebase. Periksa internet dan izin database.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/scada_mizan_login_background.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const ColoredBox(
              color: Colors.blueGrey,
            ),
          ),
          ColoredBox(color: Colors.black.withValues(alpha: 0.28)),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Card(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/scada_mizan_logo.png',
                        height: 96,
                        cacheHeight: 192,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                          Icons.electric_bolt,
                          size: 72,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'SCADA Distribusi Listrik',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                            labelText: 'Email', border: OutlineInputBorder()),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                            labelText: 'Kata Sandi',
                            border: OutlineInputBorder()),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      if (_pesanError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(_pesanError!,
                              style: const TextStyle(color: Colors.red)),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _loading ? null : _login,
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Masuk'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
