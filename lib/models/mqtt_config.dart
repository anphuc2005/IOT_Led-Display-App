import 'package:equatable/equatable.dart';

class MqttConfig extends Equatable {
  final String broker;
  final int port;
  final String username;
  final String password;
  final String clientId;
  final String topicPrefix;

  const MqttConfig({
    this.broker = 'test.mosquitto.org',
    this.port = 1883,
    this.username = '',
    this.password = '',
    this.clientId = 'smart_led_flutter',
    this.topicPrefix = 'smart_led',
  });

  MqttConfig copyWith(
          {String? broker,
          int? port,
          String? username,
          String? password,
          String? clientId,
          String? topicPrefix}) =>
      MqttConfig(
        broker: broker ?? this.broker,
        port: port ?? this.port,
        username: username ?? this.username,
        password: password ?? this.password,
        clientId: clientId ?? this.clientId,
        topicPrefix: topicPrefix ?? this.topicPrefix,
      );

  String get colorTopic => '$topicPrefix/color';
  String get brightnessTopic => '$topicPrefix/brightness';
  String get effectTopic => '$topicPrefix/effect';
  String get powerTopic => '$topicPrefix/power';
  String get sensorLightTopic => '$topicPrefix/sensor/light';
  String get sensorMotionTopic => '$topicPrefix/sensor/motion';
  String get autoModeTopic => '$topicPrefix/auto_mode';
  String get numLedsTopic => '$topicPrefix/num_leds';

  Map<String, dynamic> toJson() => {
        'broker': broker,
        'port': port,
        'username': username,
        'clientId': clientId,
        'topicPrefix': topicPrefix,
      };

  factory MqttConfig.fromJson(Map<String, dynamic> json) => MqttConfig(
        broker: json['broker'] as String? ?? 'test.mosquitto.org',
        port: json['port'] as int? ?? 1883,
        username: json['username'] as String? ?? '',
        password: json['password'] as String? ?? '',
        clientId: json['clientId'] as String? ?? 'smart_led_flutter',
        topicPrefix: json['topicPrefix'] as String? ?? 'smart_led',
      );

  @override
  List<Object> get props =>
      [broker, port, username, password, clientId, topicPrefix];
}
