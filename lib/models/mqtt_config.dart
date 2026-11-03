class MqttConfig {
  final String broker;
  final int port;
  final String username;
  final String password;
  final String clientId;
  final String topicPrefix;

  const MqttConfig({
    this.broker = 'broker.hivemq.com',
    this.port = 1883,
    this.username = '',
    this.password = '',
    this.clientId = 'smart_led_flutter',
    this.topicPrefix = 'smart_led',
  });

  MqttConfig copyWith({
    String? broker,
    int? port,
    String? username,
    String? password,
    String? clientId,
    String? topicPrefix,
  }) {
    return MqttConfig(
      broker: broker ?? this.broker,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      clientId: clientId ?? this.clientId,
      topicPrefix: topicPrefix ?? this.topicPrefix,
    );
  }

  // Topic helpers matching esp32_firmware/smart_led_esp32/smart_led_esp32.ino
  String get colorTopic => '$topicPrefix/color';
  String get brightnessTopic => '$topicPrefix/brightness';
  String get effectTopic => '$topicPrefix/effect';
  String get powerTopic => '$topicPrefix/power';
  String get sensorLightTopic => '$topicPrefix/sensor/light';
  String get sensorMotionTopic => '$topicPrefix/sensor/motion';
  String get sensorClimateTopic => '$topicPrefix/sensor/climate';
  String get autoModeTopic => '$topicPrefix/auto_mode';
  String get numLedsTopic => '$topicPrefix/num_leds';

  Map<String, dynamic> toJson() => {
        'broker': broker,
        'port': port,
        'username': username,
        'password': password,
        'clientId': clientId,
        'topicPrefix': topicPrefix,
      };

  factory MqttConfig.fromJson(Map<String, dynamic> json) => MqttConfig(
        broker: json['broker'] ?? 'broker.hivemq.com',
        port: json['port'] ?? 1883,
        username: json['username'] ?? '',
        password: json['password'] ?? '',
        clientId: json['clientId'] ?? 'smart_led_flutter',
        topicPrefix: json['topicPrefix'] ?? 'smart_led',
      );
}
