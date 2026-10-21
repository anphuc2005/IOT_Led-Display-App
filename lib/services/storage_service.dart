import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mqtt_config.dart';

class StorageService {
  static const _mqttConfigKey = 'mqtt_config';
  static const _legacyGeminiKey = 'gemini_api_key';
  static const _autoModeKey = 'auto_mode';
  static const _numLedsKey = 'num_leds';
  static const _mqttPasswordKey = 'secure_mqtt_password';
  static const _geminiApiKey = 'secure_gemini_api_key';
  final FlutterSecureStorage _secureStorage;

  StorageService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<void> saveMqttConfig(MqttConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mqttConfigKey, jsonEncode(config.toJson()));
    await _secureStorage.write(key: _mqttPasswordKey, value: config.password);
  }

  Future<MqttConfig> loadMqttConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_mqttConfigKey);
    var config = raw == null
        ? const MqttConfig()
        : MqttConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    final securePassword = await _secureStorage.read(key: _mqttPasswordKey);
    final legacyPassword = raw == null
        ? ''
        : (jsonDecode(raw) as Map<String, dynamic>)['password'] as String? ??
            '';
    config = config.copyWith(password: securePassword ?? legacyPassword);
    if (securePassword == null && legacyPassword.isNotEmpty) {
      await saveMqttConfig(config);
    }
    return config;
  }

  Future<void> saveGeminiApiKey(String value) async {
    await _secureStorage.write(key: _geminiApiKey, value: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyGeminiKey);
  }

  Future<String> loadGeminiApiKey() async {
    final secureValue = await _secureStorage.read(key: _geminiApiKey);
    if (secureValue != null) return secureValue;
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_legacyGeminiKey) ?? '';
    if (legacy.isNotEmpty) {
      await saveGeminiApiKey(legacy);
    }
    return legacy;
  }

  Future<void> saveAutoMode(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_autoModeKey, value);
  Future<bool> loadAutoMode() async =>
      (await SharedPreferences.getInstance()).getBool(_autoModeKey) ?? false;
  Future<void> saveNumLeds(int value) async =>
      (await SharedPreferences.getInstance()).setInt(_numLedsKey, value);
  Future<int> loadNumLeds() async =>
      (await SharedPreferences.getInstance()).getInt(_numLedsKey) ?? 30;
}
