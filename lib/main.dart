import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/setup_screen.dart';
import 'services/mqtt_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final mqtt = MqttService();
  final connected = await mqtt.connect();
  debugPrint(connected ? '[APP] MQTT terhubung' : '[APP] MQTT gagal');
  runApp(const PresentiaApp());
}

class PresentiaApp extends StatelessWidget {
  const PresentiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PRESENTIA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A5F),
        ),
        useMaterial3: true,
      ),
      home: const _RootRouter(),
    );
  }
}

class _RootRouter extends StatelessWidget {
  const _RootRouter();

  Future<bool> _isFirstSetup() async {
    // Cek apakah sudah ada user di Firebase
    final snap = await FirebaseDatabase.instance
        .ref('presentia/users')
        .get();
    return !snap.exists || snap.value == null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isFirstSetup(),
      builder: (context, setupSnap) {
        // Masih loading cek Firebase
        if (setupSnap.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // Belum ada user sama sekali → Setup awal
        if (setupSnap.data == true) {
          return const SetupScreen();
        }

        // Sudah ada user → cek login status
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnap) {
            if (authSnap.connectionState == ConnectionState.waiting) {
              return const SplashScreen();
            }
            if (authSnap.hasData) {
              return DashboardScreen();
            }
            return const LoginScreen();
          },
        );
      },
    );
  }
}