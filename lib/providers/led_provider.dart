import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/led_state.dart';
import '../models/sensor_data.dart';
import '../services/mqtt_service.dart';

class LedProvider extends ChangeNotifier {
  final MqttService _mqttService;
  LedState _ledState = const LedState();
  SensorData _sensorData = SensorData();
  bool _autoMode = false;
  final List<SensorData> _lightHistory = [];
  StreamSubscription? _lightSub;
  StreamSubscription? _motionSub;

  LedProvider(this._mqttService) {
    _setupSubscriptions();
  }

  LedState get ledState => _ledState;
  SensorData get sensorData => _sensorData;
  bool get autoMode => _autoMode;
  List<SensorData> get lightHistory => List.unmodifiable(_lightHistory);

  void _setupSubscriptions() {
    final config = _mqttService.config;

    _lightSub = _mqttService.subscribe(config.sensorLightTopic).listen((data) {
      try {
        final json = jsonDecode(data);
        _sensorData = _sensorData.copyWith(
          lightIntensity: (json['lux'] as num).toDouble(),
          timestamp: DateTime.now(),
        );
        _lightHistory.add(_sensorData);
        if (_lightHistory.length > 100) _lightHistory.removeAt(0);

        if (_autoMode) {
          _autoAdjustBrightness();
        }
        notifyListeners();
      } catch (e) {
        debugPrint('Error parsing light sensor: $e');
      }
    });

    _motionSub = _mqttService.subscribe(config.sensorMotionTopic).listen((data) {
      try {
        final json = jsonDecode(data);
        _sensorData = _sensorData.copyWith(
          motionDetected: json['detected'] as bool,
          timestamp: DateTime.now(),
        );

        if (_autoMode && json['detected'] == true && !_ledState.isOn) {
          togglePower(true);
        }
        notifyListeners();
      } catch (e) {
        debugPrint('Error parsing motion sensor: $e');
      }
    });
  }

  void _autoAdjustBrightness() {
    final lux = _sensorData.lightIntensity;
    int brightness;
    if (lux < 50) {
      brightness = 100;
    } else if (lux < 200) {
      brightness = 80;
    } else if (lux < 500) {
      brightness = 50;
    } else {
      brightness = 20;
    }
    setBrightness(brightness);
  }

  void togglePower(bool on) {
    _ledState = _ledState.copyWith(isOn: on);
    _mqttService.publish(
      _mqttService.config.powerTopic,
      {'state': on ? 'on' : 'off'},
    );
    notifyListeners();
  }

  void setColor(Color color) {
    _ledState = _ledState.copyWith(color: color);
    _mqttService.publish(
      _mqttService.config.colorTopic,
      _ledState.toColorJson(),
    );
    notifyListeners();
  }

  void setBrightness(int brightness) {
    _ledState = _ledState.copyWith(brightness: brightness.clamp(0, 100));
    _mqttService.publish(
      _mqttService.config.brightnessTopic,
      {'value': _ledState.brightness},
    );
    notifyListeners();
  }

  void setEffect(LedEffect effect) {
    _ledState = _ledState.copyWith(effect: effect);
    _mqttService.publish(
      _mqttService.config.effectTopic,
      _ledState.toEffectJson(),
    );
    notifyListeners();
  }

  void setEffectSpeed(int speed) {
    _ledState = _ledState.copyWith(effectSpeed: speed.clamp(50, 3000));
    _mqttService.publish(
      _mqttService.config.effectTopic,
      _ledState.toEffectJson(),
    );
    notifyListeners();
  }

  void setAutoMode(bool enabled) {
    _autoMode = enabled;
    _mqttService.publish(
      _mqttService.config.autoModeTopic,
      {'enabled': enabled},
    );
    notifyListeners();
  }

  void setNumLeds(int count) {
    _ledState = _ledState.copyWith(numLeds: count.clamp(1, 300));
    _mqttService.publish(
      _mqttService.config.numLedsTopic,
      {'count': _ledState.numLeds},
    );
    notifyListeners();
  }

  /// Build current device & sensor context for AI prompt
  String buildStateContextSummary() {
    final c = _ledState.color;
    final r = (c.r * 255.0).round().clamp(0, 255);
    final g = (c.g * 255.0).round().clamp(0, 255);
    final b = (c.b * 255.0).round().clamp(0, 255);
    return 'Trạng thái đèn hiện tại: '
        'nguồn=${_ledState.isOn ? "BẬT" : "TẮT"}, '
        'màu=RGB($r, $g, $b), '
        'độ sáng=${_ledState.brightness}%, '
        'hiệu ứng=${_ledState.effect.mqttValue} (${_ledState.effect.displayName}, tốc độ ${_ledState.effectSpeed}ms), '
        'số bóng LED=${_ledState.numLeds}, '
        'chế độ tự động=${_autoMode ? "BẬT" : "TẮT"}, '
        'cảm biến ánh sáng=${_sensorData.lightIntensity.toStringAsFixed(1)} lux, '
        'chuyển động PIR=${_sensorData.motionDetected ? "CÓ NGƯỜI" : "KHÔNG"}.';
  }

  /// Execute multiple commands from AI assistant in optimal MQTT order
  void executeCommands(List<Map<String, dynamic>> commands) {
    if (commands.isEmpty) return;

    final hasAutoModeTrue = commands.any(
      (c) => c['action'] == 'auto_mode' && c['enabled'] == true,
    );
    final hasManualControl = commands.any(
      (c) =>
          c['action'] == 'power' ||
          c['action'] == 'color' ||
          c['action'] == 'brightness' ||
          c['action'] == 'effect',
    );
    final hasPowerCmd = commands.any((c) => c['action'] == 'power');
    final hasColorCmd = commands.any((c) => c['action'] == 'color');
    final hasEffectCmd = commands.any((c) => c['action'] == 'effect');

    if (hasManualControl && !hasAutoModeTrue && _autoMode) {
      setAutoMode(false);
    }

    // Ensure power is ON first on ESP32 before applying color/brightness/effect
    if (!hasPowerCmd &&
        (hasColorCmd ||
            hasEffectCmd ||
            commands.any((c) => c['action'] == 'brightness')) &&
        !_ledState.isOn) {
      togglePower(true);
    }

    // If user asks for a specific color without specifying an effect, clear rainbow/strobe
    if (hasColorCmd &&
        !hasEffectCmd &&
        (_ledState.effect == LedEffect.rainbow ||
            _ledState.effect == LedEffect.strobe)) {
      setEffect(LedEffect.none);
    }

    for (final cmd in commands) {
      executeCommand(cmd);
    }
  }

  /// Execute single command from AI assistant
  void executeCommand(Map<String, dynamic> command) {
    final action = command['action'] as String?;
    switch (action) {
      case 'power':
        togglePower(command['state'] == 'on');
        break;
      case 'color':
        if (!_ledState.isOn) togglePower(true);
        setColor(Color.fromARGB(
          255,
          ((command['r'] as num?)?.toInt() ?? 255).clamp(0, 255),
          ((command['g'] as num?)?.toInt() ?? 255).clamp(0, 255),
          ((command['b'] as num?)?.toInt() ?? 255).clamp(0, 255),
        ));
        break;
      case 'brightness':
        setBrightness(((command['value'] as num?)?.toInt() ?? 100).clamp(0, 100));
        break;
      case 'effect':
        if (!_ledState.isOn) togglePower(true);
        final type = command['type'] as String?;
        final effect = LedEffect.values.firstWhere(
          (e) => e.mqttValue == type,
          orElse: () => LedEffect.none,
        );
        if (command['speed'] != null) {
          _ledState = _ledState.copyWith(
            effect: effect,
            effectSpeed: ((command['speed'] as num).toInt()).clamp(50, 3000),
          );
          _mqttService.publish(
            _mqttService.config.effectTopic,
            _ledState.toEffectJson(),
          );
          notifyListeners();
        } else {
          setEffect(effect);
        }
        break;
      case 'auto_mode':
        setAutoMode(command['enabled'] as bool? ?? false);
        break;
      case 'num_leds':
        setNumLeds(((command['count'] as num?)?.toInt() ?? 8).clamp(1, 300));
        break;
    }
  }

  @override
  void dispose() {
    _lightSub?.cancel();
    _motionSub?.cancel();
    super.dispose();
  }
}
