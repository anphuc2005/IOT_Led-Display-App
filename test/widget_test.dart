import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_led_control/models/chat_message.dart';
import 'package:smart_led_control/models/led_state.dart';
import 'package:smart_led_control/models/mqtt_config.dart';
import 'package:smart_led_control/models/sensor_data.dart';
import 'package:smart_led_control/providers/led_provider.dart';
import 'package:smart_led_control/services/ai_service.dart';
import 'package:smart_led_control/services/mqtt_service.dart';
import 'package:smart_led_control/services/wyoming_stt_service.dart';
import 'package:smart_led_control/services/vieneu_tts_service.dart';
import 'package:smart_led_control/utils/pronunciation_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('LedProvider.executeCommands updates multi-action LED state properly', () {
    final mqtt = MqttService();
    final provider = LedProvider(mqtt);

    expect(provider.ledState.numLeds, equals(8));

    provider.executeCommands([
      {'action': 'power', 'state': 'on'},
      {'action': 'color', 'r': 255, 'g': 180, 'b': 100},
      {'action': 'brightness', 'value': 20},
      {'action': 'effect', 'type': 'breathing', 'speed': 800},
    ]);

    expect(provider.ledState.isOn, isTrue);
    expect(provider.ledState.brightness, equals(20));
    expect(provider.ledState.effect, equals(LedEffect.breathing));
    expect(provider.ledState.effectSpeed, equals(800));
  });

  test('LedProvider.restoreSavedState restores numLeds and autoMode', () {
    final mqtt = MqttService();
    final provider = LedProvider(mqtt);

    provider.restoreSavedState(numLeds: 16, autoMode: true);
    expect(provider.ledState.numLeds, equals(16));
    expect(provider.autoMode, isTrue);
  });

  test('LedProvider autoMode stays ON when executeCommands receives auto_mode true alongside manual commands', () {
    final mqtt = MqttService();
    final provider = LedProvider(mqtt);

    provider.executeCommands([
      {'action': 'power', 'state': 'on'},
      {'action': 'auto_mode', 'enabled': true},
      {'action': 'brightness', 'value': 80},
    ]);

    expect(provider.autoMode, isTrue);
  });

  test('MqttConfig defaults match ESP32 HiveMQ firmware configuration', () {
    const config = MqttConfig();
    expect(config.broker, equals('broker.hivemq.com'));
    expect(config.port, equals(1883));
    expect(config.topicPrefix, equals('smart_led'));
    expect(config.colorTopic, equals('smart_led/color'));
    expect(config.sensorClimateTopic, equals('smart_led/sensor/climate'));
  });

  test('SensorData lightLevel thresholds work accurately', () {
    expect(SensorData(lightIntensity: 2).lightLevel, equals('Tối hoàn toàn'));
    expect(SensorData(lightIntensity: 20).lightLevel, equals('Phòng tối'));
    expect(SensorData(lightIntensity: 100).lightLevel, equals('Vừa phải'));
    expect(SensorData(lightIntensity: 300).lightLevel, equals('Đủ sáng'));
    expect(SensorData(lightIntensity: 800).lightLevel, equals('Rất sáng'));
  });

  test('AiService rotates through Gemini model pool properly', () {
    final ai = AiService();
    expect(ai.currentModelId, equals(AiService.modelPool.first.id));

    final rotated = ai.rotateToNextModel(reason: 'Hết lượt (429)');
    expect(rotated, equals(AiService.modelPool[1].id));
    expect(ai.isModelOnCooldown(AiService.modelPool.first.id), isTrue);
  });

  test('ChatMessage.allCommands returns commands list', () {
    final msg = ChatMessage(
      id: '1',
      content: 'Đã bật đèn',
      isUser: false,
      timestamp: DateTime.now(),
      commands: [
        {'action': 'power', 'state': 'on'},
      ],
      modelUsed: 'gemini-2.5-flash',
    );
    expect(msg.allCommands.length, equals(1));
    expect(msg.allCommands.first['action'], equals('power'));
    expect(msg.modelUsed, equals('gemini-2.5-flash'));
  });

  test('WyomingSttService initializes and reports not recording', () {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (call) async => null,
    );
    final wyoming = WyomingSttService();
    expect(wyoming.isRecording, isFalse);
  });

  test('PronunciationHelper correctly normalizes Smart LED technical terms', () {
    const rawText = '💡 Đã bật đèn LED RGB WS2812 với độ sáng 85% và chu kỳ 50ms.';
    final normalized = PronunciationHelper.normalizeForTts(rawText);

    expect(normalized.contains('đèn lét'), isTrue);
    expect(normalized.contains('rờ gờ bê'), isTrue);
    expect(normalized.contains('đúp-liu ét hai tám một hai'), isTrue);
    expect(normalized.contains('phần trăm'), isTrue);
    expect(normalized.contains('mili giây'), isTrue);
    expect(normalized.contains('💡'), isFalse);
  });

  test('PronunciationHelper strips json codeblocks and normalizes sensor acronyms', () {
    const rawText =
        'Cảm biến PIR và BH1750 ghi nhận 400lux.\n```json\n{"action": "power"}\n```';
    final normalized = PronunciationHelper.normalizeForTts(rawText);

    expect(normalized.contains('cảm biến chuyển động pi-a'), isTrue);
    expect(normalized.contains('bê-hát một bảy năm không'), isTrue);
    expect(normalized.contains('400 lắc'), isTrue);
    expect(normalized.contains('json'), isFalse);
    expect(normalized.contains('action'), isFalse);
  });

  test('VieNeuTtsService voices list contains standard 3-region voices', () {
    expect(VieNeuTtsService.availableVoices.contains('Minh Quân'), isTrue);
    expect(VieNeuTtsService.availableVoices.contains('Mai Phương'), isTrue);
    expect(VieNeuTtsService.availableVoices.contains('Văn Đức'), isTrue);
    expect(VieNeuTtsService.availableVoices.contains('Hải Yến'), isTrue);
    expect(VieNeuTtsService.availableVoices.contains('Quốc Bảo'), isTrue);
    expect(VieNeuTtsService.availableVoices.contains('Thảo Vy'), isTrue);
  });
}
