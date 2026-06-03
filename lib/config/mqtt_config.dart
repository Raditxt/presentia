import 'dart:math';

class MqttConfig {
  static const String host     = 'x8af8fe7.ala.asia-southeast1.emqxsl.com';
  static const int    port     = 8084;
  static const String username = 'flutter_app';
  static const String password = 'Karin1411';

  // 🔧 FIX: Client ID dinamis (unik setiap koneksi)
  static String get clientId => 'presentia_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';

  static const String topicEvent    = 'presentia/pintu/event';
  static const String topicCmdAdmin = 'presentia/cmd/kamar_admin';
  static const String topicCmdUser  = 'presentia/cmd/kamar_user';
  static const String topicCmdRumah = 'presentia/cmd/lampu_rumah';
  static const String topicStatus   = 'presentia/status';
  static const String topicScanMode = 'presentia/cmd/scan_mode';
  static const String topicScanResult = 'presentia/rfid/scan';
}