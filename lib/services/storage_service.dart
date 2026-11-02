import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mqtt_config.dart';

class StorageService {
  static const String _mqttConfigKey = 'mqtt_config';
  static const String _geminiApiKey = 'gemini_api_key';
  static const String _autoModeKey = 'auto_mode';
  static const String _numLedsKey = 'num_leds';
  static const String _voiceEnabledKey = 'ai_voice_enabled';

  /// Compile-time or default environment API Key
  static const String defaultGeminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

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
    final saved = prefs.getString(_geminiApiKey);
    if (saved != null && saved.trim().isNotEmpty) {
      return saved.trim();
    }
    return defaultGeminiApiKey;
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

  Future<void> saveVoiceEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_voiceEnabledKey, enabled);
  }

  Future<bool> loadVoiceEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_voiceEnabledKey) ?? true;
  }
}
