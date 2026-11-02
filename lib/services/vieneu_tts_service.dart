import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/pronunciation_helper.dart';

/// Service connecting to VieNeu-TTS server (https://github.com/pnnbao97/VieNeu-TTS)
/// for high-fidelity 48kHz Vietnamese speech synthesis with natural technical pronunciation.
class VieNeuTtsService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  http.Client? _activeClient;
  bool _isPlaying = false;

  void Function()? onStart;
  void Function()? onComplete;
  void Function(String error)? onError;

  static const List<String> availableVoices = [
    'Minh Quân', // Nam Bắc - Chuẩn tin tức / Trợ lý ảo
    'Mai Phương', // Nữ Bắc - Tự nhiên / Truyền cảm
    'Văn Đức', // Nam Trung - Rõ ràng
    'Hải Yến', // Nữ Trung - Ngọt ngào
    'Quốc Bảo', // Nam Nam - Trầm ấm
    'Thảo Vy', // Nữ Nam - Trẻ trung
  ];

  VieNeuTtsService() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.playing) {
        _isPlaying = true;
        onStart?.call();
      } else if (state == PlayerState.completed ||
          state == PlayerState.stopped) {
        _isPlaying = false;
        onComplete?.call();
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      _isPlaying = false;
      onComplete?.call();
    });
  }

  bool get isPlaying => _isPlaying;

  /// Synthesizes speech using VieNeu-TTS OpenAI-compatible API and plays audio.
  /// Automatically normalizes Smart LED technical acronyms before sending.
  Future<bool> speak({
    required String text,
    required String baseUrl,
    String voice = 'Minh Quân',
    String? apiKey,
    double speed = 1.0,
  }) async {
    final normalizedText = PronunciationHelper.normalizeForTts(text);
    if (normalizedText.isEmpty) return false;

    await stop();

    try {
      final endpoint = _resolveSpeechEndpoint(baseUrl);
      final client = http.Client();
      _activeClient = client;

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (apiKey != null && apiKey.trim().isNotEmpty) {
        headers['Authorization'] = 'Bearer ${apiKey.trim()}';
      }

      final body = jsonEncode({
        'model': 'vieneu-tts',
        'voice': voice,
        'input': normalizedText,
        'response_format': 'mp3',
        'speed': speed,
      });

      final response = await client
          .post(
            Uri.parse(endpoint),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        await _audioPlayer.play(BytesSource(response.bodyBytes));
        return true;
      } else {
        final errorMsg =
            'VieNeu-TTS HTTP ${response.statusCode}: ${response.body.isNotEmpty ? response.body : "Không có phản hồi"}';
        debugPrint(errorMsg);
        onError?.call(errorMsg);
        return false;
      }
    } catch (e) {
      debugPrint('VieNeu-TTS Error: $e');
      onError?.call(e.toString());
      return false;
    } finally {
      _activeClient = null;
    }
  }

  /// Stop current playback and cancel pending HTTP request
  Future<void> stop() async {
    try {
      _activeClient?.close();
      _activeClient = null;
      await _audioPlayer.stop();
      _isPlaying = false;
      onComplete?.call();
    } catch (e) {
      debugPrint('Error stopping VieNeu-TTS: $e');
    }
  }

  /// Test connection to VieNeu-TTS server and play test pronunciation
  Future<Map<String, dynamic>> testConnection({
    required String baseUrl,
    String voice = 'Minh Quân',
    String? apiKey,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final endpoint = _resolveSpeechEndpoint(baseUrl);
      final testPhrase =
          'Xin chào! Hệ thống đèn LED RGB WS2812 đã kết nối VieNeu-TTS thành công!';

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (apiKey != null && apiKey.trim().isNotEmpty) {
        headers['Authorization'] = 'Bearer ${apiKey.trim()}';
      }

      final body = jsonEncode({
        'model': 'vieneu-tts',
        'voice': voice,
        'input': PronunciationHelper.normalizeForTts(testPhrase),
        'response_format': 'mp3',
      });

      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 12));

      stopwatch.stop();

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        // Play sample audio so user can verify quality
        await _audioPlayer.play(BytesSource(response.bodyBytes));
        return {
          'success': true,
          'latencyMs': stopwatch.elapsedMilliseconds,
          'message':
              'Kết nối thành công! Đang phát thử giọng "$voice" (${response.bodyBytes.length} bytes, ${stopwatch.elapsedMilliseconds}ms).',
        };
      } else {
        return {
          'success': false,
          'latencyMs': stopwatch.elapsedMilliseconds,
          'message':
              'Server phản hồi mã lỗi ${response.statusCode}: ${response.body}',
        };
      }
    } catch (e) {
      stopwatch.stop();
      return {
        'success': false,
        'latencyMs': stopwatch.elapsedMilliseconds,
        'message': 'Không thể kết nối đến $baseUrl ($e)',
      };
    }
  }

  /// Properly resolves the speech endpoint URL from user input
  String _resolveSpeechEndpoint(String rawUrl) {
    var url = rawUrl.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.endsWith('/audio/speech')) {
      return url;
    }
    if (url.endsWith('/v1')) {
      return '$url/audio/speech';
    }
    return '$url/v1/audio/speech';
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
