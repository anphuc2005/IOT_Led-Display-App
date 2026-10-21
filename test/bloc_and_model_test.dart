import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_led_control/bloc/led_bloc.dart';
import 'package:smart_led_control/bloc/navigation_bloc.dart';
import 'package:smart_led_control/models/led_state.dart';
import 'package:smart_led_control/models/mqtt_config.dart';
import 'package:smart_led_control/models/sensor_data.dart';
import 'package:smart_led_control/services/mqtt_service.dart';
import 'package:smart_led_control/services/storage_service.dart';

void main() {
  group('NavigationBloc', () {
    blocTest<NavigationBloc, NavigationState>(
      'chuyển sang tab hợp lệ',
      build: NavigationBloc.new,
      act: (bloc) => bloc.add(const NavigationTabSelected(3)),
      expect: () => const [NavigationState(3)],
    );

    blocTest<NavigationBloc, NavigationState>(
      'bỏ qua tab ngoài phạm vi',
      build: NavigationBloc.new,
      act: (bloc) => bloc.add(const NavigationTabSelected(6)),
      expect: () => <NavigationState>[],
    );
  });

  group('LED domain', () {
    test('effect map đúng tên và MQTT value', () {
      expect(LedEffect.rainbow.displayName, 'Cầu vồng');
      expect(LedEffect.colorWipe.mqttValue, 'color_wipe');
    });

    test('sensor phân loại mức sáng ở các biên', () {
      expect(SensorData(lightIntensity: 49).lightLevel, 'Rất tối');
      expect(SensorData(lightIntensity: 50).lightLevel, 'Tối');
      expect(SensorData(lightIntensity: 200).lightLevel, 'Bình thường');
      expect(SensorData(lightIntensity: 1000).lightLevel, 'Rất sáng');
    });
  });

  group('MQTT config', () {
    test('tạo đúng topic theo prefix', () {
      const config = MqttConfig(topicPrefix: 'living_room');
      expect(config.powerTopic, 'living_room/power');
      expect(config.sensorLightTopic, 'living_room/sensor/light');
    });

    test('không ghi mật khẩu vào JSON thường', () {
      const config = MqttConfig(password: 'secret');
      expect(config.toJson().containsKey('password'), isFalse);
    });
  });

  group('LedBloc', () {
    final mqttService = _RecordingMqttService();

    blocTest<LedBloc, LedBlocState>(
      'đồng bộ đủ trạng thái thiết bị sau khi MQTT kết nối lại',
      build: () => LedBloc(
        mqttService: mqttService,
        storageService: StorageService(),
      ),
      act: (bloc) => bloc.add(const LedSyncRequested()),
      verify: (_) {
        expect(mqttService.published, hasLength(6));
        expect(
          mqttService.published.map((entry) => entry.$1),
          containsAll(<String>[
            'smart_led/power',
            'smart_led/color',
            'smart_led/brightness',
            'smart_led/effect',
            'smart_led/auto_mode',
            'smart_led/num_leds',
          ]),
        );
      },
    );

    blocTest<LedBloc, LedBlocState>(
      'từ chối lệnh AI sai định dạng thay vì làm BLoC lỗi',
      build: () {
        mqttService.published.clear();
        return LedBloc(
          mqttService: mqttService,
          storageService: StorageService(),
        );
      },
      act: (bloc) => bloc.add(
        const LedCommandRequested(<String, dynamic>{
          'action': 'color',
          'g': 80,
          'b': 120,
        }),
      ),
      expect: () => [
        isA<LedBlocState>().having(
          (state) => state.errorMessage,
          'errorMessage',
          'Lệnh AI không hợp lệ nên chưa được gửi tới thiết bị.',
        ),
      ],
      verify: (_) => expect(mqttService.published, isEmpty),
    );
  });
}

class _RecordingMqttService extends MqttService {
  final List<(String, Map<String, dynamic>)> published = [];

  @override
  bool publish(String topic, Map<String, dynamic> data) {
    published.add((topic, Map<String, dynamic>.from(data)));
    return true;
  }
}
