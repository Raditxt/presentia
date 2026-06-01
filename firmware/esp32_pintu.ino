/*
  PRESENTIA v2 — ESP32 #1 (PINTU UTAMA)
  Wiring:
    RFID RC522   → GPIO 5 (SS), 18 (SCK), 19 (MISO), 23 (MOSI), 4 (RST)
    Relay #1 CH1 → GPIO 26 (solenoid 12V)
    Relay #1 CH2 → GPIO 27 (lampu rumah)
    VCC RFID & COM Relay#1 CH2 → 3.3V
    VIN Relay#1 → 5V
    GND semua bersama
*/

#include <SPI.h>
#include <MFRC522.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <time.h>

// ========== KONFIGURASI WIFI & MQTT ==========
const char* ssid = "WLC_CNAP";
const char* password = "s4y4b1s4";

const char* mqtt_server = "a281e75ee4d8417b9d81efb8897902da.s1.eu.hivemq.cloud";
const int mqtt_port = 8883;
const char* mqtt_user = "esp32_device";
const char* mqtt_pass = "Raditya14";
const char* mqtt_topic = "rumah/pintu/event";

const char* ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 7 * 3600;  // WIB
const int daylightOffset_sec = 0;

// ========== PIN ==========
#define SS_PIN        5
#define RST_PIN       4
#define RELAY_SOLENOID 26   // CH1 Relay #1 → solenoid pintu
#define RELAY_RUMAH    27   // CH2 Relay #1 → lampu rumah

// ========== UID KARTU (ganti dengan milikmu) ==========
String adminUID = "F7 51 86 63";
String userUID  = "61 07 C9 26";

enum Role { ADMIN, USER, UNKNOWN };
int counter = 0;
bool adminPresent = false;
bool userPresent = false;

MFRC522 rfid(SS_PIN, RST_PIN);
WiFiClientSecure secureClient;
PubSubClient mqttClient(secureClient);

// ========== RELAY ==========
void setSolenoid(bool open) { digitalWrite(RELAY_SOLENOID, open ? LOW : HIGH); }
void setLampuRumah(bool on) { digitalWrite(RELAY_RUMAH, on ? LOW : HIGH); }

// ========== RFID ==========
String readUID() {
  String uid = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    if (rfid.uid.uidByte[i] < 0x10) uid += "0";
    uid += String(rfid.uid.uidByte[i], HEX);
    if (i < rfid.uid.size - 1) uid += " ";
  }
  uid.toUpperCase();
  return uid;
}

Role getRole(String uid) {
  if (uid == adminUID) return ADMIN;
  if (uid == userUID) return USER;
  return UNKNOWN;
}

void updateOutputs() {
  bool anyoneHome = (counter > 0);
  setLampuRumah(anyoneHome);
  if (!anyoneHome) setSolenoid(false);
  Serial.print("Counter: "); Serial.println(counter);
}

void publishEvent(String event) {
  if (mqttClient.connected()) {
    mqttClient.publish(mqtt_topic, event.c_str());
    Serial.print("✅ [MQTT PUBLISH] "); Serial.println(event);
  } else {
    Serial.println("❌ [MQTT] Tidak terhubung, event tidak terkirim");
  }
}

void handleAdmin(String uid) {
  if (!adminPresent) {
    adminPresent = true; counter++;
    setSolenoid(true); delay(3000); setSolenoid(false);
    updateOutputs(); publishEvent("ADMIN_MASUK");
    Serial.println("ADMIN MASUK");
  } else {
    adminPresent = false; counter--; if (counter<0) counter=0;
    updateOutputs(); publishEvent("ADMIN_KELUAR");
    Serial.println("ADMIN KELUAR");
  }
}

void handleUser(String uid) {
  if (!userPresent) {
    userPresent = true; counter++;
    setSolenoid(true); delay(3000); setSolenoid(false);
    updateOutputs(); publishEvent("USER_MASUK");
    Serial.println("USER MASUK");
  } else {
    userPresent = false; counter--; if (counter<0) counter=0;
    updateOutputs(); publishEvent("USER_KELUAR");
    Serial.println("USER KELUAR");
  }
}

// ========== KONEKSI ==========
void connectWiFi() {
  Serial.print("Menghubungkan WiFi");
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
    Serial.println(" ✅ Waktu sinkron: " + String(ctime(&now)));
  } else {
    Serial.println(" ❌ Gagal sinkron NTP");
  }
}

void connectMQTT() {
  secureClient.setInsecure(); // Untuk demo, skip verifikasi sertifikat
  mqttClient.setServer(mqtt_server, mqtt_port);
  String clientId = "ESP32_Pintu_" + WiFi.macAddress();
  clientId.replace(":", "");
  while (!mqttClient.connected()) {
    Serial.print("Koneksi MQTT... ");
    if (mqttClient.connect(clientId.c_str(), mqtt_user, mqtt_pass)) {
      Serial.println("✅ terhubung (Client ID: " + clientId + ")");
    } else {
      Serial.print("❌ gagal, rc=");
      Serial.print(mqttClient.state());
      Serial.println(" coba lagi 10 detik");
      delay(10000);
    }
  }
}

void setup() {
  Serial.begin(115200);
  SPI.begin();
  rfid.PCD_Init();
  pinMode(RELAY_SOLENOID, OUTPUT);
  pinMode(RELAY_RUMAH, OUTPUT);
  digitalWrite(RELAY_SOLENOID, HIGH); // OFF
  digitalWrite(RELAY_RUMAH, HIGH);    // OFF

  connectWiFi();
  syncTime();
  connectMQTT();

  Serial.println("PRESENTIA #1 — PINTU UTAMA");
  Serial.println("Menunggu tap kartu...\n");
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("⚠️ WiFi putus, reconnect...");
    WiFi.reconnect();
    delay(3000);
    return;
  }
  if (!mqttClient.connected()) connectMQTT();
  mqttClient.loop();

  if (!rfid.PICC_IsNewCardPresent()) { delay(50); return; }
  if (!rfid.PICC_ReadCardSerial())   { delay(50); return; }

  String uid = readUID();
  Role role = getRole(uid);

  switch (role) {
    case ADMIN: handleAdmin(uid); break;
    case USER:  handleUser(uid);  break;
    default: Serial.println("ACCESS DENIED (UID tidak dikenal)"); break;
  }

  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
  rfid.PCD_AntennaOn();
  delay(500);
}