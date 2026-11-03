class SensorData {
  final double lightIntensity;
  final bool motionDetected;
  final double temperature;
  final double humidity;
  final bool hasClimate;
  final DateTime timestamp;

  SensorData({
    this.lightIntensity = 0.0,
    this.motionDetected = false,
    this.temperature = 25.0,
    this.humidity = 60.0,
    this.hasClimate = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  SensorData copyWith({
    double? lightIntensity,
    bool? motionDetected,
    double? temperature,
    double? humidity,
    bool? hasClimate,
    DateTime? timestamp,
  }) {
    return SensorData(
      lightIntensity: lightIntensity ?? this.lightIntensity,
      motionDetected: motionDetected ?? this.motionDetected,
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      hasClimate: hasClimate ?? this.hasClimate,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  String get lightLevel {
    if (lightIntensity < 5) return 'Tối hoàn toàn';
    if (lightIntensity < 30) return 'Phòng tối';
    if (lightIntensity < 150) return 'Vừa phải';
    if (lightIntensity < 500) return 'Đủ sáng';
    return 'Rất sáng';
  }
}
