/*
  PRESENTIA v2 — ESP32 #2 (DALAM RUMAH)
  Wiring:
    PIR Admin      → GPIO 13
    PIR User       → GPIO 14
    Relay #2 CH1   → GPIO 25 (lampu kamar admin)
    Relay #2 CH2   → GPIO 26 (kipas kamar admin)  5V
    Relay #3 CH1   → GPIO 27 (lampu kamar user)
    Relay #3 CH2   → GPIO 32 (kipas kamar user)   5V
    COM Relay #2/3 CH1 → 3.3V (sumber LED lampu)
    COM Relay #2/3 CH2 → 5V   (sumber kipas)
    VCC Relay #2/3  → 5V
    VCC PIR x2      → 5V
    GND semua bersama
*/

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <time.h>

// ========== KONFIGURASI ==========
const char* ssid         = "WLC_CNAP";
const char* password     = "s4y4b1s4";
const char* mqtt_server  = "a281e75ee4d8417b9d81efb8897902da.s1.eu.hivemq.cloud";
const int   mqtt_port    = 8883;
const char* mqtt_user    = "esp32_device";
const char* mqtt_pass    = "Raditya14";
const char* mqtt_topic   = "rumah/pintu/event";
const char* ntpServer    = "pool.ntp.org";
const long  gmtOffset_sec = 7 * 3600;
const int   daylightOffset_sec = 0;

// ========== PIN ==========
#define PIR_ADMIN     13
#define PIR_USER      14
#define RELAY_L_ADMIN 25   // CH1 Relay #2 → lampu kamar admin
#define RELAY_F_ADMIN 26   // CH2 Relay #2 → kipas kamar admin
#define RELAY_L_USER  27   // CH1 Relay #3 → lampu kamar user
#define RELAY_F_USER  32   // CH2 Relay #3 → kipas kamar user

// ========== STATE ==========
bool adminPresent    = false;
bool userPresent     = false;
bool isMalam         = false;
bool lastPirAdmin    = false;
bool lastPirUser     = false;
unsigned long lastMotionAdmin = 0;
unsigned long lastMotionUser  = 0;
unsigned long lastTimeCheck   = 0;
const unsigned long PIR_TIMEOUT = 10 * 60 * 1000UL; // 10 menit

WiFiClientSecure secureClient;
PubSubClient mqttClient(secureClient);

// ========== RELAY ==========
void setRelay(int pin, bool on) { digitalWrite(pin, on ? LOW : HIGH); }

void updateKamar() {
  // Kamar Admin
  bool lampuAdmin = adminPresent;
  bool ledAdmin   = adminPresent && lastPirAdmin;  // kipas menyala jika ada gerakan

  // Kamar User
  bool lampuUser  = userPresent && isMalam;       // lampu hanya malam
  bool ledUser    = userPresent && lastPirUser;   // kipas menyala jika ada gerakan

  // Jika admin tidak ada, kamar admin mati total
  if (!adminPresent) {
    lampuAdmin = false;
    ledAdmin   = false;
  }

  setRelay(RELAY_L_ADMIN, lampuAdmin);
  setRelay(RELAY_F_ADMIN, ledAdmin);
  setRelay(RELAY_L_USER,  lampuUser);
  setRelay(RELAY_F_USER,  ledUser);

  // Debug print
  Serial.println("══════════════════════════");
  Serial.print("Waktu      : "); Serial.println(isMalam ? "MALAM 🌙" : "SIANG ☀️");
  Serial.print("Admin ada  : "); Serial.println(adminPresent ? "YA" : "TIDAK");
  Serial.print("User ada   : "); Serial.println(userPresent  ? "YA" : "TIDAK");
  Serial.print("PIR Admin  : "); Serial.println(lastPirAdmin ? "AKTIF" : "off");
  Serial.print("PIR User   : "); Serial.println(lastPirUser  ? "AKTIF" : "off");
  Serial.println("──────────────────────────");
  Serial.print("Lampu admin: "); Serial.println(lampuAdmin ? "ON" : "OFF");
  Serial.print("Kipas admin: "); Serial.println(ledAdmin   ? "ON" : "OFF");
  Serial.print("Lampu user : "); Serial.println(lampuUser  ? "ON" : "OFF");
  Serial.print("Kipas user : "); Serial.println(ledUser    ? "ON" : "OFF");
  Serial.println("══════════════════════════\n");
}

// ========== CEK WAKTU OTOMATIS ==========
void checkWaktu() {
  time_t now = time(nullptr);
  if (now < 100000) return; // NTP belum sync
  struct tm* t = localtime(&now);
  int jam = t->tm_hour;
  bool malambaru = (jam >= 18 || jam < 5); // Maghrib 18:00 - Subuh 05:00
  if (malambaru != isMalam) {
    isMalam = malambaru;
    Serial.print("🕐 Waktu berubah → ");
    Serial.println(isMalam ? "MALAM" : "SIANG");
    updateKamar();
  }
}

// ========== MQTT CALLBACK ==========
void callback(char* topic, byte* payload, unsigned int length) {
  String msg;
  for (unsigned int i = 0; i < length; i++) msg += (char)payload[i];
  msg.trim();
  Serial.print("📩 [MQTT] "); Serial.println(msg);

  if (msg == "ADMIN_MASUK")  { adminPresent = true;  lastMotionAdmin = millis(); }
  else if (msg == "ADMIN_KELUAR") { adminPresent = false; }
  else if (msg == "USER_MASUK")   { userPresent  = true;  lastMotionUser  = millis(); }
  else if (msg == "USER_KELUAR")  { userPresent  = false; }
  else if (msg == "SEMUA_OFF")    { adminPresent = false; userPresent = false; }
  else { return; }
  updateKamar();
}

// ========== KONEKSI ==========
void connectWiFi() {
  Serial.print("Menghubungkan WiFi...");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\n✅ WiFi terhubung, IP: " + WiFi.localIP().toString());
}

void syncTime() {
  Serial.print("Sinkronisasi NTP...");
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
  time_t now = time(nullptr);
  int retry = 0;
  while (now < 100000 && retry < 20) {
    delay(500);
    now = time(nullptr);
    retry++;
    Serial.print(".");
  }
  if (now > 100000) {
    struct tm* t = localtime(&now);
    Serial.printf(" ✅ %02d:%02d WIB\n", t->tm_hour, t->tm_min);
  } else {
    Serial.println(" ❌ NTP gagal");
  }
}

void connectMQTT() {
  secureClient.setInsecure();
  mqttClient.setServer(mqtt_server, mqtt_port);
  mqttClient.setCallback(callback);
  while (!mqttClient.connected()) {
    String clientId = "ESP32_Kamar_" + WiFi.macAddress();
    clientId.replace(":", "");
    Serial.print("MQTT koneksi... ");
    if (mqttClient.connect(clientId.c_str(), mqtt_user, mqtt_pass)) {
      Serial.println("✅ terhubung (Client ID: " + clientId + ")");
      mqttClient.subscribe(mqtt_topic);
      Serial.print("   Subscribe ke topic: "); Serial.println(mqtt_topic);
    } else {
      Serial.print("❌ gagal, rc=");
      Serial.print(mqttClient.state());
      Serial.println(" coba lagi 10 detik");
      delay(10000);
    }
  }
}

// ========== SETUP ==========
void setup() {
  Serial.begin(115200);
  int pins[] = {RELAY_L_ADMIN, RELAY_F_ADMIN, RELAY_L_USER, RELAY_F_USER};
  for (int p : pins) { pinMode(p, OUTPUT); digitalWrite(p, HIGH); }
  pinMode(PIR_ADMIN, INPUT_PULLDOWN);
  pinMode(PIR_USER, INPUT_PULLDOWN);
  lastMotionAdmin = lastMotionUser = millis();

  connectWiFi();
  syncTime();
  connectMQTT();

  Serial.println("PRESENTIA #2 — DALAM RUMAH");
  Serial.println("PIR warm-up 30 detik... jangan bergerak di depan sensor.");
  delay(30000);
  Serial.println("✅ PIR siap! Sistem berjalan.\n");
  updateKamar();
}

// ========== LOOP ==========
void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("⚠️ WiFi putus, reconnect...");
    WiFi.reconnect();
    delay(3000);
    return;
  }
  if (!mqttClient.connected()) connectMQTT();
  mqttClient.loop();

  // Baca PIR
  bool pirAdmin = digitalRead(PIR_ADMIN);
  bool pirUser  = digitalRead(PIR_USER);

  if (pirAdmin) lastMotionAdmin = millis();
  if (pirUser)  lastMotionUser  = millis();

  if (pirAdmin != lastPirAdmin || pirUser != lastPirUser) {
    lastPirAdmin = pirAdmin;
    lastPirUser  = pirUser;
    if (pirAdmin) Serial.println("👤 [PIR ADMIN] Gerakan terdeteksi");
    if (pirUser)  Serial.println("👤 [PIR USER]  Gerakan terdeteksi");
    updateKamar();
  }

  // Failsafe timeout
  if (adminPresent && lastPirAdmin && (millis() - lastMotionAdmin >= PIR_TIMEOUT)) {
    Serial.println("⚠️ Failsafe Admin: tidak ada gerakan > 10 menit → Kipas OFF");
    lastPirAdmin = false;
    lastMotionAdmin = millis();
    updateKamar();
  }
  if (userPresent && lastPirUser && (millis() - lastMotionUser >= PIR_TIMEOUT)) {
    Serial.println("⚠️ Failsafe User: tidak ada gerakan > 10 menit → Kipas OFF");
    lastPirUser = false;
    lastMotionUser = millis();
    updateKamar();
  }

  // Cek waktu otomatis setiap menit
  if (millis() - lastTimeCheck >= 60000) {
    lastTimeCheck = millis();
    checkWaktu();
  }

  // Perintah manual via Serial Monitor
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim(); cmd.toUpperCase();
    if (cmd == "TOGGLE_MALAM") {
      isMalam = !isMalam;
      Serial.print("🔄 Manual toggle waktu → ");
      Serial.println(isMalam ? "MALAM" : "SIANG");
      updateKamar();
    }
    else if (cmd == "STATUS") updateKamar();
    else if (cmd == "SEMUA_OFF") {
      adminPresent = false; userPresent = false; isMalam = false;
      lastPirAdmin = false; lastPirUser = false;
      Serial.println("🔴 Semua state di-reset (OFF)");
      updateKamar();
    }
    else if (cmd == "HELP") {
      Serial.println("Perintah: TOGGLE_MALAM, STATUS, SEMUA_OFF");
    }
    else {
      Serial.println("❌ Perintah tidak dikenal. Ketik HELP");
    }
  }

  delay(200);
}