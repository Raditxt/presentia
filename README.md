# PRESENTIA 🏠

**Smart Door Controller berbasis IoT**  
Sistem kendali akses dan otomatisasi ruangan menggunakan ESP32, RFID, PIR Sensor, dan Flutter.

---

## Kategori
Smart Home

## Stack
| Layer | Teknologi |
|---|---|
| Firmware | ESP32 (Arduino IDE) |
| Protokol | MQTT (HiveMQ Cloud) |
| Database | Firebase Realtime Database |
| Auth | Firebase Authentication |
| Mobile App | Flutter (Dart) |

## Fitur
- Role-based access control (Admin & User)
- Counter occupancy multi-user
- PIR sensor failsafe
- Otomatisasi pencahayaan berbasis waktu (NTP)
- Kontrol manual via aplikasi mobile
- Log aktivitas real-time
- Manajemen kartu RFID via app
- Plug & play device registration

## Hardware
- ESP32 DevKit v1 x2
- RFID RC522 + kartu RFID (min. 2)
- PIR HC-SR501 x2
- Relay 2 channel x3
- LED (output lampu & kipas)

---

## Setup & Instalasi

### 1. Clone repo
```bash
git clone https://github.com/Raditxt/presentia.git
cd presentia
```

### 2. Setup Firebase
- Buat project di [Firebase Console](https://console.firebase.google.com)
- Aktifkan Authentication (Email/Password) dan Realtime Database
- Jalankan:
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```
File `lib/firebase_options.dart` akan otomatis terbuat.

### 3. Setup HiveMQ
- Daftar di [HiveMQ Cloud](https://console.hivemq.cloud) (free tier)
- Buat cluster → catat Host URL, Username, Password
- Update `lib/config/mqtt_config.dart` dengan credentials kamu

### 4. Install dependencies & run
```bash
flutter pub get
flutter run
```

### 5. Upload firmware ESP32
- Buka `firmware/esp32_pintu.ino` di Arduino IDE
- Install library: `MFRC522`, `PubSubClient`
- Update WiFi credentials dan MQTT credentials di kode
- Upload ke ESP32 #1 (Pintu) dan ESP32 #2 (Kamar)

---

## Struktur Folder
lib/
├── config/         # MQTT config
├── models/         # Data models
├── screens/        # UI screens
├── services/       # Auth, Database, MQTT services
└── widgets/        # Reusable widgets
firmware/
├── esp32_pintu.ino     # ESP32 #1 — Pintu utama
└── esp32_kamar.ino     # ESP32 #2 — Dalam rumah

---

## Wiring
Lihat dokumentasi lengkap wiring di `docs/wiring.md`

---

*Proyek UAS IoT — D4 Teknik Komputer dan Jaringan, PNUP*