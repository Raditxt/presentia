class MqttConfig {
  // Ambil dari HiveMQ console kamu
  static const String host     = 'a281e75ee4d8417b9d81efb8897902da.s1.eu.hivemq.cloud';
  static const int    port     = 8884; // WebSocket TLS untuk Flutter
  static const String username = 'flutter_app'; // buat credentials baru di HiveMQ
  static const String password = 'Testingdart123';
  static const String clientId = 'presentia_flutter';

  // Topics — harus sama persis dengan yang di ESP32
  static const String topicEvent    = 'rumah/pintu/event';   // subscribe (terima dari ESP32)
  static const String topicCmdAdmin = 'rumah/cmd/kamar_admin';
  static const String topicCmdUser  = 'rumah/cmd/kamar_user';
  static const String topicCmdRumah = 'rumah/cmd/lampu_rumah';
  static const String topicStatus   = 'rumah/status';        // ESP32 #2 publish statusnya
}