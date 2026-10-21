# Smart LED Control - ESP32 + Flutter

## Hệ thống điều khiển đèn LED thông minh

App Flutter điều khiển dải LED WS2812/NeoPixel trên ESP32 qua MQTT,
tích hợp trợ lý AI (Google Gemini) để điều khiển bằng ngôn ngữ tự nhiên.

---

## Phần cứng cần thiết

| Linh kiện | Kết nối ESP32 |
|---|---|
| ESP32 DevKit | - |
| WS2812 LED Strip | Data → GPIO 5, VCC → 5V, GND → GND |
| Cảm biến ánh sáng (LDR/BH1750) | Analog → GPIO 34 |
| Cảm biến chuyển động PIR | Signal → GPIO 27, VCC → 3.3V |

## Cài đặt

### 1. Nạp firmware ESP32

1. Mở Arduino IDE
2. Cài thư viện: `Adafruit NeoPixel`, `PubSubClient`, `ArduinoJson`
3. Mở file `esp32_firmware/smart_led_esp32.ino`
4. Đổi `WIFI_SSID` và `WIFI_PASSWORD` thành WiFi của bạn
5. Nạp code vào ESP32

### 2. Chạy app Flutter

```bash
cd "App IOT"
flutter pub get
flutter run
```

### 3. Cấu hình trong app

1. Vào **Cài đặt** (icon bánh răng)
2. Nhập MQTT broker: `test.mosquitto.org` (mặc định)
3. Nhập Gemini API Key (lấy free tại https://aistudio.google.com)
4. Nhấn **Lưu & Kết nối**

## Tính năng

### Điều khiển màu sắc
- Color picker wheel
- RGB sliders
- 12 preset màu (Hoàng hôn, Lavender, Biển đêm...)

### Hiệu ứng LED (8 loại)
- Nhấp nháy, Fade, Cầu vồng, Thở
- Strobe, Color Wipe, Chase
- Tùy chỉnh tốc độ 50ms - 3000ms

### Trợ lý AI (Gemini)
- Nói: "Bật đèn màu xanh dương"
- Nói: "Cho đèn hiệu ứng cầu vồng"
- Nói: "Giảm sáng 30%"
- Nói: "Bật chế độ tự động"

### Cảm biến
- Biểu đồ cường độ ánh sáng realtime
- Phát hiện chuyển động
- Chế độ tự động: tự chỉnh sáng + tự bật đèn khi có người

## MQTT Topics

| Topic | Dữ liệu | Hướng |
|---|---|---|
| `smart_led/power` | `{"state": "on"}` | App → ESP32 |
| `smart_led/color` | `{"r": 255, "g": 0, "b": 128}` | App → ESP32 |
| `smart_led/brightness` | `{"value": 80}` | App → ESP32 |
| `smart_led/effect` | `{"type": "rainbow", "speed": 500}` | App → ESP32 |
| `smart_led/auto_mode` | `{"enabled": true}` | App → ESP32 |
| `smart_led/sensor/light` | `{"lux": 350}` | ESP32 → App |
| `smart_led/sensor/motion` | `{"detected": true}` | ESP32 → App |

## Cấu trúc dự án

```
App IOT/
├── lib/
│   ├── main.dart              # Entry point + splash screen
│   ├── theme/app_theme.dart   # Dark theme + design system
│   ├── models/
│   │   ├── led_state.dart     # LED state + effects enum
│   │   ├── sensor_data.dart   # Sensor data model
│   │   ├── mqtt_config.dart   # MQTT configuration
│   │   └── chat_message.dart  # AI chat message
│   ├── services/
│   │   ├── mqtt_service.dart  # MQTT client
│   │   ├── ai_service.dart    # Gemini AI integration
│   │   └── storage_service.dart # Local storage
│   ├── providers/
│   │   └── led_provider.dart  # State management
│   └── screens/
│       ├── home_screen.dart       # Dashboard
│       ├── color_picker_screen.dart # Color picker
│       ├── effects_screen.dart    # LED effects
│       ├── ai_chat_screen.dart    # AI assistant
│       ├── sensor_screen.dart     # Sensor data
│       └── settings_screen.dart   # Settings
├── esp32_firmware/
│   └── smart_led_esp32.ino    # ESP32 Arduino code
└── pubspec.yaml
```
