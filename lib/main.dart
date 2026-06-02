import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/mqtt_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🔌 Connect MQTT setelah Firebase siap
  final mqtt = MqttService();
  final connected = await mqtt.connect();
  debugPrint(connected
      ? '[APP] MQTT terhubung'
      : '[APP] MQTT gagal — cek credentials HiveMQ');

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
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }
          if (snapshot.hasData) {
            // ⚠️ const dihapus karena DashboardScreen mungkin butuh MQTT instance
            return DashboardScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}