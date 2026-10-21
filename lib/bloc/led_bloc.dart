import 'dart:async';
import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/led_state.dart';
import '../models/mqtt_config.dart';
import '../models/sensor_data.dart';
import '../services/mqtt_service.dart';
import '../services/storage_service.dart';

sealed class LedEvent extends Equatable {
  const LedEvent();
  @override
  List<Object?> get props => [];
}

final class LedConfigured extends LedEvent {
  final MqttConfig config;
  final bool autoMode;
  final int numLeds;
  const LedConfigured(this.config,
      {required this.autoMode, required this.numLeds});
  @override
  List<Object?> get props => [config, autoMode, numLeds];
}

final class LedSyncRequested extends LedEvent {
  const LedSyncRequested();
}

final class LedPowerChanged extends LedEvent {
  final bool value;
  const LedPowerChanged(this.value);
  @override
  List<Object> get props => [value];
}

final class LedColorDraftChanged extends LedEvent {
  final Color color;
  const LedColorDraftChanged(this.color);
  @override
  List<Object> get props => [color];
}

final class LedColorApplied extends LedEvent {
  final Color? color;
  const LedColorApplied([this.color]);
  @override
  List<Object?> get props => [color];
}

final class LedBrightnessPreviewed extends LedEvent {
  final int value;
  const LedBrightnessPreviewed(this.value);
  @override
  List<Object> get props => [value];
}

final class LedBrightnessCommitted extends LedEvent {
  final int value;
  const LedBrightnessCommitted(this.value);
  @override
  List<Object> get props => [value];
}

final class LedEffectChanged extends LedEvent {
  final LedEffect effect;
  const LedEffectChanged(this.effect);
  @override
  List<Object> get props => [effect];
}

final class LedEffectSpeedPreviewed extends LedEvent {
  final int speed;
  const LedEffectSpeedPreviewed(this.speed);
  @override
  List<Object> get props => [speed];
}

final class LedEffectSpeedChanged extends LedEvent {
  final int speed;
  const LedEffectSpeedChanged(this.speed);
  @override
  List<Object> get props => [speed];
}

final class LedAutoModeChanged extends LedEvent {
  final bool value;
  const LedAutoModeChanged(this.value);
  @override
  List<Object> get props => [value];
}

final class LedNumLedsChanged extends LedEvent {
  final int value;
  const LedNumLedsChanged(this.value);
  @override
  List<Object> get props => [value];
}

final class LedCommandRequested extends LedEvent {
  final Map<String, dynamic> command;
  const LedCommandRequested(this.command);
  @override
  List<Object> get props => [command];
}

final class LedSensorPausedChanged extends LedEvent {
  final bool value;
  const LedSensorPausedChanged(this.value);
  @override
  List<Object> get props => [value];
}

final class LedErrorCleared extends LedEvent {
  const LedErrorCleared();
}

final class _LedLightReceived extends LedEvent {
  final double lux;
  const _LedLightReceived(this.lux);
}

final class _LedMotionReceived extends LedEvent {
  final bool detected;
  const _LedMotionReceived(this.detected);
}

class LedBlocState extends Equatable {
  final LedState led;
  final Color draftColor;
  final SensorData sensor;
  final List<SensorData> lightHistory;
  final bool autoMode;
  final bool sensorPaused;
  final String? errorMessage;

  LedBlocState({
    this.led = const LedState(),
    Color? draftColor,
    SensorData? sensor,
    this.lightHistory = const [],
    this.autoMode = false,
    this.sensorPaused = false,
    this.errorMessage,
  })  : draftColor = draftColor ?? led.color,
        sensor = sensor ?? SensorData();

  LedBlocState copyWith({
    LedState? led,
    Color? draftColor,
    SensorData? sensor,
    List<SensorData>? lightHistory,
    bool? autoMode,
    bool? sensorPaused,
    String? errorMessage,
    bool clearError = false,
  }) =>
      LedBlocState(
        led: led ?? this.led,
        draftColor: draftColor ?? this.draftColor,
        sensor: sensor ?? this.sensor,
        lightHistory: lightHistory ?? this.lightHistory,
        autoMode: autoMode ?? this.autoMode,
        sensorPaused: sensorPaused ?? this.sensorPaused,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      );

  @override
  List<Object?> get props => [
        led,
        draftColor,
        sensor,
        lightHistory,
        autoMode,
        sensorPaused,
        errorMessage
      ];
}

class LedBloc extends Bloc<LedEvent, LedBlocState> {
  final MqttService mqttService;
  final StorageService storageService;
  MqttConfig _config = const MqttConfig();
  StreamSubscription<String>? _lightSubscription;
  StreamSubscription<String>? _motionSubscription;

  LedBloc({required this.mqttService, required this.storageService})
      : super(LedBlocState()) {
    on<LedConfigured>(_onConfigured);
    on<LedSyncRequested>(_onSyncRequested);
    on<LedPowerChanged>(_onPowerChanged);
    on<LedColorDraftChanged>((event, emit) =>
        emit(state.copyWith(draftColor: event.color, clearError: true)));
    on<LedColorApplied>(_onColorApplied);
    on<LedBrightnessPreviewed>((event, emit) => emit(state.copyWith(
        led: state.led.copyWith(brightness: event.value.clamp(0, 100)))));
    on<LedBrightnessCommitted>(_onBrightnessCommitted);
    on<LedEffectChanged>(_onEffectChanged);
    on<LedEffectSpeedPreviewed>((event, emit) => emit(state.copyWith(
        led: state.led.copyWith(effectSpeed: event.speed.clamp(50, 3000)))));
    on<LedEffectSpeedChanged>(_onEffectSpeedChanged);
    on<LedAutoModeChanged>(_onAutoModeChanged);
    on<LedNumLedsChanged>(_onNumLedsChanged);
    on<LedCommandRequested>(_onCommandRequested);
    on<LedSensorPausedChanged>(
        (event, emit) => emit(state.copyWith(sensorPaused: event.value)));
    on<LedErrorCleared>(
        (event, emit) => emit(state.copyWith(clearError: true)));
    on<_LedLightReceived>(_onLightReceived);
    on<_LedMotionReceived>(_onMotionReceived);
  }

  Future<void> _onConfigured(
      LedConfigured event, Emitter<LedBlocState> emit) async {
    await _cancelSensorSubscriptions();
    _config = event.config;
    final led = state.led.copyWith(numLeds: event.numLeds.clamp(1, 300));
    emit(state.copyWith(led: led, autoMode: event.autoMode, clearError: true));
    _lightSubscription =
        mqttService.subscribe(_config.sensorLightTopic).listen((payload) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        add(_LedLightReceived((data['lux'] as num).toDouble()));
      } catch (_) {
        add(const LedErrorCleared());
      }
    });
    _motionSubscription =
        mqttService.subscribe(_config.sensorMotionTopic).listen((payload) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        add(_LedMotionReceived(data['detected'] as bool));
      } catch (_) {
        add(const LedErrorCleared());
      }
    });
  }

  void _onPowerChanged(LedPowerChanged event, Emitter<LedBlocState> emit) {
    if (!_publish(
        _config.powerTopic, {'state': event.value ? 'on' : 'off'}, emit)) {
      return;
    }
    emit(state.copyWith(
        led: state.led.copyWith(isOn: event.value), clearError: true));
  }

  void _onSyncRequested(LedSyncRequested event, Emitter<LedBlocState> emit) {
    final led = state.led;
    final synced = mqttService.publish(
          _config.powerTopic,
          {'state': led.isOn ? 'on' : 'off'},
        ) &&
        mqttService.publish(_config.colorTopic, led.toColorJson()) &&
        mqttService.publish(
          _config.brightnessTopic,
          {'value': led.brightness},
        ) &&
        mqttService.publish(_config.effectTopic, led.toEffectJson()) &&
        mqttService.publish(
          _config.autoModeTopic,
          {'enabled': state.autoMode},
        ) &&
        mqttService.publish(_config.numLedsTopic, {'count': led.numLeds});
    if (synced) {
      emit(state.copyWith(clearError: true));
    } else {
      emit(state.copyWith(
          errorMessage: 'Không thể đồng bộ trạng thái với thiết bị.'));
    }
  }

  void _onColorApplied(LedColorApplied event, Emitter<LedBlocState> emit) {
    final color = event.color ?? state.draftColor;
    final next = state.led.copyWith(color: color);
    if (!_publish(_config.colorTopic, next.toColorJson(), emit)) return;
    emit(state.copyWith(led: next, draftColor: color, clearError: true));
  }

  void _onBrightnessCommitted(
      LedBrightnessCommitted event, Emitter<LedBlocState> emit) {
    final value = event.value.clamp(0, 100);
    if (!_publish(_config.brightnessTopic, {'value': value}, emit)) return;
    emit(state.copyWith(
        led: state.led.copyWith(brightness: value), clearError: true));
  }

  void _onEffectChanged(LedEffectChanged event, Emitter<LedBlocState> emit) {
    final next = state.led.copyWith(effect: event.effect);
    if (!_publish(_config.effectTopic, next.toEffectJson(), emit)) return;
    emit(state.copyWith(led: next, clearError: true));
  }

  void _onEffectSpeedChanged(
      LedEffectSpeedChanged event, Emitter<LedBlocState> emit) {
    final next = state.led.copyWith(effectSpeed: event.speed.clamp(50, 3000));
    if (!_publish(_config.effectTopic, next.toEffectJson(), emit)) return;
    emit(state.copyWith(led: next, clearError: true));
  }

  Future<void> _onAutoModeChanged(
      LedAutoModeChanged event, Emitter<LedBlocState> emit) async {
    if (!_publish(_config.autoModeTopic, {'enabled': event.value}, emit)) {
      return;
    }
    emit(state.copyWith(autoMode: event.value, clearError: true));
    await storageService.saveAutoMode(event.value);
  }

  Future<void> _onNumLedsChanged(
      LedNumLedsChanged event, Emitter<LedBlocState> emit) async {
    final value = event.value.clamp(1, 300);
    if (!_publish(_config.numLedsTopic, {'count': value}, emit)) return;
    emit(state.copyWith(
        led: state.led.copyWith(numLeds: value), clearError: true));
    await storageService.saveNumLeds(value);
  }

  void _onLightReceived(_LedLightReceived event, Emitter<LedBlocState> emit) {
    if (state.sensorPaused) return;
    final sensor = state.sensor
        .copyWith(lightIntensity: event.lux, timestamp: DateTime.now());
    final history = [...state.lightHistory, sensor];
    if (history.length > 120) history.removeRange(0, history.length - 120);
    emit(state.copyWith(
        sensor: sensor, lightHistory: List.unmodifiable(history)));
    if (state.autoMode) {
      final brightness = event.lux < 50
          ? 100
          : event.lux < 200
              ? 80
              : event.lux < 500
                  ? 50
                  : 20;
      if (brightness != state.led.brightness) {
        add(LedBrightnessCommitted(brightness));
      }
    }
  }

  void _onMotionReceived(_LedMotionReceived event, Emitter<LedBlocState> emit) {
    if (state.sensorPaused) return;
    emit(state.copyWith(
        sensor: state.sensor.copyWith(
            motionDetected: event.detected, timestamp: DateTime.now())));
    if (state.autoMode && event.detected && !state.led.isOn) {
      add(const LedPowerChanged(true));
    }
  }

  void _onCommandRequested(
      LedCommandRequested event, Emitter<LedBlocState> emit) {
    final command = event.command;
    try {
      switch (command['action']) {
        case 'power':
          final value = command['state'];
          if (value != 'on' && value != 'off') throw const FormatException();
          add(LedPowerChanged(value == 'on'));
          return;
        case 'color':
          final red = (command['r'] as num).toInt().clamp(0, 255);
          final green = (command['g'] as num).toInt().clamp(0, 255);
          final blue = (command['b'] as num).toInt().clamp(0, 255);
          add(LedColorApplied(Color.fromARGB(255, red, green, blue)));
          if (!state.led.isOn) add(const LedPowerChanged(true));
          return;
        case 'brightness':
          add(LedBrightnessCommitted((command['value'] as num).toInt()));
          return;
        case 'effect':
          final type = command['type'];
          final effect = LedEffect.values.firstWhere(
            (value) => value.mqttValue == type,
            orElse: () => throw const FormatException(),
          );
          add(LedEffectChanged(effect));
          if (command['speed'] != null) {
            add(LedEffectSpeedChanged((command['speed'] as num).toInt()));
          }
          if (!state.led.isOn) add(const LedPowerChanged(true));
          return;
        case 'auto_mode':
          add(LedAutoModeChanged(command['enabled'] as bool));
          return;
      }
    } catch (_) {
      emit(state.copyWith(
          errorMessage:
              'Lệnh AI không hợp lệ nên chưa được gửi tới thiết bị.'));
      return;
    }
    emit(state.copyWith(
        errorMessage:
            'Lệnh AI không được hỗ trợ nên chưa được gửi tới thiết bị.'));
  }

  bool _publish(
      String topic, Map<String, dynamic> payload, Emitter<LedBlocState> emit) {
    if (mqttService.publish(topic, payload)) return true;
    emit(state.copyWith(
        errorMessage:
            'Thiết bị đang ngoại tuyến. Hãy kết nối MQTT rồi thử lại.'));
    return false;
  }

  Future<void> _cancelSensorSubscriptions() async {
    await _lightSubscription?.cancel();
    await _motionSubscription?.cancel();
    mqttService.unsubscribe(_config.sensorLightTopic);
    mqttService.unsubscribe(_config.sensorMotionTopic);
  }

  @override
  Future<void> close() async {
    await _cancelSensorSubscriptions();
    return super.close();
  }
}
