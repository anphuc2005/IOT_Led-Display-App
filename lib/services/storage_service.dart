import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mqtt_config.dart';

class StorageService {
  static const String _mqttConfigKey = 'mqtt_config';
  static const String _geminiApiKey = 'gemini_api_key';
  static const String _autoModeKey = 'auto_mode';
  static const String _numLedsKey = 'num_leds';
  static const String _voiceEnabledKey = 'ai_voice_enabled';
  static const String _wyomingHostKey = 'wyoming_host';
  static const String _wyomingPortKey = 'wyoming_port';
  static const String _wyomingEnabledKey = 'wyoming_enabled';
  static const String _vieneuTtsEnabledKey = 'vieneu_tts_enabled';
  static const String _vieneuTtsUrlKey = 'vieneu_tts_url';
  static const String _vieneuTtsVoiceKey = 'vieneu_tts_voice';
  static const String _vieneuTtsApiKeyKey = 'vieneu_tts_api_key';

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

  Future<void> saveWyomingConfig({
    required String host,
    required int port,
    required bool enabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_wyomingHostKey, host.trim());
    await prefs.setInt(_wyomingPortKey, port);
    await prefs.setBool(_wyomingEnabledKey, enabled);
  }

  Future<String> loadWyomingHost() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_wyomingHostKey) ?? '';
  }

  Future<int> loadWyomingPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_wyomingPortKey) ?? 10300;
  }

  Future<bool> loadWyomingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_wyomingEnabledKey) ?? false;
  }

  Future<void> saveVieNeuTtsConfig({
    required bool enabled,
    required String url,
    required String voice,
    required String apiKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vieneuTtsEnabledKey, enabled);
    await prefs.setString(_vieneuTtsUrlKey, url.trim());
    await prefs.setString(_vieneuTtsVoiceKey, voice.trim());
    await prefs.setString(_vieneuTtsApiKeyKey, apiKey.trim());
  }

  Future<bool> loadVieNeuTtsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_vieneuTtsEnabledKey) ?? false;
  }

  Future<String> loadVieNeuTtsUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_vieneuTtsUrlKey) ?? 'http://192.168.1.100:23333/v1';
  }

  Future<String> loadVieNeuTtsVoice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_vieneuTtsVoiceKey) ?? 'Minh Quân';
  }

  Future<String> loadVieNeuTtsApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_vieneuTtsApiKeyKey) ?? '';
  }
}
