#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <time.h>

// ========== KONFIGURASI ==========
const char* ssid              = "WLC_CNAP";
const char* password          = "s4y4b1s4";
const char* mqtt_server       = "x8af8fe7.ala.asia-southeast1.emqxsl.com";
const int   mqtt_port         = 8883;
const char* mqtt_user         = "esp32_device";
const char* mqtt_pass         = "Raditya14";
const char* mqtt_topic_event  = "presentia/pintu/event";
const char* mqtt_topic_cmd    = "presentia/cmd/#";   // ← subscribe semua command dari app
const char* ntpServer         = "pool.ntp.org";
const long  gmtOffset_sec     = 7 * 3600;
const int   daylightOffset_sec = 0;

// ========== PIN ==========
#define PIR_ADMIN     13
#define PIR_USER      14
#define RELAY_L_ADMIN 25   // lampu kamar admin
#define RELAY_F_ADMIN 26   // kipas kamar admin
#define RELAY_L_USER  27   // lampu kamar user
#define RELAY_F_USER  32   // kipas kamar user

// ========== STATE ==========
bool adminPresent     = false;
bool userPresent      = false;
bool isMalam          = false;
bool lastPirAdmin     = false;
bool lastPirUser      = false;

// Mode manual override dari app — jika true, app yang kontrol relay
// jika false, relay dikontrol otomatis oleh logika sistem
bool manualLampuAdmin = false;
bool manualKipasAdmin = false;
bool manualLampuUser  = false;
bool manualKipasUser  = false;

unsigned long lastMotionAdmin = 0;
unsigned long lastMotionUser  = 0;
unsigned long lastTimeCheck   = 0;
const unsigned long PIR_TIMEOUT = 10UL * 60UL * 1000UL;

WiFiClientSecure secureClient;
PubSubClient     mqttClient(secureClient);

// ========== RELAY ==========
void setRelay(int pin, bool on) { digitalWrite(pin, on ? LOW : HIGH); }

void updateKamar() {
  // Kalau mode manual aktif untuk output tertentu,
  // nilai relay sudah di-set langsung di callback — skip logika otomatis
  bool lampuAdmin = manualLampuAdmin
      ? (digitalRead(RELAY_L_ADMIN) == LOW)  // baca state saat ini
      : adminPresent;

  bool kipasAdmin = manualKipasAdmin
      ? (digitalRead(RELAY_F_ADMIN) == LOW)
      : (adminPresent && lastPirAdmin);

  bool lampuUser  = manualLampuUser
      ? (digitalRead(RELAY_L_USER) == LOW)
      : (userPresent && isMalam);

  bool kipasUser  = manualKipasUser
      ? (digitalRead(RELAY_F_USER) == LOW)
      : (userPresent && lastPirUser);

  // Kamar admin selalu mati jika admin tidak ada, override manual pun diabaikan
  if (!adminPresent) { lampuAdmin = false; kipasAdmin = false; }

  setRelay(RELAY_L_ADMIN, lampuAdmin);
  setRelay(RELAY_F_ADMIN, kipasAdmin);
  setRelay(RELAY_L_USER,  lampuUser);
  setRelay(RELAY_F_USER,  kipasUser);

  Serial.println("══════════════════════════");
  Serial.print("Waktu      : "); Serial.println(isMalam ? "MALAM" : "SIANG");
  Serial.print("Admin ada  : "); Serial.println(adminPresent ? "YA" : "TIDAK");
  Serial.print("User ada   : "); Serial.println(userPresent  ? "YA" : "TIDAK");
  Serial.print("PIR Admin  : "); Serial.println(lastPirAdmin ? "AKTIF" : "off");
  Serial.print("PIR User   : "); Serial.println(lastPirUser  ? "AKTIF" : "off");
  Serial.println("──────────────────────────");
  Serial.print("Lampu admin: "); Serial.println(lampuAdmin ? "ON" : "OFF");
  Serial.print("Kipas admin: "); Serial.println(kipasAdmin ? "ON" : "OFF");
  Serial.print("Lampu user : "); Serial.println(lampuUser  ? "ON" : "OFF");
  Serial.print("Kipas user : "); Serial.println(kipasUser  ? "ON" : "OFF");
  Serial.println("══════════════════════════\n");
}

// ========== CEK WAKTU ==========
void checkWaktu() {
  time_t now = time(nullptr);
  if (now < 100000) return;
  struct tm* t = localtime(&now);
  int  jam       = t->tm_hour;
  bool malambaru = (jam >= 18 || jam < 5);
  if (malambaru != isMalam) {
    isMalam = malambaru;
    Serial.print("Waktu berubah → ");
    Serial.println(isMalam ? "MALAM" : "SIANG");
    updateKamar();
  }
}

// ========== MQTT CALLBACK ==========
void callback(char* topicChar, byte* payload, unsigned int length) {
  String msg   = "";
  String topic = String(topicChar);
  for (unsigned int i = 0; i < length; i++) msg += (char)payload[i];
  msg.trim();

  Serial.print("[MQTT] topic: "); Serial.print(topic);
  Serial.print(" → "); Serial.println(msg);

  // ── Event dari ESP32 #1 (tap kartu) ─────────────────
  if (topic == mqtt_topic_event) {
    if      (msg == "ADMIN_MASUK")  { adminPresent = true;  lastMotionAdmin = millis(); }
    else if (msg == "ADMIN_KELUAR") { adminPresent = false; manualLampuAdmin = false; manualKipasAdmin = false; }
    else if (msg == "USER_MASUK")   { userPresent  = true;  lastMotionUser  = millis(); }
    else if (msg == "USER_KELUAR")  { userPresent  = false; manualLampuUser  = false; manualKipasUser  = false; }
    else if (msg == "SEMUA_OFF")    {
      adminPresent = false; userPresent = false;
      manualLampuAdmin = manualKipasAdmin = false;
      manualLampuUser  = manualKipasUser  = false;
    }
    updateKamar();
    return;
  }

  // ── Command dari Flutter app ─────────────────────────
  // Topic format: presentia/cmd/lampu_rumah
  //               presentia/cmd/kamar_admin_lampu
  //               presentia/cmd/kamar_admin_kipas
  //               presentia/cmd/kamar_user_lampu
  //               presentia/cmd/kamar_user_kipas
  bool val = (msg == "ON" || msg == "1" || msg == "true");

  if (topic == "presentia/cmd/kamar_admin_lampu") {
    if (!adminPresent) {
      Serial.println("[CMD] Ditolak — admin tidak ada di rumah");
      return;
    }
    manualLampuAdmin = true;
    setRelay(RELAY_L_ADMIN, val);
    Serial.print("[CMD] Lampu admin → "); Serial.println(val ? "ON" : "OFF");

  } else if (topic == "presentia/cmd/kamar_admin_kipas") {
    if (!adminPresent) {
      Serial.println("[CMD] Ditolak — admin tidak ada di rumah");
      return;
    }
    manualKipasAdmin = true;
    setRelay(RELAY_F_ADMIN, val);
    Serial.print("[CMD] Kipas admin → "); Serial.println(val ? "ON" : "OFF");

  } else if (topic == "presentia/cmd/kamar_user_lampu") {
    manualLampuUser = true;
    setRelay(RELAY_L_USER, val);
    Serial.print("[CMD] Lampu user → "); Serial.println(val ? "ON" : "OFF");

  } else if (topic == "presentia/cmd/kamar_user_kipas") {
    manualKipasUser = true;
    setRelay(RELAY_F_USER, val);
    Serial.print("[CMD] Kipas user → "); Serial.println(val ? "ON" : "OFF");

  } else if (topic == "presentia/cmd/semua_off") {
    adminPresent = false; userPresent = false;
    manualLampuAdmin = manualKipasAdmin = false;
    manualLampuUser  = manualKipasUser  = false;
    updateKamar();
    Serial.println("[CMD] Semua OFF");
  }
}

// ========== KONEKSI ==========
void connectWiFi() {
  Serial.print("Menghubungkan WiFi...");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500); Serial.print(".");
  }
  Serial.println("\n✅ WiFi terhubung, IP: " + WiFi.localIP().toString());
}

void syncTime() {
  Serial.print("Sinkronisasi NTP...");
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
  time_t now = time(nullptr);
  int retry = 0;
  while (now < 100000 && retry < 20) {
    delay(500); now = time(nullptr); retry++; Serial.print(".");
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
      // Subscribe ke dua topic sekaligus
      mqttClient.subscribe(mqtt_topic_event);
      mqttClient.subscribe(mqtt_topic_cmd);
      Serial.println("   Subscribe: presentia/pintu/event");
      Serial.println("   Subscribe: presentia/cmd/#");
    } else {
      Serial.print("❌ gagal, rc=");
      Serial.print(mqttClient.state());
      Serial.println(" — coba lagi 10 detik");
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
  pinMode(PIR_USER,  INPUT_PULLDOWN);
  lastMotionAdmin = lastMotionUser = millis();

  connectWiFi();
  syncTime();
  connectMQTT();

  Serial.println("\nPRESENTIA #2 — DALAM RUMAH");
  Serial.println("PIR warm-up 30 detik...");
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

  bool pirAdmin = digitalRead(PIR_ADMIN);
  bool pirUser  = digitalRead(PIR_USER);

  if (pirAdmin) lastMotionAdmin = millis();
  if (pirUser)  lastMotionUser  = millis();

  if (pirAdmin != lastPirAdmin || pirUser != lastPirUser) {
    lastPirAdmin = pirAdmin;
    lastPirUser  = pirUser;
    if (pirAdmin) Serial.println("[PIR ADMIN] Gerakan terdeteksi");
    if (pirUser)  Serial.println("[PIR USER]  Gerakan terdeteksi");
    // Reset manual override saat ada gerakan baru — kembali ke mode otomatis
    if (pirAdmin) manualKipasAdmin = false;
    if (pirUser)  manualKipasUser  = false;
    updateKamar();
  }

  // Failsafe PIR timeout
  if (adminPresent && lastPirAdmin &&
      (millis() - lastMotionAdmin >= PIR_TIMEOUT)) {
    Serial.println("⚠️ Failsafe Admin: timeout → Kipas OFF");
    lastPirAdmin     = false;
    manualKipasAdmin = false;
    lastMotionAdmin  = millis();
    updateKamar();
  }
  if (userPresent && lastPirUser &&
      (millis() - lastMotionUser >= PIR_TIMEOUT)) {
    Serial.println("⚠️ Failsafe User: timeout → Kipas OFF");
    lastPirUser     = false;
    manualKipasUser = false;
    lastMotionUser  = millis();
    updateKamar();
  }

  // Cek waktu setiap menit
  if (millis() - lastTimeCheck >= 60000) {
    lastTimeCheck = millis();
    checkWaktu();
  }

  // Perintah manual Serial Monitor
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim(); cmd.toUpperCase();
    if      (cmd == "TOGGLE_MALAM") {
      isMalam = !isMalam;
      Serial.print("Manual toggle → ");
      Serial.println(isMalam ? "MALAM" : "SIANG");
      updateKamar();
    }
    else if (cmd == "STATUS")    updateKamar();
    else if (cmd == "SEMUA_OFF") {
      adminPresent = userPresent = isMalam = false;
      lastPirAdmin = lastPirUser = false;
      manualLampuAdmin = manualKipasAdmin = false;
      manualLampuUser  = manualKipasUser  = false;
      Serial.println("Reset semua state → OFF");
      updateKamar();
    }
    else if (cmd == "HELP") {
      Serial.println("Perintah: TOGGLE_MALAM | STATUS | SEMUA_OFF");
    }
    else Serial.println("Tidak dikenal. Ketik HELP");
  }

  delay(200);
}