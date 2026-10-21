import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/mqtt_config.dart';
import '../services/storage_service.dart';

enum SettingsStatus { initial, loading, ready, saving, success, failure }

enum SettingsField {
  broker,
  port,
  username,
  password,
  topicPrefix,
  apiKey,
  numLeds
}

sealed class SettingsEvent extends Equatable {
  const SettingsEvent();
  @override
  List<Object?> get props => [];
}

final class SettingsRequested extends SettingsEvent {
  const SettingsRequested();
}

final class SettingsValueChanged extends SettingsEvent {
  final SettingsField field;
  final String value;
  const SettingsValueChanged(this.field, this.value);
  @override
  List<Object> get props => [field, value];
}

final class SettingsPasswordVisibilityToggled extends SettingsEvent {
  const SettingsPasswordVisibilityToggled();
}

final class SettingsApiKeyVisibilityToggled extends SettingsEvent {
  const SettingsApiKeyVisibilityToggled();
}

final class SettingsSubmitted extends SettingsEvent {
  const SettingsSubmitted();
}

class SettingsState extends Equatable {
  final SettingsStatus status;
  final String broker;
  final String port;
  final String username;
  final String password;
  final String topicPrefix;
  final String apiKey;
  final String numLeds;
  final bool obscurePassword;
  final bool obscureApiKey;
  final Map<SettingsField, String> errors;
  final String? message;

  const SettingsState({
    this.status = SettingsStatus.initial,
    this.broker = '',
    this.port = '1883',
    this.username = '',
    this.password = '',
    this.topicPrefix = 'smart_led',
    this.apiKey = '',
    this.numLeds = '30',
    this.obscurePassword = true,
    this.obscureApiKey = true,
    this.errors = const {},
    this.message,
  });

  MqttConfig get config => MqttConfig(
        broker: broker.trim(),
        port: int.tryParse(port) ?? 1883,
        username: username.trim(),
        password: password,
        topicPrefix: topicPrefix.trim(),
      );
  int get parsedNumLeds => int.tryParse(numLeds) ?? 30;

  SettingsState copyWith({
    SettingsStatus? status,
    String? broker,
    String? port,
    String? username,
    String? password,
    String? topicPrefix,
    String? apiKey,
    String? numLeds,
    bool? obscurePassword,
    bool? obscureApiKey,
    Map<SettingsField, String>? errors,
    String? message,
    bool clearMessage = false,
  }) =>
      SettingsState(
        status: status ?? this.status,
        broker: broker ?? this.broker,
        port: port ?? this.port,
        username: username ?? this.username,
        password: password ?? this.password,
        topicPrefix: topicPrefix ?? this.topicPrefix,
        apiKey: apiKey ?? this.apiKey,
        numLeds: numLeds ?? this.numLeds,
        obscurePassword: obscurePassword ?? this.obscurePassword,
        obscureApiKey: obscureApiKey ?? this.obscureApiKey,
        errors: errors ?? this.errors,
        message: clearMessage ? null : message ?? this.message,
      );

  @override
  List<Object?> get props => [
        status,
        broker,
        port,
        username,
        password,
        topicPrefix,
        apiKey,
        numLeds,
        obscurePassword,
        obscureApiKey,
        errors,
        message
      ];
}

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final StorageService storageService;
  SettingsBloc(this.storageService) : super(const SettingsState()) {
    on<SettingsRequested>(_onRequested);
    on<SettingsValueChanged>(_onValueChanged);
    on<SettingsPasswordVisibilityToggled>((event, emit) =>
        emit(state.copyWith(obscurePassword: !state.obscurePassword)));
    on<SettingsApiKeyVisibilityToggled>((event, emit) =>
        emit(state.copyWith(obscureApiKey: !state.obscureApiKey)));
    on<SettingsSubmitted>(_onSubmitted);
  }

  Future<void> _onRequested(
      SettingsRequested event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(status: SettingsStatus.loading, clearMessage: true));
    try {
      final values = await Future.wait<Object>([
        storageService.loadMqttConfig(),
        storageService.loadGeminiApiKey(),
        storageService.loadNumLeds(),
      ]);
      final config = values[0] as MqttConfig;
      emit(state.copyWith(
        status: SettingsStatus.ready,
        broker: config.broker,
        port: config.port.toString(),
        username: config.username,
        password: config.password,
        topicPrefix: config.topicPrefix,
        apiKey: values[1] as String,
        numLeds: (values[2] as int).toString(),
        errors: const {},
        clearMessage: true,
      ));
    } catch (error) {
      emit(state.copyWith(
          status: SettingsStatus.failure,
          message: 'Không thể tải cài đặt: $error'));
    }
  }

  void _onValueChanged(
      SettingsValueChanged event, Emitter<SettingsState> emit) {
    final errors = Map<SettingsField, String>.from(state.errors)
      ..remove(event.field);
    final next = switch (event.field) {
      SettingsField.broker =>
        state.copyWith(broker: event.value, errors: errors),
      SettingsField.port => state.copyWith(port: event.value, errors: errors),
      SettingsField.username =>
        state.copyWith(username: event.value, errors: errors),
      SettingsField.password =>
        state.copyWith(password: event.value, errors: errors),
      SettingsField.topicPrefix =>
        state.copyWith(topicPrefix: event.value, errors: errors),
      SettingsField.apiKey =>
        state.copyWith(apiKey: event.value, errors: errors),
      SettingsField.numLeds =>
        state.copyWith(numLeds: event.value, errors: errors),
    };
    emit(next.copyWith(status: SettingsStatus.ready, clearMessage: true));
  }

  Future<void> _onSubmitted(
      SettingsSubmitted event, Emitter<SettingsState> emit) async {
    final errors = <SettingsField, String>{};
    if (state.broker.trim().isEmpty) {
      errors[SettingsField.broker] = 'Vui lòng nhập địa chỉ broker.';
    }
    final port = int.tryParse(state.port);
    if (port == null || port < 1 || port > 65535) {
      errors[SettingsField.port] = 'Port phải nằm trong khoảng 1–65535.';
    }
    if (state.topicPrefix.trim().isEmpty) {
      errors[SettingsField.topicPrefix] = 'Topic prefix không được để trống.';
    }
    final count = int.tryParse(state.numLeds);
    if (count == null || count < 1 || count > 300) {
      errors[SettingsField.numLeds] = 'Số LED phải nằm trong khoảng 1–300.';
    }
    if (errors.isNotEmpty) {
      emit(state.copyWith(
          status: SettingsStatus.failure,
          errors: errors,
          message: 'Hãy kiểm tra lại các trường được đánh dấu.'));
      return;
    }

    emit(state.copyWith(
        status: SettingsStatus.saving, errors: const {}, clearMessage: true));
    try {
      await Future.wait([
        storageService.saveMqttConfig(state.config),
        storageService.saveGeminiApiKey(state.apiKey.trim()),
        storageService.saveNumLeds(state.parsedNumLeds),
      ]);
      emit(state.copyWith(
          status: SettingsStatus.success,
          message: 'Đã lưu cài đặt. Đang kết nối lại MQTT…'));
    } catch (error) {
      emit(state.copyWith(
          status: SettingsStatus.failure,
          message: 'Không thể lưu cài đặt: $error'));
    }
  }
}
