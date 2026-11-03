import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/pronunciation_helper.dart';

/// Service providing high-fidelity Vietnamese speech synthesis (Cloud Vietnamese TTS + VieNeu-TTS)
/// with automatic pronunciation normalization for Smart LED technical terms.
class VieNeuTtsService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  http.Client? _activeClient;
  bool _isPlaying = false;
  bool _suppressAutoComplete = false;
  int _sessionId = 0;

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
    _configureAudioPlayer();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.playing) {
        _isPlaying = true;
        onStart?.call();
      } else if ((state == PlayerState.completed ||
              state == PlayerState.stopped) &&
          !_suppressAutoComplete) {
        _isPlaying = false;
        onComplete?.call();
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (!_suppressAutoComplete) {
        _isPlaying = false;
        onComplete?.call();
      }
    });
  }

  Future<void> _configureAudioPlayer() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setVolume(1.0);
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _audioPlayer.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              isSpeakerphoneOn: true,
              stayAwake: false,
              contentType: AndroidContentType.speech,
              usageType: AndroidUsageType.assistant,
              audioFocus: AndroidAudioFocus.gainTransientMayDuck,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('AudioPlayer context config warning: $e');
    }
  }

  bool get isPlaying => _isPlaying;

  /// Built-in Zero-Config Vietnamese Cloud TTS (works on all Android ROMs including Vivo V2419A / OriginOS
  /// that lack a local Vietnamese TTS engine, with no API key required).
  /// Streams sentence-by-sentence via temporary MP3 files so playback starts immediately and never fails on Android MediaPlayer.
  Future<bool> speakVietnameseCloud(String text) async {
    final normalizedText = PronunciationHelper.normalizeForTts(text);
    if (normalizedText.isEmpty) return false;

    await _stopInternal(notifyComplete: false);

    final currentSession = ++_sessionId;
    final client = http.Client();
    _activeClient = client;
    _suppressAutoComplete = true;

    try {
      final chunks = _splitTextIntoNaturalChunks(
        normalizedText,
        maxChunkLength: 160,
      );
      if (chunks.isEmpty) return false;

      // Pre-fetch first chunk immediately
      Future<Uint8List?>? nextChunkFuture =
          _fetchVietnameseMp3Chunk(client, chunks[0]);
      bool playedAny = false;

      for (int i = 0; i < chunks.length; i++) {
        if (_sessionId != currentSession) return playedAny;

        final chunkBytes = await nextChunkFuture;
        // Start pre-fetching the next chunk in parallel while current chunk plays
        if (i + 1 < chunks.length && _sessionId == currentSession) {
          nextChunkFuture = _fetchVietnameseMp3Chunk(client, chunks[i + 1]);
        } else {
          nextChunkFuture = null;
        }

        if (_sessionId != currentSession) return playedAny;
        if (chunkBytes == null || chunkBytes.isEmpty) {
          continue;
        }

        playedAny = true;
        _isPlaying = true;
        onStart?.call();

        await _playMp3BytesAndWait(
          chunkBytes,
          sessionId: currentSession,
          chunkIndex: i,
        );
      }

      if (_sessionId == currentSession && playedAny) {
        _isPlaying = false;
        onComplete?.call();
      }
      return playedAny;
    } catch (e) {
      debugPrint('Cloud Vietnamese TTS Error: $e');
      return false;
    } finally {
      if (_activeClient == client) {
        _activeClient = null;
      }
      if (_sessionId == currentSession) {
        _suppressAutoComplete = false;
        _isPlaying = false;
      }
    }
  }

  Future<Uint8List?> _fetchVietnameseMp3Chunk(
    http.Client client,
    String chunk,
  ) async {
    final endpoints = <Uri>[
      Uri.https('translate.google.com', '/translate_tts', {
        'ie': 'UTF-8',
        'client': 'tw-ob',
        'tl': 'vi',
        'q': chunk,
      }),
      Uri.https('translate.googleapis.com', '/translate_tts', {
        'ie': 'UTF-8',
        'client': 'gtx',
        'tl': 'vi',
        'q': chunk,
      }),
      Uri.https('translate.google.com.vn', '/translate_tts', {
        'ie': 'UTF-8',
        'client': 'tw-ob',
        'tl': 'vi',
        'q': chunk,
      }),
    ];

    for (final uri in endpoints) {
      try {
        final response = await client
            .get(
              uri,
              headers: const {
                'User-Agent':
                    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
                'Referer': 'https://translate.google.com/',
                'Accept': 'audio/mpeg, audio/*;q=0.9, */*;q=0.8',
              },
            )
            .timeout(const Duration(seconds: 6));

        if (response.statusCode == 200 && response.bodyBytes.length > 128) {
          return response.bodyBytes;
        }
      } catch (e) {
        debugPrint('TTS endpoint fallback (${uri.host}): $e');
      }
    }
    return null;
  }

  Future<void> _playMp3BytesAndWait(
    Uint8List mp3Bytes, {
    required int sessionId,
    required int chunkIndex,
  }) async {
    if (_sessionId != sessionId) return;

    File? tempFile;
    final completer = Completer<void>();
    StreamSubscription<void>? completeSub;
    StreamSubscription<PlayerState>? stateSub;

    void finish() {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    completeSub = _audioPlayer.onPlayerComplete.listen((_) => finish());
    stateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        finish();
      }
    });

    try {
      if (!kIsWeb) {
        final tempDir = Directory.systemTemp;
        tempFile = File(
          '${tempDir.path}${Platform.pathSeparator}smart_led_tts_${sessionId}_$chunkIndex.mp3',
        );
        await tempFile.writeAsBytes(mp3Bytes, flush: true);
        if (_sessionId != sessionId) return;
        await _audioPlayer.play(
          DeviceFileSource(tempFile.path, mimeType: 'audio/mpeg'),
        );
      } else {
        await _audioPlayer.play(
          BytesSource(mp3Bytes, mimeType: 'audio/mpeg'),
        );
      }

      // Wait for playback completion with safety timeout
      await completer.future.timeout(
        const Duration(seconds: 18),
        onTimeout: () {},
      );
    } catch (e) {
      debugPrint('Error playing MP3 chunk via DeviceFileSource, trying BytesSource: $e');
      try {
        await _audioPlayer.play(
          BytesSource(mp3Bytes, mimeType: 'audio/mpeg'),
        );
        await completer.future.timeout(
          const Duration(seconds: 18),
          onTimeout: () {},
        );
      } catch (_) {}
    } finally {
      await completeSub.cancel();
      await stateSub.cancel();
      if (tempFile != null) {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
      }
    }
  }

  List<String> _splitTextIntoNaturalChunks(
    String text, {
    int maxChunkLength = 160,
  }) {
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return const [];
    if (cleaned.length <= maxChunkLength) return [cleaned];

    // First split by sentence punctuation
    final sentences = cleaned.split(RegExp(r'(?<=[.!?;\n])\s+'));
    final chunks = <String>[];
    final current = StringBuffer();

    void flushCurrent() {
      final str = current.toString().trim();
      if (str.isNotEmpty) {
        chunks.add(str);
      }
      current.clear();
    }

    for (final sentence in sentences) {
      final trimmed = sentence.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.length <= maxChunkLength) {
        if (current.isEmpty) {
          current.write(trimmed);
        } else if (current.length + 1 + trimmed.length <= maxChunkLength) {
          current.write(' ');
          current.write(trimmed);
        } else {
          flushCurrent();
          current.write(trimmed);
        }
      } else {
        flushCurrent();
        // Split long sentence by comma or words
        final words = trimmed.split(' ');
        for (final word in words) {
          if (current.isEmpty) {
            current.write(word);
          } else if (current.length + 1 + word.length <= maxChunkLength) {
            current.write(' ');
            current.write(word);
          } else {
            flushCurrent();
            current.write(word);
          }
        }
        flushCurrent();
      }
    }
    flushCurrent();
    return chunks;
  }

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

    await _stopInternal(notifyComplete: false);
    final currentSession = ++_sessionId;
    _suppressAutoComplete = false;

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

      if (_sessionId != currentSession) return false;

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        await _playMp3BytesAndWait(
          response.bodyBytes,
          sessionId: currentSession,
          chunkIndex: 0,
        );
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

  Future<void> _stopInternal({required bool notifyComplete}) async {
    _sessionId++;
    _suppressAutoComplete = !notifyComplete;
    try {
      _activeClient?.close();
      _activeClient = null;
      await _audioPlayer.stop();
      _isPlaying = false;
      if (notifyComplete) {
        onComplete?.call();
      }
    } catch (e) {
      debugPrint('Error stopping VieNeu-TTS: $e');
    }
  }

  /// Stop current playback and cancel pending HTTP request
  Future<void> stop() async {
    await _stopInternal(notifyComplete: true);
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
        await _audioPlayer.play(
          BytesSource(response.bodyBytes, mimeType: 'audio/mpeg'),
        );
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
    _sessionId++;
    _activeClient?.close();
    _audioPlayer.dispose();
  }
}
