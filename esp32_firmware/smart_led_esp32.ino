/*
 * Smart LED Control - ESP32 Firmware
 * 
 * Phần cứng:
 * - ESP32 DevKit
 * - WS2812 LED Strip (Data pin: GPIO 5)
 * - Cảm biến ánh sáng (Analog pin: GPIO 34)
 * - Cảm biến chuyển động PIR (Digital pin: GPIO 27)
 * 
 * Thư viện cần cài:
 * - Adafruit NeoPixel
 * - PubSubClient (MQTT)
 * - ArduinoJson
 * - WiFi (built-in)
 */

#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Adafruit_NeoPixel.h>

// ============ CẤU HÌNH WiFi & MQTT ============
const char* WIFI_SSID = "YOUR_WIFI_SSID";          // Đổi thành tên WiFi
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";    // Đổi thành mật khẩu WiFi
const char* MQTT_BROKER = "test.mosquitto.org";
const int MQTT_PORT = 1883;
const char* MQTT_CLIENT_ID = "smart_led_esp32";

// ============ CẤU HÌNH PHẦN CỨNG ============
#define LED_PIN       5       // GPIO cho WS2812 Data
#define NUM_LEDS      30      // Số LED mặc định
#define LIGHT_SENSOR  34      // GPIO Analog cho cảm biến ánh sáng
#define PIR_PIN       27      // GPIO cho cảm biến chuyển động

// ============ MQTT TOPICS ============
const char* TOPIC_PREFIX = "smart_led";
String topicColor;
String topicBrightness;
String topicEffect;
String topicPower;
String topicSensorLight;
String topicSensorMotion;
String topicAutoMode;
String topicNumLeds;

// ============ BIẾN TOÀN CỤC ============
WiFiClient espClient;
PubSubClient mqttClient(espClient);
Adafruit_NeoPixel strip(NUM_LEDS, LED_PIN, NEO_GRB + NEO_KHZ800);

// Trạng thái LED
bool ledPower = false;
uint8_t ledR = 255, ledG = 255, ledB = 255;
int ledBrightness = 100;
String currentEffect = "none";
int effectSpeed = 500;
bool autoMode = false;
int numLeds = NUM_LEDS;

// Timing
unsigned long lastSensorRead = 0;
unsigned long lastEffectUpdate = 0;
unsigned long lastMotionCheck = 0;
const unsigned long SENSOR_INTERVAL = 2000;     // Đọc cảm biến mỗi 2 giây
const unsigned long MOTION_INTERVAL = 500;

// Effect state
int effectStep = 0;
bool effectDirection = true;

void setup() {
  Serial.begin(115200);
  Serial.println("\n=== Smart LED Control ESP32 ===");

  // Khởi tạo pin
  pinMode(PIR_PIN, INPUT);
  pinMode(LIGHT_SENSOR, INPUT);

  // Khởi tạo LED strip
  strip.begin();
  strip.setBrightness(map(ledBrightness, 0, 100, 0, 255));
  strip.show();

  // Khởi tạo MQTT topics
  topicColor = String(TOPIC_PREFIX) + "/color";
  topicBrightness = String(TOPIC_PREFIX) + "/brightness";
  topicEffect = String(TOPIC_PREFIX) + "/effect";
  topicPower = String(TOPIC_PREFIX) + "/power";
  topicSensorLight = String(TOPIC_PREFIX) + "/sensor/light";
  topicSensorMotion = String(TOPIC_PREFIX) + "/sensor/motion";
  topicAutoMode = String(TOPIC_PREFIX) + "/auto_mode";
  topicNumLeds = String(TOPIC_PREFIX) + "/num_leds";

  // Kết nối WiFi
  connectWiFi();

  // Cấu hình MQTT
  mqttClient.setServer(MQTT_BROKER, MQTT_PORT);
  mqttClient.setCallback(mqttCallback);
  mqttClient.setBufferSize(512);
  
  connectMQTT();
}

void loop() {
  // Duy trì kết nối
  if (!mqttClient.connected()) {
    connectMQTT();
  }
  mqttClient.loop();

  unsigned long now = millis();

  // Đọc cảm biến ánh sáng
  if (now - lastSensorRead >= SENSOR_INTERVAL) {
    lastSensorRead = now;
    readLightSensor();
  }

  // Kiểm tra chuyển động
  if (now - lastMotionCheck >= MOTION_INTERVAL) {
    lastMotionCheck = now;
    checkMotion();
  }

  // Cập nhật hiệu ứng
  if (ledPower && currentEffect != "none") {
    if (now - lastEffectUpdate >= (unsigned long)effectSpeed) {
      lastEffectUpdate = now;
      updateEffect();
    }
  }
}

// ============ WiFi ============
void connectWiFi() {
  Serial.printf("Đang kết nối WiFi: %s", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\nĐã kết nối WiFi! IP: %s\n", WiFi.localIP().toString().c_str());
  } else {
    Serial.println("\nLỗi kết nối WiFi!");
  }
}

// ============ MQTT ============
void connectMQTT() {
  int attempts = 0;
  while (!mqttClient.connected() && attempts < 5) {
    Serial.println("Đang kết nối MQTT...");
    
    if (mqttClient.connect(MQTT_CLIENT_ID)) {
      Serial.println("Đã kết nối MQTT!");
      
      // Subscribe các topic
      mqttClient.subscribe(topicColor.c_str());
      mqttClient.subscribe(topicBrightness.c_str());
      mqttClient.subscribe(topicEffect.c_str());
      mqttClient.subscribe(topicPower.c_str());
      mqttClient.subscribe(topicAutoMode.c_str());
      mqttClient.subscribe(topicNumLeds.c_str());
      
      Serial.println("Đã subscribe tất cả topics.");
    } else {
      Serial.printf("Lỗi MQTT, rc=%d. Thử lại...\n", mqttClient.state());
      delay(2000);
    }
    attempts++;
  }
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String message;
  for (unsigned int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  
  Serial.printf("MQTT [%s]: %s\n", topic, message.c_str());

  JsonDocument doc;
  DeserializationError error = deserializeJson(doc, message);
  if (error) {
    Serial.printf("Lỗi parse JSON: %s\n", error.c_str());
    return;
  }

  String topicStr = String(topic);

  if (topicStr == topicPower) {
    String state = doc["state"] | "off";
    ledPower = (state == "on");
    if (!ledPower) {
      clearLeds();
    } else {
      setAllLeds(ledR, ledG, ledB);
    }
  }
  else if (topicStr == topicColor) {
    ledR = doc["r"] | 255;
    ledG = doc["g"] | 255;
    ledB = doc["b"] | 255;
    if (ledPower && currentEffect == "none") {
      setAllLeds(ledR, ledG, ledB);
    }
  }
  else if (topicStr == topicBrightness) {
    ledBrightness = doc["value"] | 100;
    strip.setBrightness(map(ledBrightness, 0, 100, 0, 255));
    strip.show();
  }
  else if (topicStr == topicEffect) {
    currentEffect = doc["type"] | "none";
    effectSpeed = doc["speed"] | 500;
    effectStep = 0;
    effectDirection = true;
    
    if (currentEffect == "none" && ledPower) {
      setAllLeds(ledR, ledG, ledB);
    }
  }
  else if (topicStr == topicAutoMode) {
    autoMode = doc["enabled"] | false;
    Serial.printf("Chế độ tự động: %s\n", autoMode ? "BẬT" : "TẮT");
  }
  else if (topicStr == topicNumLeds) {
    int newCount = doc["count"] | NUM_LEDS;
    if (newCount != numLeds && newCount > 0 && newCount <= 300) {
      numLeds = newCount;
      strip.updateLength(numLeds);
      strip.show();
    }
  }
}

// ============ CẢM BIẾN ============
void readLightSensor() {
  int raw = analogRead(LIGHT_SENSOR);
  // Chuyển đổi giá trị analog sang lux (ước lượng)
  float lux = map(raw, 0, 4095, 0, 2000);
  
  JsonDocument doc;
  doc["lux"] = lux;
  
  String json;
  serializeJson(doc, json);
  mqttClient.publish(topicSensorLight.c_str(), json.c_str());
}

void checkMotion() {
  bool detected = digitalRead(PIR_PIN) == HIGH;
  
  static bool lastMotion = false;
  if (detected != lastMotion) {
    lastMotion = detected;
    
    JsonDocument doc;
    doc["detected"] = detected;
    
    String json;
    serializeJson(doc, json);
    mqttClient.publish(topicSensorMotion.c_str(), json.c_str());
    
    Serial.printf("Chuyển động: %s\n", detected ? "Phát hiện" : "Không");
  }
}

// ============ LED CONTROL ============
void setAllLeds(uint8_t r, uint8_t g, uint8_t b) {
  for (int i = 0; i < numLeds; i++) {
    strip.setPixelColor(i, strip.Color(r, g, b));
  }
  strip.show();
}

void clearLeds() {
  strip.clear();
  strip.show();
}

// ============ HIỆU ỨNG ============
void updateEffect() {
  if (currentEffect == "blink") {
    effectBlink();
  } else if (currentEffect == "fade") {
    effectFade();
  } else if (currentEffect == "rainbow") {
    effectRainbow();
  } else if (currentEffect == "breathing") {
    effectBreathing();
  } else if (currentEffect == "strobe") {
    effectStrobe();
  } else if (currentEffect == "color_wipe") {
    effectColorWipe();
  } else if (currentEffect == "chase") {
    effectChase();
  }
}

void effectBlink() {
  if (effectStep % 2 == 0) {
    setAllLeds(ledR, ledG, ledB);
  } else {
    clearLeds();
  }
  effectStep++;
}

void effectFade() {
  if (effectDirection) {
    effectStep += 5;
    if (effectStep >= 255) effectDirection = false;
  } else {
    effectStep -= 5;
    if (effectStep <= 0) effectDirection = true;
  }
  float factor = effectStep / 255.0;
  setAllLeds(ledR * factor, ledG * factor, ledB * factor);
}

void effectRainbow() {
  for (int i = 0; i < numLeds; i++) {
    int hue = (i * 65536 / numLeds + effectStep * 256) & 0xFFFF;
    strip.setPixelColor(i, strip.gamma32(strip.ColorHSV(hue)));
  }
  strip.show();
  effectStep = (effectStep + 1) % 256;
}

void effectBreathing() {
  float breath = (exp(sin(effectStep * PI / 128.0)) - 0.36787944) * 108.0;
  float factor = breath / 255.0;
  setAllLeds(ledR * factor, ledG * factor, ledB * factor);
  effectStep = (effectStep + 1) % 256;
}

void effectStrobe() {
  if (effectStep % 2 == 0) {
    setAllLeds(255, 255, 255);
  } else {
    clearLeds();
  }
  effectStep++;
}

void effectColorWipe() {
  if (effectStep < numLeds) {
    strip.setPixelColor(effectStep, strip.Color(ledR, ledG, ledB));
    strip.show();
  }
  effectStep++;
  if (effectStep >= numLeds * 2) {
    effectStep = 0;
    clearLeds();
  } else if (effectStep >= numLeds) {
    strip.setPixelColor(effectStep - numLeds, 0);
    strip.show();
  }
}

void effectChase() {
  for (int i = 0; i < numLeds; i++) {
    if ((i + effectStep) % 3 == 0) {
      strip.setPixelColor(i, strip.Color(ledR, ledG, ledB));
    } else {
      strip.setPixelColor(i, 0);
    }
  }
  strip.show();
  effectStep = (effectStep + 1) % 3;
}
