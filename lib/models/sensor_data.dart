import 'package:equatable/equatable.dart';

class SensorData extends Equatable {
  final double lightIntensity;
  final bool motionDetected;
  final DateTime timestamp;

  SensorData(
      {this.lightIntensity = 0,
      this.motionDetected = false,
      DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();

  SensorData copyWith(
          {double? lightIntensity,
          bool? motionDetected,
          DateTime? timestamp}) =>
      SensorData(
        lightIntensity: lightIntensity ?? this.lightIntensity,
        motionDetected: motionDetected ?? this.motionDetected,
        timestamp: timestamp ?? this.timestamp,
      );

  String get lightLevel {
    if (lightIntensity < 50) return 'Rất tối';
    if (lightIntensity < 200) return 'Tối';
    if (lightIntensity < 500) return 'Bình thường';
    if (lightIntensity < 1000) return 'Sáng';
    return 'Rất sáng';
  }

  @override
  List<Object> get props => [lightIntensity, motionDetected, timestamp];
}
