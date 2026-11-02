import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

class WyomingSttService {
  final AudioRecorder _audioRecorder = AudioRecorder();

  Socket? _socket;
  StreamSubscription<Uint8List>? _recordSubscription;
  StreamSubscription<Uint8List>? _socketSubscription;
  Completer<String>? _transcriptCompleter;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  /// Test connection to a Wyoming Vietnamese server via describe -> info event
  Future<bool> testConnection(String host, int port) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 4),
      );
      final completer = Completer<bool>();

      socket.listen(
        (data) {
          final text = utf8.decode(data, allowMalformed: true);
          if (text.contains('"type": "info"') || text.contains('"type":"info"')) {
            if (!completer.isCompleted) completer.complete(true);
          }
        },
        onError: (e) {
          if (!completer.isCompleted) completer.complete(false);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete(false);
        },
      );

      // Send Wyoming describe event
      const describeEvent = '{"type": "describe"}\n';
      socket.write(describeEvent);
      await socket.flush();

      final result = await completer.future.timeout(
        const Duration(seconds: 4),
        onTimeout: () => false,
      );
      await socket.close();
      return result;
    } catch (e) {
      debugPrint('Wyoming testConnection error: $e');
      return false;
    }
  }

  /// Start recording from microphone and stream 16kHz PCM audio to Wyoming server
  Future<void> startListening({
    required String host,
    required int port,
    required ValueChanged<String> onTranscriptReceived,
    required ValueChanged<String> onError,
  }) async {
    if (_isRecording) return;

    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        onError('Chưa cấp quyền Micro để thu âm giọng nói.');
        return;
      }

      // Connect TCP Socket to Wyoming server
      _socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );

      _transcriptCompleter = Completer<String>();
      _isRecording = true;

      final buffer = StringBuffer();

      _socketSubscription = _socket!.listen(
        (Uint8List data) {
          final str = utf8.decode(data, allowMalformed: true);
          buffer.write(str);

          // Process line by line
          final content = buffer.toString();
          if (content.contains('\n')) {
            final lines = content.split('\n');
            for (int i = 0; i < lines.length - 1; i++) {
              final line = lines[i].trim();
              if (line.isEmpty) continue;
              try {
                final json = jsonDecode(line) as Map<String, dynamic>;
                final type = json['type'] as String?;
                if (type == 'transcript') {
                  final text = json['data']?['text'] as String? ?? '';
                  if (!_transcriptCompleter!.isCompleted) {
                    _transcriptCompleter!.complete(text.trim());
                  }
                }
              } catch (e) {
                debugPrint('Wyoming parse event error: $e in line: $line');
              }
            }
            buffer.clear();
            buffer.write(lines.last);
          }
        },
        onError: (err) {
          debugPrint('Wyoming socket error: $err');
          _isRecording = false;
          onError('Lỗi kết nối máy chủ Wyoming STT: $err');
        },
        onDone: () {
          _isRecording = false;
        },
      );

      // 1. Send transcribe init event
      _sendWyomingEvent('{"type": "transcribe", "data": {"language": "vi"}}\n');

      // 2. Send audio-start event (16kHz 16-bit Mono PCM)
      _sendWyomingEvent(
        '{"type": "audio-start", "data": {"rate": 16000, "width": 2, "channels": 1}}\n',
      );

      // 3. Start audio stream from mic
      final audioStream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      _recordSubscription = audioStream.listen((Uint8List chunk) {
        if (!_isRecording || _socket == null) return;

        // Wyoming audio-chunk event
        final header = jsonEncode({
          'type': 'audio-chunk',
          'data': {
            'rate': 16000,
            'width': 2,
            'channels': 1,
          },
          'payload_length': chunk.length,
        });

        try {
          _socket!.write('$header\n');
          _socket!.add(chunk);
          _socket!.flush();
        } catch (e) {
          debugPrint('Error writing audio chunk to Wyoming socket: $e');
        }
      });
    } catch (e) {
      _isRecording = false;
      await _cleanup();
      debugPrint('Wyoming startListening error: $e');
      onError('Không thể kết nối máy chủ Wyoming ($host:$port): $e');
    }
  }

  void _sendWyomingEvent(String eventStr) {
    if (_socket != null) {
      _socket!.write(eventStr);
      _socket!.flush();
    }
  }

  /// Stop recording, send audio-stop to Wyoming server, and await transcript
  Future<String?> stopListening() async {
    if (!_isRecording) return null;
    _isRecording = false;

    try {
      await _recordSubscription?.cancel();
      _recordSubscription = null;
      await _audioRecorder.stop();

      // Send audio-stop event
      _sendWyomingEvent('{"type": "audio-stop"}\n');

      String? transcript;
      if (_transcriptCompleter != null && !_transcriptCompleter!.isCompleted) {
        transcript = await _transcriptCompleter!.future.timeout(
          const Duration(seconds: 8),
          onTimeout: () => '',
        );
      }

      await _cleanup();
      return transcript;
    } catch (e) {
      debugPrint('Wyoming stopListening error: $e');
      await _cleanup();
      return null;
    }
  }

  Future<void> cancelListening() async {
    _isRecording = false;
    await _recordSubscription?.cancel();
    _recordSubscription = null;
    await _audioRecorder.stop();
    await _cleanup();
  }

  Future<void> _cleanup() async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;
  }

  Future<void> dispose() async {
    await cancelListening();
    await _audioRecorder.dispose();
  }
}
