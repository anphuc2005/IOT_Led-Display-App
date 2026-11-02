import 'package:flutter_test/flutter_test.dart';
import 'package:smart_led_control/models/chat_message.dart';
import 'package:smart_led_control/models/led_state.dart';
import 'package:smart_led_control/providers/led_provider.dart';
import 'package:smart_led_control/services/ai_service.dart';
import 'package:smart_led_control/services/mqtt_service.dart';

void main() {
  test('LedProvider.executeCommands updates multi-action LED state properly', () {
    final mqtt = MqttService();
    final provider = LedProvider(mqtt);

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
      modelUsed: 'gemini-3.5-flash-lite',
    );
    expect(msg.allCommands.length, equals(1));
    expect(msg.allCommands.first['action'], equals('power'));
    expect(msg.modelUsed, equals('gemini-3.5-flash-lite'));
  });
}
