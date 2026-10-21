import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/mqtt_config.dart';

enum AppConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

class MqttService extends ChangeNotifier {
  MqttServerClient? _client;
  MqttConfig _config = const MqttConfig();
  AppConnectionState _connectionState = AppConnectionState.disconnected;
  String _errorMessage = '';

  final Map<String, StreamController<String>> _topicControllers = {};

  AppConnectionState get connectionState => _connectionState;
  String get errorMessage => _errorMessage;
  MqttConfig get config => _config;
  bool get isConnected => _connectionState == AppConnectionState.connected;

  void updateConfig(MqttConfig config) {
    _config = config;
    notifyListeners();
  }

  Future<void> connect() async {
    if (_connectionState == AppConnectionState.connecting) return;

    _connectionState = AppConnectionState.connecting;
    _errorMessage = '';
    notifyListeners();

    try {
      _client = MqttServerClient.withPort(
        _config.broker,
        _config.clientId,
        _config.port,
      );

      _client!.logging(on: false);
      _client!.keepAlivePeriod = 30;
      _client!.autoReconnect = true;
      _client!.resubscribeOnAutoReconnect = true;
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onAutoReconnect = _onAutoReconnect;
      _client!.onAutoReconnected = _onAutoReconnected;

      final connMsg = MqttConnectMessage()
          .withClientIdentifier(_config.clientId)
          .startClean()
          .withWillQos(MqttQos.atMostOnce);

      if (_config.username.isNotEmpty) {
        connMsg.authenticateAs(_config.username, _config.password);
      }

      _client!.connectionMessage = connMsg;

      await _client!.connect();

      if (_client!.connectionStatus?.state ==
          MqttConnectionState.connected) {
        _connectionState = AppConnectionState.connected;
        _setupMessageListener();
      }
    } catch (e) {
      _connectionState = AppConnectionState.error;
      _errorMessage = e.toString();
      debugPrint('MQTT Connection Error: $e');
    }

    notifyListeners();
  }

  void _setupMessageListener() {
    _client!.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (final msg in messages) {
        final payload = msg.payload as MqttPublishMessage;
        final data = MqttPublishPayload.bytesToStringAsString(
          payload.payload.message,
        );
        final topic = msg.topic;

        if (_topicControllers.containsKey(topic)) {
          _topicControllers[topic]!.add(data);
        }
      }
    });
  }

  void disconnect() {
    _client?.disconnect();
    _connectionState = AppConnectionState.disconnected;
    notifyListeners();
  }

  void publish(String topic, Map<String, dynamic> data) {
    if (!isConnected || _client == null) return;

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(data));

    _client!.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    debugPrint('MQTT Published to $topic: ${jsonEncode(data)}');
  }

  void publishString(String topic, String data) {
    if (!isConnected || _client == null) return;

    final builder = MqttClientPayloadBuilder();
    builder.addString(data);

    _client!.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
  }

  Stream<String> subscribe(String topic) {
    if (!_topicControllers.containsKey(topic)) {
      _topicControllers[topic] = StreamController<String>.broadcast();
    }

    if (isConnected && _client != null) {
      _client!.subscribe(topic, MqttQos.atMostOnce);
    }

    return _topicControllers[topic]!.stream;
  }

  void _onConnected() {
    debugPrint('MQTT Connected');
    _connectionState = AppConnectionState.connected;

    // Re-subscribe to all topics
    for (final topic in _topicControllers.keys) {
      _client!.subscribe(topic, MqttQos.atMostOnce);
    }

    notifyListeners();
  }

  void _onDisconnected() {
    debugPrint('MQTT Disconnected');
    _connectionState = AppConnectionState.disconnected;
    notifyListeners();
  }

  void _onAutoReconnect() {
    debugPrint('MQTT Auto Reconnecting...');
    _connectionState = AppConnectionState.connecting;
    notifyListeners();
  }

  void _onAutoReconnected() {
    debugPrint('MQTT Auto Reconnected');
    _connectionState = AppConnectionState.connected;
    notifyListeners();
  }

  @override
  void dispose() {
    _client?.disconnect();
    for (final controller in _topicControllers.values) {
      controller.close();
    }
    _topicControllers.clear();
    super.dispose();
  }
}
