import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:firebase_database/firebase_database.dart';
import '../config/mqtt_config.dart';

class MqttService {
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  late MqttBrowserClient _client;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  final _db = FirebaseDatabase.instance;
  final _msgController = StreamController<Map<String, String>>.broadcast();
  Stream<Map<String, String>> get messageStream => _msgController.stream;

  Future<bool> connect() async {
    _client = MqttBrowserClient(
      'wss://${MqttConfig.host}/mqtt',
      MqttConfig.clientId,
    );
    _client.port = MqttConfig.port;
    _client.keepAlivePeriod = 60;
    _client.logging(on: false);
    _client.onDisconnected = _onDisconnected;
    _client.onConnected = _onConnected;

    final connMsg = MqttConnectMessage()
        .withClientIdentifier(MqttConfig.clientId)
        .authenticateAs(MqttConfig.username, MqttConfig.password)
        .startClean()
        .withWillTopic('presentia/status')
        .withWillMessage('offline')
        .withWillQos(MqttQos.atLeastOnce);

    _client.connectionMessage = connMsg;

    try {
      await _client.connect();
    } catch (e) {
      debugPrint('[MQTT] Koneksi gagal: $e');
      _client.disconnect();
      return false;
    }

    if (_client.connectionStatus!.state != MqttConnectionState.connected) {
      debugPrint('[MQTT] Status: ${_client.connectionStatus!.state}');
      return false;
    }

    _client.subscribe(MqttConfig.topicEvent, MqttQos.atLeastOnce);
    _client.updates!.listen(_onMessage);
    _isConnected = true;
    return true;
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final msg in messages) {
      final payload = MqttPublishPayload.bytesToStringAsString(
        (msg.payload as MqttPublishMessage).payload.message,
      );
      final topic = msg.topic;
      debugPrint('[MQTT IN] $topic → $payload');
      _msgController.add({'topic': topic, 'payload': payload});
      if (topic == MqttConfig.topicEvent) {
        _handleEvent(payload);
      }
    }
  }

  Future<void> _handleEvent(String event) async {
    final ref = _db.ref('presentia/state');
    final logRef = _db.ref('presentia/log');
    final now = DateTime.now();

    final timeStr = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')} '
        '${now.day}/${now.month}/${now.year}';

    final counterSnap = await _db.ref('presentia/state/counter').get();
    int counter = (counterSnap.value as int?) ?? 0;

    switch (event) {
      case 'ADMIN_MASUK':
        counter = counter + 1;
        await ref.update({
          'adminPresent': true,
          'lampuRumah': true,
          'kamarAdmin/lampu': true,
          'counter': counter,
        });
        // 🔹 Tambahkan log untuk admin masuk
        await logRef.push().set({
          'role': 'admin',
          'action': 'masuk',
          'name': 'Admin',
          'timestamp': now.millisecondsSinceEpoch,
          'time': timeStr,
        });
        break;

      case 'ADMIN_KELUAR':
        counter = (counter - 1).clamp(0, 99);
        await ref.update({
          'adminPresent': false,
          'kamarAdmin/lampu': false,
          'kamarAdmin/kipas': false,
          'counter': counter,
        });
        if (counter == 0) {
          await ref.update({'lampuRumah': false});
        }
        await logRef.push().set({
          'role': 'admin',
          'action': 'keluar',
          'name': 'Admin',
          'timestamp': now.millisecondsSinceEpoch,
          'time': timeStr,
        });
        break;

      case 'USER_MASUK':
        counter = counter + 1;
        await ref.update({
          'userPresent': true,
          'lampuRumah': true,
          'kamarUser/lampu': true,
          'counter': counter,
        });
        await logRef.push().set({
          'role': 'user',
          'action': 'masuk',
          'name': 'User',
          'timestamp': now.millisecondsSinceEpoch,
          'time': timeStr,
        });
        break;

      case 'USER_KELUAR':
        counter = (counter - 1).clamp(0, 99);
        await ref.update({
          'userPresent': false,
          'kamarUser/lampu': false,
          'kamarUser/kipas': false,
          'counter': counter,
        });
        if (counter == 0) {
          await ref.update({'lampuRumah': false});
        }
        await logRef.push().set({
          'role': 'user',
          'action': 'keluar',
          'name': 'User',
          'timestamp': now.millisecondsSinceEpoch,
          'time': timeStr,
        });
        break;

      case 'SEMUA_OFF':
        await ref.set({
          'adminPresent': false,
          'userPresent': false,
          'counter': 0,
          'lampuRumah': false,
          'isMalam': false,
          'kamarAdmin': {'lampu': false, 'kipas': false},
          'kamarUser': {'lampu': false, 'kipas': false},
        });
        break;
    }
  }

  void publish(String topic, String payload) {
    if (!_isConnected) {
      debugPrint('[MQTT] Tidak terhubung, publish gagal');
      return;
    }
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    debugPrint('[MQTT OUT] $topic → $payload');
  }

  void disconnect() {
    _client.disconnect();
    _isConnected = false;
  }

  void _onConnected() {
    _isConnected = true;
    debugPrint('[MQTT] ✅ Terhubung ke EMQX Cloud');
  }

  void _onDisconnected() {
    _isConnected = false;
    debugPrint('[MQTT] ❌ Terputus dari EMQX Cloud');
  }
}