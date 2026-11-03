import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/led_state.dart';
import '../models/sensor_data.dart';
import '../services/mqtt_service.dart';

class LedProvider extends ChangeNotifier {
  final MqttService _mqttService;
  LedState _ledState = const LedState(numLeds: 8);
  SensorData _sensorData = SensorData();
  bool _autoMode = false;
  String _subscribedPrefix = '';
  final List<SensorData> _lightHistory = [];
  StreamSubscription? _lightSub;
  StreamSubscription? _motionSub;
  StreamSubscription? _climateSub;

  LedProvider(this._mqttService) {
    _setupSubscriptions();
    _mqttService.addListener(_onMqttChanged);
  }

  LedState get ledState => _ledState;
  SensorData get sensorData => _sensorData;
  bool get autoMode => _autoMode;
  List<SensorData> get lightHistory => List.unmodifiable(_lightHistory);

  /// Restores persisted LED count and auto-mode state during app initialization
  void restoreSavedState({required int numLeds, required bool autoMode}) {
    _ledState = _ledState.copyWith(numLeds: numLeds.clamp(1, 300));
    _autoMode = autoMode;
    notifyListeners();
  }

  void _onMqttChanged() {
    if (_mqttService.config.topicPrefix != _subscribedPrefix) {
      _setupSubscriptions();
    }
  }

  void _setupSubscriptions() {
    _lightSub?.cancel();
    _motionSub?.cancel();
    _climateSub?.cancel();

    final config = _mqttService.config;
    _subscribedPrefix = config.topicPrefix;

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
          motionDetected: json['detected'] as bool? ?? false,
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

    _climateSub =
        _mqttService.subscribe(config.sensorClimateTopic).listen((data) {
      try {
        final json = jsonDecode(data);
        if (json['valid'] == true) {
          _sensorData = _sensorData.copyWith(
            temperature: (json['temperature'] as num?)?.toDouble(),
            humidity: (json['humidity'] as num?)?.toDouble(),
            hasClimate: true,
            timestamp: DateTime.now(),
          );
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error parsing climate sensor: $e');
      }
    });
  }

  void _autoAdjustBrightness() {
    final lux = _sensorData.lightIntensity;
    int brightness;
    if (lux < 30) {
      brightness = 100;
    } else if (lux < 150) {
      brightness = 80;
    } else if (lux < 400) {
      brightness = 50;
    } else {
      brightness = 20;
    }
    setBrightness(brightness);
  }

  /// Ensures ESP32 exits autoMode and turns on ledPower when user manually adjusts color/brightness/effect
  void _ensureManualPowerOn() {
    if (!_ledState.isOn || _autoMode) {
      _autoMode = false;
      _ledState = _ledState.copyWith(isOn: true);
      _mqttService.publish(
        _mqttService.config.powerTopic,
        {'state': 'on'},
      );
    }
  }

  void togglePower(bool on) {
    if (on) {
      _autoMode = false;
    }
    _ledState = _ledState.copyWith(isOn: on);
    _mqttService.publish(
      _mqttService.config.powerTopic,
      {'state': on ? 'on' : 'off'},
    );
    notifyListeners();
  }

  void setColor(Color color) {
    _ensureManualPowerOn();
    _ledState = _ledState.copyWith(color: color);
    _mqttService.publish(
      _mqttService.config.colorTopic,
      _ledState.toColorJson(),
    );
    notifyListeners();
  }

  void setBrightness(int brightness) {
    _ensureManualPowerOn();
    _ledState = _ledState.copyWith(brightness: brightness.clamp(0, 100));
    _mqttService.publish(
      _mqttService.config.brightnessTopic,
      {'value': _ledState.brightness},
    );
    notifyListeners();
  }

  void setEffect(LedEffect effect) {
    _ensureManualPowerOn();
    _ledState = _ledState.copyWith(effect: effect);
    _mqttService.publish(
      _mqttService.config.effectTopic,
      _ledState.toEffectJson(),
    );
    notifyListeners();
  }

  void setEffectSpeed(int speed) {
    _ensureManualPowerOn();
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

  /// Sends a quick hardware test signal to ESP32 (Power ON + Cyan color + 100% brightness)
  void sendHardwareTestPing() {
    _autoMode = false;
    _ledState = _ledState.copyWith(
      isOn: true,
      color: const Color(0xFF00F5D4),
      brightness: 100,
      effect: LedEffect.none,
    );
    _mqttService.publish(_mqttService.config.powerTopic, {'state': 'on'});
    _mqttService.publish(_mqttService.config.brightnessTopic, {'value': 100});
    _mqttService.publish(_mqttService.config.effectTopic, {
      'type': 'none',
      'speed': _ledState.effectSpeed,
    });
    _mqttService.publish(
      _mqttService.config.colorTopic,
      {'r': 0, 'g': 245, 'b': 212},
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
        'chuyển động PIR=${_sensorData.motionDetected ? "CÓ NGƯỜI" : "KHÔNG"}'
        '${_sensorData.hasClimate ? ", nhiệt độ=${_sensorData.temperature.toStringAsFixed(1)}°C, độ ẩm=${_sensorData.humidity.toStringAsFixed(0)}%" : ""}.';
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
        _ensureManualPowerOn();
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
    _mqttService.removeListener(_onMqttChanged);
    _lightSub?.cancel();
    _motionSub?.cancel();
    _climateSub?.cancel();
    super.dispose();
  }
}
