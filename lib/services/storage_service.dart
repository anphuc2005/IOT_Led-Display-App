import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mqtt_config.dart';

class StorageService {
  static const String _mqttConfigKey = 'mqtt_config';
  static const String _geminiApiKey = 'gemini_api_key';
  static const String _autoModeKey = 'auto_mode';
  static const String _numLedsKey = 'num_leds';

  Future<void> saveMqttConfig(MqttConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mqttConfigKey, jsonEncode(config.toJson()));
  }

  Future<MqttConfig> loadMqttConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_mqttConfigKey);
    if (data != null) {
      return MqttConfig.fromJson(jsonDecode(data));
    }
    return const MqttConfig();
  }

  Future<void> saveGeminiApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_geminiApiKey, key);
  }

  Future<String> loadGeminiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_geminiApiKey) ?? '';
  }

  Future<void> saveAutoMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoModeKey, enabled);
  }

  Future<bool> loadAutoMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoModeKey) ?? false;
  }

  Future<void> saveNumLeds(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_numLedsKey, count);
  }

  Future<int> loadNumLeds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_numLedsKey) ?? 30;
  }
}
