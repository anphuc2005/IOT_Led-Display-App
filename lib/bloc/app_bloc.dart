import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/mqtt_config.dart';
import '../services/ai_service.dart';
import '../services/mqtt_service.dart';
import '../services/storage_service.dart';

enum AppLoadStatus { initial, loading, ready, failure }

sealed class AppEvent extends Equatable {
  const AppEvent();
  @override
  List<Object?> get props => [];
}

final class AppStarted extends AppEvent {
  const AppStarted();
}

final class AppReconnectRequested extends AppEvent {
  const AppReconnectRequested();
}

final class AppDisconnectRequested extends AppEvent {
  const AppDisconnectRequested();
}

final class AppConfigurationApplied extends AppEvent {
  final MqttConfig config;
  final String apiKey;
  final bool autoMode;
  final int numLeds;
  const AppConfigurationApplied(
      {required this.config,
      required this.apiKey,
      required this.autoMode,
      required this.numLeds});
  @override
  List<Object?> get props => [config, apiKey, autoMode, numLeds];
}

final class _AppMqttStatusChanged extends AppEvent {
  final MqttStatusEvent event;
  const _AppMqttStatusChanged(this.event);
}

class AppState extends Equatable {
  final AppLoadStatus loadStatus;
  final MqttConnectionStatus connectionStatus;
  final MqttConfig config;
  final String apiKey;
  final bool autoMode;
  final int numLeds;
  final String? message;

  const AppState({
    this.loadStatus = AppLoadStatus.initial,
    this.connectionStatus = MqttConnectionStatus.disconnected,
    this.config = const MqttConfig(),
    this.apiKey = '',
    this.autoMode = false,
    this.numLeds = 30,
    this.message,
  });

  bool get isConnected => connectionStatus == MqttConnectionStatus.connected;

  AppState copyWith({
    AppLoadStatus? loadStatus,
    MqttConnectionStatus? connectionStatus,
    MqttConfig? config,
    String? apiKey,
    bool? autoMode,
    int? numLeds,
    String? message,
    bool clearMessage = false,
  }) =>
      AppState(
        loadStatus: loadStatus ?? this.loadStatus,
        connectionStatus: connectionStatus ?? this.connectionStatus,
        config: config ?? this.config,
        apiKey: apiKey ?? this.apiKey,
        autoMode: autoMode ?? this.autoMode,
        numLeds: numLeds ?? this.numLeds,
        message: clearMessage ? null : message ?? this.message,
      );

  @override
  List<Object?> get props => [
        loadStatus,
        connectionStatus,
        config,
        apiKey,
        autoMode,
        numLeds,
        message
      ];
}

class AppBloc extends Bloc<AppEvent, AppState> {
  final MqttService mqttService;
  final AiService aiService;
  final StorageService storageService;
  late final StreamSubscription<MqttStatusEvent> _mqttSubscription;

  AppBloc(
      {required this.mqttService,
      required this.aiService,
      required this.storageService})
      : super(const AppState()) {
    on<AppStarted>(_onStarted);
    on<AppReconnectRequested>(_onReconnect);
    on<AppDisconnectRequested>((event, emit) => mqttService.disconnect());
    on<AppConfigurationApplied>(_onConfigurationApplied);
    on<_AppMqttStatusChanged>((event, emit) {
      emit(state.copyWith(
          connectionStatus: event.event.status,
          message: event.event.message,
          clearMessage: event.event.message == null));
    });
    _mqttSubscription = mqttService.statusStream
        .listen((event) => add(_AppMqttStatusChanged(event)));
  }

  Future<void> _onStarted(AppStarted event, Emitter<AppState> emit) async {
    emit(state.copyWith(loadStatus: AppLoadStatus.loading, clearMessage: true));
    try {
      final values = await Future.wait<Object>([
        storageService.loadMqttConfig(),
        storageService.loadGeminiApiKey(),
        storageService.loadAutoMode(),
        storageService.loadNumLeds(),
      ]);
      final config = values[0] as MqttConfig;
      final apiKey = values[1] as String;
      mqttService.updateConfig(config);
      aiService.setApiKey(apiKey);
      emit(state.copyWith(
        loadStatus: AppLoadStatus.ready,
        config: config,
        apiKey: apiKey,
        autoMode: values[2] as bool,
        numLeds: values[3] as int,
        clearMessage: true,
      ));
      await mqttService.connect();
    } catch (error) {
      emit(state.copyWith(
          loadStatus: AppLoadStatus.failure,
          message: 'Không thể khởi tạo ứng dụng: $error'));
    }
  }

  Future<void> _onReconnect(
          AppReconnectRequested event, Emitter<AppState> emit) =>
      mqttService.connect();

  Future<void> _onConfigurationApplied(
      AppConfigurationApplied event, Emitter<AppState> emit) async {
    aiService.setApiKey(event.apiKey);
    emit(state.copyWith(
      config: event.config,
      apiKey: event.apiKey,
      autoMode: event.autoMode,
      numLeds: event.numLeds,
      clearMessage: true,
    ));
    await mqttService.reconnect(event.config);
  }

  @override
  Future<void> close() async {
    await _mqttSubscription.cancel();
    return super.close();
  }
}
