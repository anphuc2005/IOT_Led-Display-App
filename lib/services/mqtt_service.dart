import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/mqtt_config.dart';

enum MqttConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failure
}

class MqttStatusEvent {
  final MqttConnectionStatus status;
  final String? message;
  const MqttStatusEvent(this.status, [this.message]);
}

class MqttService {
  MqttServerClient? _client;
  StreamSubscription? _updatesSubscription;
  MqttConfig _config = const MqttConfig();
  MqttConnectionStatus _status = MqttConnectionStatus.disconnected;
  final _statusController = StreamController<MqttStatusEvent>.broadcast();
  final Map<String, StreamController<String>> _topicControllers = {};

  MqttConfig get config => _config;
  MqttConnectionStatus get status => _status;
  bool get isConnected => _status == MqttConnectionStatus.connected;
  Stream<MqttStatusEvent> get statusStream => _statusController.stream;

  void updateConfig(MqttConfig config) => _config = config;

  Future<void> connect() async {
    if (_status == MqttConnectionStatus.connecting) return;
    _setStatus(MqttConnectionStatus.connecting);
    await _updatesSubscription?.cancel();
    _client?.disconnect();

    try {
      final client = MqttServerClient.withPort(
          _config.broker, _config.clientId, _config.port);
      client.logging(on: false);
      client.keepAlivePeriod = 30;
      client.connectTimeoutPeriod = 8000;
      client.autoReconnect = true;
      client.resubscribeOnAutoReconnect = true;
      client.onConnected = _onConnected;
      client.onDisconnected = _onDisconnected;
      client.onAutoReconnect =
          () => _setStatus(MqttConnectionStatus.reconnecting);
      client.onAutoReconnected = _onConnected;

      var message = MqttConnectMessage()
          .withClientIdentifier(_config.clientId)
          .startClean()
          .withWillQos(MqttQos.atMostOnce);
      if (_config.username.isNotEmpty) {
        message.authenticateAs(_config.username, _config.password);
      }
      client.connectionMessage = message;
      _client = client;
      await client.connect();

      if (client.connectionStatus?.state != MqttConnectionState.connected) {
        throw StateError(
            client.connectionStatus?.returnCode.toString() ?? 'Không xác định');
      }
      if (!isConnected) _onConnected();
    } catch (error) {
      _client?.disconnect();
      _setStatus(
          MqttConnectionStatus.failure, 'Không thể kết nối MQTT: $error');
    }
  }

  Future<void> reconnect(MqttConfig config) async {
    updateConfig(config);
    await connect();
  }

  void disconnect() {
    _client?.disconnect();
    _setStatus(MqttConnectionStatus.disconnected);
  }

  bool publish(String topic, Map<String, dynamic> data) {
    final client = _client;
    if (!isConnected || client == null) return false;
    final builder = MqttClientPayloadBuilder()..addString(jsonEncode(data));
    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    return true;
  }

  Stream<String> subscribe(String topic) {
    final controller = _topicControllers.putIfAbsent(
        topic, StreamController<String>.broadcast);
    if (isConnected) _client?.subscribe(topic, MqttQos.atMostOnce);
    return controller.stream;
  }

  void unsubscribe(String topic) {
    _client?.unsubscribe(topic);
    final controller = _topicControllers.remove(topic);
    controller?.close();
  }

  void _listenForMessages() {
    _updatesSubscription?.cancel();
    _updatesSubscription = _client?.updates?.listen((messages) {
      for (final message in messages) {
        final payload = message.payload as MqttPublishMessage;
        final value =
            MqttPublishPayload.bytesToStringAsString(payload.payload.message);
        _topicControllers[message.topic]?.add(value);
      }
    });
  }

  void _onConnected() {
    _setStatus(MqttConnectionStatus.connected);
    for (final topic in _topicControllers.keys) {
      _client?.subscribe(topic, MqttQos.atMostOnce);
    }
    _listenForMessages();
  }

  void _onDisconnected() {
    if (_status != MqttConnectionStatus.failure) {
      _setStatus(MqttConnectionStatus.disconnected);
    }
  }

  void _setStatus(MqttConnectionStatus value, [String? message]) {
    _status = value;
    if (!_statusController.isClosed) {
      _statusController.add(MqttStatusEvent(value, message));
    }
  }

  Future<void> dispose() async {
    await _updatesSubscription?.cancel();
    _client?.disconnect();
    for (final controller in _topicControllers.values) {
      await controller.close();
    }
    await _statusController.close();
  }
}
