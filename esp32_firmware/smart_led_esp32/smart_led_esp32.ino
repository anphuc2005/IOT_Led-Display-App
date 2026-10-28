// ESP32 room light with MQTT control. ArduinoJson 7 required.
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

#include <Wire.h>
#include <BH1750.h>
#include <DHT.h>
#include <Adafruit_NeoPixel.h>
#include <math.h>

// =====================================
// 1. KHAI BAO CHAN
// =====================================
#define PIR_PIN 27
#define DHT_PIN 26
#define DHT_TYPE DHT11

#define SDA_PIN 21
#define SCL_PIN 22

#define LED_PIN 18
#define LED_COUNT 8

// =====================================
// 2. THONG SO CAU HINH
// =====================================

// Nguong anh sang
const float DARK_LUX = 30.0f;
const float BRIGHT_LUX = 45.0f;
const float NIGHT_LUX = 5.0f;

// Thoi gian
const unsigned long HOLD_TIME = 60000UL;
const unsigned long FADE_TIME = 1500UL;
const unsigned long PIR_WARMUP = 45000UL;

// Chu ky cap nhat
const unsigned long LIGHT_INTERVAL = 500UL;
const unsigned long DHT_INTERVAL = 2500UL;
const unsigned long LED_INTERVAL = 25UL;
const unsigned long PRINT_INTERVAL = 1000UL;

// BH1750 tu khoi phuc sau loi
const unsigned long BH_RETRY = 5000UL;

// Loc du lieu
const float LUX_ALPHA = 0.20f;
const float TEMP_ALPHA = 0.25f;

// Nhiet do chuyen mau
const float TEMP_MIN = 20.0f;
const float TEMP_MAX = 35.0f;

// Gioi han cong suat LED
// 80/255 ~ 31% cong suat kenh RGB
const uint8_t MAX_LED_LEVEL = 80;

// =====================================
// 3. KHOI TAO DOI TUONG
// =====================================
BH1750 lightMeter;
DHT dht(DHT_PIN, DHT_TYPE);

Adafruit_NeoPixel strip(
  LED_COUNT,
  LED_PIN,
  NEO_GRB + NEO_KHZ800
);

// =====================================
// 4. BIEN TRANG THAI
// =====================================
float rawLux = 0;
float filteredLux = 0;

float temperature = 25;
float filteredTemp = 25;
float humidity = 0;

bool bhOK = false;
bool luxReady = false;
bool dhtOK = false;
bool tempReady = false;

bool pirReady = false;
bool motion = false;
bool hadMotion = false;

bool isDark = false;
bool lightActive = false;

// Thoi gian
unsigned long bootTime = 0;
unsigned long lastMotion = 0;

unsigned long lastLightRead = 0;
unsigned long lastDHTRead = 0;
unsigned long lastLEDUpdate = 0;
unsigned long lastPrint = 0;
unsigned long lastBHRetry = 0;

// Trang thai sang cua tung kenh LED
float currentR = 0;
float currentG = 0;
float currentB = 0;

// Debug
int ledLevel = 0;
uint8_t bhFailCount = 0;

// =====================================
// 5. KHOI TAO BH1750
// =====================================
bool initBH1750() {
  bool success = lightMeter.begin(
    BH1750::CONTINUOUS_HIGH_RES_MODE
  );

  if (success) {
    bhOK = true;
    luxReady = false;
    bhFailCount = 0;
    lastLightRead = millis();

    Serial.println("[BH1750] Connected");
  } else {
    bhOK = false;
    luxReady = false;

    Serial.println("[BH1750] Connection error");
  }

  return success;
}

// =====================================
// 6. DOC ANH SANG VA LOC NHIEM
// =====================================
void readLight(unsigned long now) {
  if (now - lastLightRead < LIGHT_INTERVAL) {
    return;
  }

  lastLightRead = now;

  if (!bhOK) {
    return;
  }

  float value = lightMeter.readLightLevel();

  if (!isfinite(value) || value < 0) {
    bhFailCount++;

    if (bhFailCount >= 3) {
      bhOK = false;
      luxReady = false;
      lastBHRetry = now;

      Serial.println("[BH1750] Sensor lost");
    }
    return;
  }

  bhFailCount = 0;
  rawLux = value;

  if (!luxReady) {
    filteredLux = value;
    luxReady = true;
  } else {
    filteredLux =
      LUX_ALPHA * value +
      (1.0f - LUX_ALPHA) * filteredLux;
  }

  // Hysteresis
  if (filteredLux < DARK_LUX) {
    isDark = true;
  } else if (filteredLux > BRIGHT_LUX) {
    isDark = false;
  }
}

// =====================================
// 7. DOC NHIET DO VA DO AM
// =====================================
void readDHT(unsigned long now) {
  if (now - lastDHTRead < DHT_INTERVAL) {
    return;
  }

  lastDHTRead = now;

  float t = dht.readTemperature();
  float h = dht.readHumidity();

  if (!isfinite(t) || !isfinite(h)) {
    dhtOK = false;
    Serial.println("[DHT11] Read error");
    return;
  }

  temperature = t;
  humidity = h;
  dhtOK = true;

  if (!tempReady) {
    filteredTemp = t;
    tempReady = true;
  } else {
    filteredTemp =
      TEMP_ALPHA * t +
      (1.0f - TEMP_ALPHA) * filteredTemp;
  }
}

// =====================================
// 8. DOC CHUYEN DONG
// =====================================
void readPIR(unsigned long now) {
  pirReady = (now - bootTime >= PIR_WARMUP);

  if (!pirReady) {
    motion = false;
    return;
  }

  motion = digitalRead(PIR_PIN) == HIGH;

  if (motion) {
    lastMotion = now;
    hadMotion = true;
  }
}

// =====================================
// 9. QUYET DINH BAT/TAT
// =====================================
void updateAutomation(unsigned long now) {
  if (!pirReady) {
    lightActive = false;
    return;
  }

  bool recentlyDetected =
    hadMotion &&
    (now - lastMotion < HOLD_TIME);

  if (!recentlyDetected) {
    lightActive = false;
    return;
  }

  // Neu BH1750 loi:
  // Cho phep chieu sang du phong khi co PIR
  if (!bhOK || !luxReady) {
    lightActive = true;
    return;
  }

  // Chi kiem tra nguong toi KHI DEN TAT
  // Khi den da bat, lux tang se khong
  // lam den tat dot ngot.
  if (!lightActive) {
    if (isDark && motion) {
      lightActive = true;
    }
  }
}

// =====================================
// 10. TINH DO SANG THEO LUX
// =====================================
int calculateBrightness() {
  if (!lightActive) {
    return 0;
  }

  // BH1750 loi: do sang du phong
  if (!bhOK || !luxReady) {
    return 25;
  }

  float x = filteredLux;

  // Phong cuc toi: chong choi
  if (x < NIGHT_LUX) {
    return 12;
  }

  // Moi truong toi: sang vua phai
  if (x < 15.0f) {
    float ratio = (x - 5.0f) / 10.0f;
    return 28 + (int)(ratio * 20.0f);
  }

  // Thieu sang: tang do sang
  if (x < DARK_LUX) {
    float ratio = (x - 15.0f) / 15.0f;
    return 48 + (int)(ratio * 32.0f);
  }

  // Den dang bat: giu do sang
  // Khong buoc tang sang theo lux qua cao
  return 65;
}

// =====================================
// 11. MAU TRANG -> VANG AM
// =====================================
void calculateTemperatureColor(
  float temp,
  float &r,
  float &g,
  float &b
) {
  float ratio =
    (temp - TEMP_MIN) / (TEMP_MAX - TEMP_MIN);

  ratio = constrain(ratio, 0.0f, 1.0f);

  // Trang: 255,255,255
  // Vang am: 255,170,45
  r = 255.0f;
  g = 255.0f - 85.0f * ratio;
  b = 255.0f - 210.0f * ratio;
}

// =====================================
// 12. LAM MUOT LED (KHONG DELAY)
// =====================================
void updateLED(unsigned long now) {
  if (now - lastLEDUpdate < LED_INTERVAL) {
    return;
  }

  unsigned long elapsed =
    now - lastLEDUpdate;

  lastLEDUpdate = now;

  float r = 255;
  float g = 225;
  float b = 170;

  // Neu DHT11 tot, dung nhiet do
  if (dhtOK && tempReady) {
    calculateTemperatureColor(
      filteredTemp, r, g, b
    );
  }

  ledLevel = calculateBrightness();

  float scale =
    (float)ledLevel / 255.0f;

  float targetR = r * scale;
  float targetG = g * scale;
  float targetB = b * scale;

  // Gioi han toc do thay doi moi kenh
  // Bien thien toi da 80 muc / 1500ms
  float maxStep =
    (float)MAX_LED_LEVEL *
    (float)elapsed / (float)FADE_TIME;

  currentR += constrain(
    targetR - currentR,
    -maxStep,
    maxStep
  );

  currentG += constrain(
    targetG - currentG,
    -maxStep,
    maxStep
  );

  currentB += constrain(
    targetB - currentB,
    -maxStep,
    maxStep
  );

  uint8_t outR = (uint8_t)constrain(
    roundf(currentR), 0.0f, 255.0f
  );

  uint8_t outG = (uint8_t)constrain(
    roundf(currentG), 0.0f, 255.0f
  );

  uint8_t outB = (uint8_t)constrain(
    roundf(currentB), 0.0f, 255.0f
  );

  strip.fill(strip.Color(outR, outG, outB));
  strip.show();
}

// =====================================
// 13. SERIAL MONITOR DEBUG
// =====================================
void printDebug(unsigned long now) {
  if (now - lastPrint < PRINT_INTERVAL) {
    return;
  }

  lastPrint = now;

  Serial.println();
  Serial.println("====== ROOM LIGHT ======");

  Serial.print("BH1750: ");
  if (bhOK && luxReady) {
    Serial.print(rawLux, 1);
    Serial.print(" lux | Filter: ");
    Serial.println(filteredLux, 1);
  } else {
    Serial.println("ERROR / NOT READY");
  }

  Serial.print("PIR: ");
  if (!pirReady) {
    Serial.println("WARMUP");
  } else {
    Serial.println(
      motion ? "MOTION" : "NO MOTION"
    );
  }

  Serial.print("Temperature: ");
  if (dhtOK) {
    Serial.print(temperature, 1);
    Serial.println(" C");
  } else {
    Serial.println("ERROR");
  }

  Serial.print("Humidity: ");
  if (dhtOK) {
    Serial.print(humidity, 1);
    Serial.println(" %");
  } else {
    Serial.println("ERROR");
  }

  Serial.print("Environment: ");
  if (!bhOK || !luxReady) {
    Serial.println("SENSOR ERROR");
  } else {
    Serial.println(isDark ? "DARK" : "BRIGHT");
  }

  Serial.print("Light: ");
  Serial.println(
    lightActive ? "ON" : "OFF"
  );

  Serial.print("LED level: ");
  Serial.println(ledLevel);

  Serial.print("LED RGB: ");
  Serial.print((int)roundf(currentR));
  Serial.print(", ");
  Serial.print((int)roundf(currentG));
  Serial.print(", ");
  Serial.println((int)roundf(currentB));

  if (pirReady && hadMotion) {
    unsigned long elapsed = now - lastMotion;

    unsigned long remaining =
      elapsed >= HOLD_TIME
        ? 0
        : (HOLD_TIME - elapsed) / 1000UL;

    Serial.print("Hold remaining: ");
    Serial.print(remaining);
    Serial.println(" s");
  }

  Serial.println("========================");
}

// =====================================
// 14. SETUP
// =====================================

const char* WIFI_SSID = "TP-Link_24AC";          // Đổi thành tên WiFi
const char* WIFI_PASSWORD = "18289152";    // Đổi thành mật khẩu WiFi
const char* MQTT_BROKER = "broker.hivemq.com";
const int MQTT_PORT = 1883;
const char* MQTT_CLIENT_ID = "smart_led_esp32";

const char* TOPIC_PREFIX = "smart_led";
String topicColor;
String topicBrightness;
String topicEffect;
String topicPower;
String topicSensorLight;
String topicSensorMotion;
String topicAutoMode;
String topicNumLeds;


#define NUM_LEDS LED_COUNT
WiFiClient espClient;
PubSubClient mqttClient(espClient);
bool autoMode = true;
bool ledPower = false;
uint8_t ledR = 255, ledG = 255, ledB = 255;
int ledBrightness = 100;
int numLeds = LED_COUNT;
String currentEffect = "none";
int effectSpeed = 500;
int effectStep = 0;
bool effectDirection = true;
unsigned long lastEffectUpdate = 0;
unsigned long lastNetworkRetry = 0;
unsigned long lastTelemetry = 0;
const unsigned long NETWORK_RETRY = 5000UL;

void connectMQTT() {
  if (!mqttClient.connect(MQTT_CLIENT_ID)) return;
  mqttClient.subscribe(topicColor.c_str());
  mqttClient.subscribe(topicBrightness.c_str());
  mqttClient.subscribe(topicEffect.c_str());
  mqttClient.subscribe(topicPower.c_str());
  mqttClient.subscribe(topicAutoMode.c_str());
  mqttClient.subscribe(topicNumLeds.c_str());
}

void publishSensors(unsigned long now) {
  if (!mqttClient.connected() || now - lastTelemetry < 2000UL) return;
  lastTelemetry = now;
  String json;
  JsonDocument light;
  if (bhOK && luxReady) {
    light["lux"] = filteredLux;
    serializeJson(light, json);
    mqttClient.publish(topicSensorLight.c_str(), json.c_str());
  }
  JsonDocument pir;
  pir["detected"] = motion;
  pir["ready"] = pirReady;
  json = "";
  serializeJson(pir, json);
  mqttClient.publish(topicSensorMotion.c_str(), json.c_str());
  JsonDocument climate;
  climate["valid"] = dhtOK;
  if (dhtOK) {
    climate["temperature"] = temperature;
    climate["humidity"] = humidity;
  }
  json = "";
  serializeJson(climate, json);
  mqttClient.publish((String(TOPIC_PREFIX) + "/sensor/climate").c_str(), json.c_str());
}

void setup() {
  Serial.begin(115200);
  bootTime = millis();
  pinMode(PIR_PIN, INPUT);
  strip.begin();
  strip.clear();
  strip.show();
  Wire.begin(SDA_PIN, SCL_PIN);
  initBH1750();
  dht.begin();
  topicColor = String(TOPIC_PREFIX) + "/color";
  topicBrightness = String(TOPIC_PREFIX) + "/brightness";
  topicEffect = String(TOPIC_PREFIX) + "/effect";
  topicPower = String(TOPIC_PREFIX) + "/power";
  topicSensorLight = String(TOPIC_PREFIX) + "/sensor/light";
  topicSensorMotion = String(TOPIC_PREFIX) + "/sensor/motion";
  topicAutoMode = String(TOPIC_PREFIX) + "/auto_mode";
  topicNumLeds = String(TOPIC_PREFIX) + "/num_leds";
  mqttClient.setServer(MQTT_BROKER, MQTT_PORT);
  mqttClient.setCallback(mqttCallback);
  mqttClient.setBufferSize(512);
  mqttClient.setSocketTimeout(1);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  unsigned long now = millis();
  lastLightRead = lastDHTRead = lastLEDUpdate = lastPrint = now;
  lastNetworkRetry = now - NETWORK_RETRY;
  Serial.println("SMART ROOM LIGHT STARTED - PIR warmup: 45 seconds");
}

void loop() {
  unsigned long now = millis();
  if (!bhOK && now - lastBHRetry >= BH_RETRY) {
    lastBHRetry = now;
    initBH1750();
  }
  readLight(now);
  readDHT(now);
  readPIR(now);
  if (autoMode) {
    updateAutomation(now);
    updateLED(now);
  } else if (ledPower && currentEffect != "none" &&
             now - lastEffectUpdate >= (unsigned long)effectSpeed) {
    lastEffectUpdate = now;
    updateEffect();
  }
  printDebug(now);
  if (now - lastNetworkRetry >= NETWORK_RETRY) {
    lastNetworkRetry = now;
    if (WiFi.status() != WL_CONNECTED) WiFi.reconnect();
    else if (!mqttClient.connected()) connectMQTT();
  }
  if (mqttClient.connected()) mqttClient.loop();
  publishSensors(millis());
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
    String state = doc["state"] | "";
    if (state != "on" && state != "off") return;
    // A manual power command owns the strip until auto mode is explicitly enabled.
    autoMode = false;
    lightActive = false;
    currentR = currentG = currentB = 0;
    strip.setBrightness(map(ledBrightness, 0, 100, 0, MAX_LED_LEVEL));
    effectStep = 0;
    effectDirection = true;
    lastEffectUpdate = millis();
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
    ledBrightness = constrain(ledBrightness, 0, 100);
    if (!autoMode) strip.setBrightness(map(ledBrightness, 0, 100, 0, MAX_LED_LEVEL));
    strip.show();
  }
  else if (topicStr == topicEffect) {
    currentEffect = doc["type"] | "none";
    effectSpeed = constrain(doc["speed"] | 500, 25, 3000);
    effectStep = 0;
    effectDirection = true;
    
    if (currentEffect == "none" && ledPower) {
      setAllLeds(ledR, ledG, ledB);
    }
  }
  else if (topicStr == topicAutoMode) {
    autoMode = doc["enabled"] | false;
    if (autoMode) {
      strip.setBrightness(255);
      currentR = currentG = currentB = 0;
      lastLEDUpdate = millis();
      lightActive = false;
      strip.clear();
      strip.show();
    } else {
      strip.setBrightness(map(ledBrightness, 0, 100, 0, MAX_LED_LEVEL));
      if (ledPower) setAllLeds(ledR, ledG, ledB);
      else clearLeds();
    }
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


void setAllLeds(uint8_t r, uint8_t g, uint8_t b) {
  if (autoMode) return;
  for (int i = 0; i < numLeds; i++) {
    strip.setPixelColor(i, strip.Color(r, g, b));
  }
  strip.show();
}

void clearLeds() {
  if (autoMode) return;
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
