import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../models/led_state.dart';
import '../providers/led_provider.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../services/wyoming_stt_service.dart';
import '../services/vieneu_tts_service.dart';
import '../utils/pronunciation_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_glass.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final Set<String> _animatedMessageIds = {};
  final _uuid = const Uuid();

  // Voice TTS & STT
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _speech = SpeechToText();
  final WyomingSttService _wyomingStt = WyomingSttService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _directRecordSub;
  BytesBuilder _pcmBuffer = BytesBuilder(copy: false);
  bool _isRecordingDirectAudio = false;
  bool _hasDetectedVoice = false;
  int _noiseFloor = 300;
  double _currentMicLevel = 0.2;
  DateTime? _recordStartTime;
  DateTime? _lastVoiceTime;

  bool _isLoading = false;
  bool _voiceEnabled = true;
  bool _isSpeaking = false;
  bool _localViTtsAvailable = false;
  String? _speakingMessageId;

  // VieNeu-TTS settings
  bool _vieneuEnabled = false;
  String _vieneuUrl = '';
  String _vieneuVoice = 'Minh Quân';
  String _vieneuApiKey = '';

  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isUsingWyoming = false;
  String _partialSpeech = '';
  bool _showQuickControls = false;

  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    final welcomeId = _uuid.v4();
    _animatedMessageIds.add(welcomeId);
    _messages.add(ChatMessage(
      id: welcomeId,
      content:
          'Xin chào! Mình là Trợ lý AI điều khiển đèn LED thông minh.\n'
          'Bạn có thể chạm nút Micro 🎙️ để nói bằng tiếng Việt hoặc chọn nhanh các gợi ý bên dưới để bật/tắt, đổi màu và chỉnh hiệu ứng đèn nhé!',
      isUser: false,
      timestamp: DateTime.now(),
      modelUsed: 'smart-led-agent',
    ));

    _initVoiceServices();
  }

  Future<void> _initVoiceServices() async {
    final storage = context.read<StorageService>();
    final vieneu = context.read<VieNeuTtsService>();

    final savedVoice = await storage.loadVoiceEnabled();
    final vieneuEnabled = await storage.loadVieNeuTtsEnabled();
    final vieneuUrl = await storage.loadVieNeuTtsUrl();
    final vieneuVoice = await storage.loadVieNeuTtsVoice();
    final vieneuApiKey = await storage.loadVieNeuTtsApiKey();

    if (mounted) {
      setState(() {
        _voiceEnabled = savedVoice;
        _vieneuEnabled = vieneuEnabled && vieneuUrl.isNotEmpty;
        _vieneuUrl = vieneuUrl;
        _vieneuVoice = vieneuVoice;
        _vieneuApiKey = vieneuApiKey;
      });
    }

    // Configure VieNeu-TTS listeners
    try {
      vieneu.onStart = () {
        if (mounted) setState(() => _isSpeaking = true);
      };
      vieneu.onComplete = () {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _speakingMessageId = null;
          });
        }
      };
      vieneu.onError = (err) {
        debugPrint('VieNeu-TTS playback error: $err');
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _speakingMessageId = null;
          });
        }
      };
    } catch (e) {
      debugPrint('Failed to bind VieNeuTtsService: $e');
    }

    // Configure FlutterTts for Vietnamese
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playAndRecord,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          await _tts.setEngine('com.google.android.tts');
        } catch (_) {}
      }

      try {
        final viAvail = await _tts.isLanguageAvailable('vi-VN');
        final viShortAvail = await _tts.isLanguageAvailable('vi');
        _localViTtsAvailable = (viAvail == true || viShortAvail == true);
      } catch (_) {
        _localViTtsAvailable = false;
      }

      if (_localViTtsAvailable) {
        await _tts.setLanguage('vi-VN');
      }
      await _tts.setSpeechRate(
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS ? 0.50 : 0.55,
      );
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setStartHandler(() {
        if (mounted) {
          setState(() => _isSpeaking = true);
        }
      });

      _tts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _speakingMessageId = null;
          });
        }
      });

      _tts.setCancelHandler(() {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _speakingMessageId = null;
          });
        }
      });

      _tts.setErrorHandler((msg) {
        debugPrint('TTS Error: $msg');
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _speakingMessageId = null;
          });
        }
      });
    } catch (e) {
      debugPrint('Failed to init TTS: $e');
    }
  }

  @override
  void dispose() {
    _directRecordSub?.cancel();
    _audioRecorder.dispose();
    _tts.stop();
    try {
      context.read<VieNeuTtsService>().stop();
    } catch (_) {}
    _speech.stop();
    _wyomingStt.dispose();
    _waveController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleVoiceEnabled() async {
    final next = !_voiceEnabled;
    setState(() => _voiceEnabled = next);
    if (!next && _isSpeaking) {
      await _stopSpeaking();
    }
    if (mounted) {
      await context.read<StorageService>().saveVoiceEnabled(next);
    }
  }

  Future<void> _speakText(String messageId, String text) async {
    if (text.trim().isEmpty) return;
    final normalized = PronunciationHelper.normalizeForTts(text);
    if (normalized.isEmpty) return;

    try {
      await _stopSpeaking();
      if (!mounted) return;

      setState(() {
        _isSpeaking = true;
        _speakingMessageId = messageId;
      });

      final vieneu = context.read<VieNeuTtsService>();

      // 1. Try custom VieNeu-TTS server if explicitly enabled
      if (_vieneuEnabled && _vieneuUrl.isNotEmpty) {
        final ok = await vieneu.speak(
          text: normalized,
          baseUrl: _vieneuUrl,
          voice: _vieneuVoice,
          apiKey: _vieneuApiKey,
        );
        if (ok) return;
      }

      // 2. Always use built-in Vietnamese Cloud TTS first so phones without local Vietnamese TTS
      // (such as Vivo V2419A / OriginOS China ROM) speak 100% natural Vietnamese instead of English
      final cloudOk = await vieneu.speakVietnameseCloud(normalized);
      if (cloudOk) return;

      // 3. Offline local device TTS fallback (only if Vietnamese voice pack is actually installed)
      if (_localViTtsAvailable) {
        await _tts.speak(normalized);
      } else {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _speakingMessageId = null;
          });
        }
      }
    } catch (e) {
      debugPrint('Error speaking text: $e');
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _speakingMessageId = null;
        });
      }
    }
  }

  Future<void> _stopSpeaking() async {
    try {
      final vieneu = context.read<VieNeuTtsService>();
      await vieneu.stop();
    } catch (_) {}
    await _tts.stop();
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _speakingMessageId = null;
      });
    }
  }

  Future<void> _toggleListening() async {
    if (_isLoading) return;

    if (_isListening) {
      if (_isRecordingDirectAudio) {
        await _stopAndSendDirectAudioRecording();
      } else if (_isUsingWyoming) {
        setState(() => _isListening = false);
        final transcript = await _wyomingStt.stopListening();
        if (transcript != null && transcript.trim().isNotEmpty) {
          _controller.text = transcript.trim();
          await _sendMessage();
        }
      } else {
        await _speech.stop();
        setState(() => _isListening = false);
        if (_controller.text.trim().isNotEmpty) {
          await _sendMessage();
        }
      }
      return;
    }

    final storage = context.read<StorageService>();
    final aiService = context.read<AiService>();

    // Stop AI TTS before listening to user
    if (_isSpeaking) {
      await _stopSpeaking();
    }
    if (!mounted) return;

    // Check if Wyoming Vietnamese STT is enabled & configured
    final wyEnabled = await storage.loadWyomingEnabled();
    final wyHost = await storage.loadWyomingHost();
    final wyPort = await storage.loadWyomingPort();

    if (wyEnabled && wyHost.isNotEmpty) {
      _isUsingWyoming = true;
      setState(() {
        _isListening = true;
        _partialSpeech =
            'Đang nghe bằng Wyoming Vietnamese STT ($wyHost:$wyPort)...';
      });

      await _wyomingStt.startListening(
        host: wyHost,
        port: wyPort,
        onTranscriptReceived: (transcript) {
          if (!mounted) return;
          if (transcript.isNotEmpty) {
            _controller.text = transcript;
            _sendMessage();
          }
        },
        onError: (err) async {
          if (!mounted) return;
          await _wyomingStt.cancelListening();
          await _startDirectAudioRecording();
        },
      );
      return;
    }

    _isUsingWyoming = false;

    // When Gemini API Key is configured, use direct hardware PCM microphone recording + Gemini Audio STT
    // so it works 100% reliably on all devices (including Vivo V2419A OriginOS where system SpeechRecognizer lacks Vietnamese)
    if (aiService.hasApiKey) {
      await _startDirectAudioRecording();
      return;
    }

    await _startDeviceListening();
  }

  /// Records 16kHz 16-bit Mono PCM directly from the hardware microphone using `AudioRecorder`
  /// and transcribes + processes Vietnamese speech via Gemini Multimodal Audio.
  Future<void> _startDirectAudioRecording({bool fallbackDone = false}) async {
    try {
      bool hasPerm = false;
      try {
        hasPerm = await _audioRecorder.hasPermission();
      } catch (e) {
        debugPrint('hasPermission check error: $e');
      }

      if (!hasPerm) {
        // Try SpeechToText permission check as secondary verification in case record plugin check fails
        final speechPerm = await _speech.hasPermission;
        if (!speechPerm) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Vui lòng cấp quyền Micro (Ghi âm) cho ứng dụng để nói chuyện bằng giọng nói.',
              ),
              backgroundColor: AppTheme.accentOrange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
          return;
        }
      }

      await _directRecordSub?.cancel();
      _pcmBuffer = BytesBuilder(copy: false);
      _isRecordingDirectAudio = true;
      _hasDetectedVoice = false;
      _noiseFloor = 300;
      _currentMicLevel = 0.2;
      final now = DateTime.now();
      _recordStartTime = now;
      _lastVoiceTime = now;

      setState(() {
        _isListening = true;
        _isUsingWyoming = false;
        _partialSpeech =
            '🎙️ Đang thu giọng nói tiếng Việt... Nói xong bấm "Gửi ngay" hoặc "Chuyển chữ"';
      });

      final stream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
          androidConfig: AndroidRecordConfig(
            manageBluetooth: false,
            audioSource: AndroidAudioSource.voiceRecognition,
          ),
        ),
      );

      _directRecordSub = stream.listen(
        (Uint8List chunk) {
          if (!_isRecordingDirectAudio || !mounted) return;
          _pcmBuffer.add(chunk);

          // Measure peak 16-bit signed PCM amplitude for adaptive voice activity detection
          int maxAmp = 0;
          final byteData = ByteData.sublistView(chunk);
          for (int i = 0; i + 1 < chunk.length; i += 2) {
            final sample = byteData.getInt16(i, Endian.little).abs();
            if (sample > maxAmp) maxAmp = sample;
          }

          final currentTime = DateTime.now();
          final elapsedMs = currentTime
              .difference(_recordStartTime ?? currentTime)
              .inMilliseconds;

          if (elapsedMs < 350) {
            // Calibrate ambient noise floor during the first 350ms
            _noiseFloor = ((_noiseFloor * 2 + maxAmp) ~/ 3).clamp(180, 1800);
          } else {
            final threshold = (_noiseFloor * 1.85).round().clamp(420, 3200);
            if (maxAmp > threshold) {
              _hasDetectedVoice = true;
              _lastVoiceTime = currentTime;
            }
          }

          final elapsedSec = elapsedMs ~/ 1000;
          final level = (maxAmp / 6000.0).clamp(0.15, 1.0);

          setState(() {
            _currentMicLevel = level;
            _partialSpeech = _hasDetectedVoice
                ? '🎙️ Đang thu tiếng Việt (${elapsedSec}s)... Ngừng nói 2s tự gửi hoặc bấm "Chuyển chữ"'
                : '🎙️ Đang nghe (${elapsedSec}s)... Hãy nói câu lệnh đèn hoặc bấm "Chuyển chữ"';
          });

          // Auto-send after 2.2s of silence once user has spoken (at least 1.5s total recording)
          if (_hasDetectedVoice &&
              currentTime
                      .difference(_lastVoiceTime ?? currentTime)
                      .inMilliseconds >
                  2200 &&
              elapsedMs > 1500) {
            _stopAndSendDirectAudioRecording();
          } else if (elapsedSec >= 15) {
            _stopAndSendDirectAudioRecording();
          }
        },
        onError: (err) {
          debugPrint('Direct audio recorder error: $err');
          if (mounted) {
            setState(() {
              _isRecordingDirectAudio = false;
              _isListening = false;
            });
          }
        },
      );
    } catch (e) {
      debugPrint('Failed to start direct audio recording: $e');
      if (mounted) {
        setState(() {
          _isRecordingDirectAudio = false;
          _isListening = false;
        });
      }
      if (!fallbackDone) {
        await _startDeviceListening(fallbackDone: true);
      }
    }
  }

  Future<void> _stopAndSendDirectAudioRecording({
    bool insertIntoTextFieldOnly = false,
  }) async {
    if (!_isRecordingDirectAudio) return;
    _isRecordingDirectAudio = false;

    try {
      await _directRecordSub?.cancel();
      _directRecordSub = null;
      await _audioRecorder.stop();
    } catch (e) {
      debugPrint('Error stopping audio recorder: $e');
    }

    final rawPcmBytes = _pcmBuffer.takeBytes();
    if (!mounted) return;

    setState(() {
      _isListening = false;
      _partialSpeech = '';
    });

    if (rawPcmBytes.length < 3200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Thời gian ghi âm quá ngắn. Bạn hãy bấm Micro, nói câu hỏi/lệnh rồi bấm "Gửi ngay" nhé!',
          ),
          backgroundColor: AppTheme.accentOrange,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final aiService = context.read<AiService>();
    final ledProvider = context.read<LedProvider>();

    if (!aiService.hasApiKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Vui lòng nhập Gemini API Key trong mục Cài đặt để chuyển giọng nói tiếng Việt thành văn bản trên thiết bị này.',
          ),
          backgroundColor: AppTheme.accentOrange,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final normalizedPcm = _normalizePcm16(rawPcmBytes);
    final wavBytes = _buildWavBytes(normalizedPcm, sampleRate: 16000);

    // Mode 1: Transcribe Vietnamese speech directly into the text input field
    if (insertIntoTextFieldOnly) {
      setState(() => _isLoading = true);
      final text = await aiService.transcribeAudioOnly(wavBytes);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (text != null && text.trim().isNotEmpty) {
        setState(() {
          _controller.text = text.trim();
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Không nghe rõ giọng nói tiếng Việt. Bạn hãy nói to và rõ hơn gần micro nhé!',
            ),
            backgroundColor: AppTheme.accentOrange,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    // Mode 2: Transcribe + process voice command immediately
    final userMsgId = _uuid.v4();
    _animatedMessageIds.add(userMsgId);

    setState(() {
      _messages.add(ChatMessage(
        id: userMsgId,
        content: '🎙️ Đang nhận diện giọng nói tiếng Việt...',
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });
    _scrollToBottom();

    final deviceContext = ledProvider.buildStateContextSummary();
    final result = await aiService.processAudioCommand(
      wavBytes,
      deviceContext: deviceContext,
    );

    if (!mounted) return;

    final rawTranscript = (result?['transcript'] as String?)?.trim() ?? '';
    final replyText = (result?['response'] as String?)?.trim() ?? '';
    final rawCommands = result?['commands'] as List<dynamic>?;
    final hasValidReply =
        rawTranscript.isNotEmpty ||
        replyText.isNotEmpty ||
        (rawCommands != null && rawCommands.isNotEmpty);

    if (result == null || !hasValidReply) {
      setState(() {
        _messages.removeWhere((m) => m.id == userMsgId);
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Không nghe rõ giọng nói tiếng Việt. Bạn hãy nói to và rõ hơn gần micro nhé!',
          ),
          backgroundColor: AppTheme.accentOrange,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final transcript = rawTranscript.isNotEmpty
        ? rawTranscript
        : '🎙️ [Lệnh giọng nói tiếng Việt]';
    final finalReply =
        replyText.isNotEmpty ? replyText : 'Đã thực hiện lệnh giọng nói của bạn.';
    final modelUsed =
        (result['modelUsed'] as String?) ?? aiService.lastUsedModel;
    final commands = rawCommands != null
        ? rawCommands.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : (result['command'] != null
            ? [Map<String, dynamic>.from(result['command'] as Map)]
            : <Map<String, dynamic>>[]);

    if (commands.isNotEmpty) {
      ledProvider.executeCommands(commands);
    }

    final aiMsgId = _uuid.v4();
    setState(() {
      final userIdx = _messages.indexWhere((m) => m.id == userMsgId);
      if (userIdx != -1) {
        _messages[userIdx] = ChatMessage(
          id: userMsgId,
          content: transcript,
          isUser: true,
          timestamp: _messages[userIdx].timestamp,
        );
      }
      _messages.add(ChatMessage(
        id: aiMsgId,
        content: finalReply,
        isUser: false,
        timestamp: DateTime.now(),
        command: commands.isNotEmpty ? commands.first : null,
        commands: commands,
        shouldAnimate: true,
        modelUsed: modelUsed,
      ));
      _isLoading = false;
    });

    _scrollToBottom();

    if (_voiceEnabled) {
      await _speakText(aiMsgId, finalReply);
    }
  }

  /// Normalizes 16-bit Little-Endian PCM audio:
  /// - Ensures even byte length (2-byte sample alignment)
  /// - Removes DC offset
  /// - Applies automatic digital gain (up to 8x) so quiet microphones are crystal clear for STT
  Uint8List _normalizePcm16(Uint8List rawBytes) {
    final alignedLength = rawBytes.length & ~1;
    if (alignedLength < 4) return rawBytes;

    final numSamples = alignedLength ~/ 2;
    final inData = ByteData.sublistView(rawBytes, 0, alignedLength);

    int sum = 0;
    for (int i = 0; i < alignedLength; i += 2) {
      sum += inData.getInt16(i, Endian.little);
    }
    final dcOffset = sum ~/ numSamples;

    int peak = 0;
    for (int i = 0; i < alignedLength; i += 2) {
      final centered = (inData.getInt16(i, Endian.little) - dcOffset).abs();
      if (centered > peak) peak = centered;
    }

    if (peak < 80) {
      return Uint8List.sublistView(rawBytes, 0, alignedLength);
    }

    // Target peak ~24000 out of 32767 (-2.7 dBFS), max boost 8.0x
    final gain = (24000.0 / peak).clamp(1.0, 8.0);
    final outBytes = Uint8List(alignedLength);
    final outData = ByteData.sublistView(outBytes);

    for (int i = 0; i < alignedLength; i += 2) {
      final centered = inData.getInt16(i, Endian.little) - dcOffset;
      final amplified = (centered * gain).round().clamp(-32767, 32767);
      outData.setInt16(i, amplified, Endian.little);
    }
    return outBytes;
  }

  /// Wraps raw 16-bit Mono PCM bytes in a standard 44-byte RIFF WAV header
  Uint8List _buildWavBytes(
    Uint8List pcmBytes, {
    int sampleRate = 16000,
    int numChannels = 1,
    int bitsPerSample = 16,
  }) {
    final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final blockAlign = numChannels * (bitsPerSample ~/ 8);
    final dataLength = pcmBytes.length;
    final totalLength = 44 + dataLength;

    final header = ByteData(44);
    // "RIFF"
    header.setUint8(0, 0x52);
    header.setUint8(1, 0x49);
    header.setUint8(2, 0x46);
    header.setUint8(3, 0x46);
    header.setUint32(4, 36 + dataLength, Endian.little);
    // "WAVE"
    header.setUint8(8, 0x57);
    header.setUint8(9, 0x41);
    header.setUint8(10, 0x56);
    header.setUint8(11, 0x45);
    // "fmt "
    header.setUint8(12, 0x66);
    header.setUint8(13, 0x6D);
    header.setUint8(14, 0x74);
    header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little); // PCM chunk size
    header.setUint16(20, 1, Endian.little); // AudioFormat = 1 (PCM)
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    // "data"
    header.setUint8(36, 0x64);
    header.setUint8(37, 0x61);
    header.setUint8(38, 0x74);
    header.setUint8(39, 0x61);
    header.setUint32(40, dataLength, Endian.little);

    final wav = Uint8List(totalLength);
    wav.setRange(0, 44, header.buffer.asUint8List());
    wav.setRange(44, totalLength, pcmBytes);
    return wav;
  }

  Future<void> _startDeviceListening({bool fallbackDone = false}) async {
    try {
      if (!_speechAvailable) {
        _speechAvailable = await _speech.initialize(
          options: [
            SpeechToText.androidIntentLookup,
            SpeechToText.androidNoBluetooth,
          ],
          onStatus: (status) {
            if ((status == 'done' || status == 'notListening') && mounted) {
              if (!_isRecordingDirectAudio) {
                setState(() => _isListening = false);
              }
            }
          },
          onError: (error) {
            debugPrint('Speech recognition error: $error');
            if (mounted && !_isRecordingDirectAudio) {
              setState(() => _isListening = false);
            }
          },
        );
      }

      if (!_speechAvailable) {
        if (!fallbackDone) {
          // Fallback to direct hardware microphone recorder if SpeechRecognizer is unavailable
          await _startDirectAudioRecording(fallbackDone: true);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Vui lòng nhập Gemini API Key trong mục Cài đặt hoặc bật Google Voice Typing trên máy để dùng giọng nói.',
              ),
              backgroundColor: AppTheme.accentOrange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return;
      }

      setState(() {
        _isListening = true;
        _isUsingWyoming = false;
        _partialSpeech = '';
      });

      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: 'vi_VN',
          listenFor: const Duration(seconds: 15),
          pauseFor: const Duration(seconds: 2),
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
        ),
        onResult: (SpeechRecognitionResult result) {
          if (!mounted) return;
          setState(() {
            _partialSpeech = result.recognizedWords;
            _controller.text = result.recognizedWords;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
          });

          if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
            setState(() => _isListening = false);
            _sendMessage();
          }
        },
      );
    } catch (e) {
      debugPrint('Error starting speech recognition, falling back to audio recorder: $e');
      if (!fallbackDone) {
        await _startDirectAudioRecording(fallbackDone: true);
      }
    }
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _controller.text).trim();
    if (text.isEmpty || _isLoading) return;

    final aiService = context.read<AiService>();
    final ledProvider = context.read<LedProvider>();

    if (_isListening) {
      if (_isRecordingDirectAudio) {
        _isRecordingDirectAudio = false;
        await _directRecordSub?.cancel();
        _directRecordSub = null;
        await _audioRecorder.stop();
      } else if (_isUsingWyoming) {
        await _wyomingStt.cancelListening();
      } else {
        await _speech.stop();
      }
      setState(() => _isListening = false);
    }
    if (_isSpeaking) {
      await _stopSpeaking();
    }

    _controller.clear();
    _partialSpeech = '';

    final userMsgId = _uuid.v4();
    _animatedMessageIds.add(userMsgId);

    setState(() {
      _messages.add(ChatMessage(
        id: userMsgId,
        content: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _scrollToBottom();

    final deviceContext = ledProvider.buildStateContextSummary();

    final result = await aiService.processCommand(
      text,
      deviceContext: deviceContext,
    );

    if (!mounted) return;

    final replyText = (result['response'] as String?) ?? 'Đã xử lý lệnh.';
    final modelUsed = (result['modelUsed'] as String?) ?? aiService.lastUsedModel;
    final rawCommands = result['commands'] as List<dynamic>?;
    final commands = rawCommands != null
        ? rawCommands.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : (result['command'] != null
            ? [Map<String, dynamic>.from(result['command'] as Map)]
            : <Map<String, dynamic>>[]);

    // 1. Execute MQTT LED commands immediately so hardware responds right away
    if (commands.isNotEmpty) {
      ledProvider.executeCommands(commands);
    }

    // 2. Add AI message with typewriter animation enabled
    final aiMsgId = _uuid.v4();
    setState(() {
      _messages.add(ChatMessage(
        id: aiMsgId,
        content: replyText,
        isUser: false,
        timestamp: DateTime.now(),
        command: commands.isNotEmpty ? commands.first : null,
        commands: commands,
        shouldAnimate: true,
        modelUsed: modelUsed,
      ));
      _isLoading = false;
    });

    _scrollToBottom();

    // 3. Speak AI response simultaneously while text streams out
    if (_voiceEnabled) {
      await _speakText(aiMsgId, replyText);
    }
  }

  void _resetChat() {
    _stopSpeaking();
    final aiService = context.read<AiService>();
    aiService.resetConversation();
    final welcomeId = _uuid.v4();
    _animatedMessageIds
      ..clear()
      ..add(welcomeId);
    setState(() {
      _messages
        ..clear()
        ..add(ChatMessage(
          id: welcomeId,
          content:
              'Đã làm mới hội thoại với Smart LED Agent! Bạn muốn hỏi thông tin gì về đèn hay muốn điều chỉnh ánh sáng thế nào?',
          isUser: false,
          timestamp: DateTime.now(),
          modelUsed: aiService.currentModelId,
        ));
    });
  }

  void _showModelSelectorSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Consumer<AiService>(
          builder: (context, ai, _) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.65,
              maxChildSize: 0.88,
              minChildSize: 0.45,
              builder: (_, scrollCtrl) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.accentCyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.accentCyan.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Icon(
                              Icons.autorenew_rounded,
                              color: AppTheme.accentCyan,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Gemini AI Models',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  'Tự động xoay vòng khi hết quota',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              final next = ai.rotateToNextModel();
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('Đã xoay sang model: $next'),
                                  backgroundColor: AppTheme.accentBlue,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.skip_next_rounded, size: 18),
                            label: const Text('Xoay ngay'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.accentCyan,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Auto-rotate switch card
                      LiquidGlassCard(
                        borderRadius: 16,
                        tintColor: AppTheme.accentGreen,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Tự động đổi model khi hết quota',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Khi 1 model gặp 429 hoặc bận, tự động chuyển tiếp.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: ai.autoRotate,
                              activeThumbColor: AppTheme.accentGreen,
                              onChanged: (v) =>
                                  ai.setModelPreference(autoRotate: v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollCtrl,
                          itemCount: AiService.modelPool.length,
                          itemBuilder: (_, idx) {
                            final m = AiService.modelPool[idx];
                            final isCurrent = ai.currentModelId == m.id;
                            final onCooldown = ai.isModelOnCooldown(m.id);
                            final statusNote = ai.getModelStatusNote(m.id);

                            return GestureDetector(
                              onTap: () {
                                ai.setModelPreference(modelIndex: idx);
                                Navigator.pop(ctx);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? AppTheme.accentCyan.withValues(alpha: 0.12)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isCurrent
                                        ? AppTheme.accentCyan
                                        : (onCooldown
                                            ? AppTheme.accentOrange.withValues(alpha: 0.5)
                                            : const Color(0xFFCBD5E1)),
                                    width: isCurrent ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isCurrent
                                          ? Icons.radio_button_checked_rounded
                                          : onCooldown
                                              ? Icons.timer_outlined
                                              : Icons.radio_button_off_rounded,
                                      color: isCurrent
                                          ? AppTheme.accentCyan
                                          : onCooldown
                                              ? AppTheme.accentOrange
                                              : AppTheme.textSecondary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  m.name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13,
                                                    color: isCurrent
                                                        ? AppTheme.accentCyan
                                                        : AppTheme.textPrimary,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  '(${m.id})',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppTheme.textSecondary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            statusNote ?? m.description,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: onCooldown
                                                  ? AppTheme.accentOrange
                                                  : AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isCurrent)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.accentGreen
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: AppTheme.accentGreen
                                                .withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: const Text(
                                          'Đang dùng',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.accentGreen,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _cancelListening() async {
    try {
      if (_isRecordingDirectAudio) {
        _isRecordingDirectAudio = false;
        await _directRecordSub?.cancel();
        _directRecordSub = null;
        await _audioRecorder.stop();
        _pcmBuffer.clear();
      } else if (_isUsingWyoming) {
        await _wyomingStt.cancelListening();
      } else {
        await _speech.stop();
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isListening = false;
        _partialSpeech = '';
      });
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final aiService = context.watch<AiService>();
    final ledProvider = context.watch<LedProvider>();
    final ledState = ledProvider.ledState;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = bottomInset > 0;
    // When SafeArea(bottom: true) is used with extendBody: true, SafeArea already pads by the bottomNavigationBar height (78px)!
    final bottomPad = isKeyboardOpen ? 8.0 : 8.0;

    return SafeArea(
      child: Column(
        children: [
          // Unified Compact Header + Quick LED Status
          _buildUnifiedHeader(aiService, ledProvider, ledState),

          // Expandable Quick LED Control Drawer (only visible when toggled and keyboard closed)
          if (_showQuickControls && !isKeyboardOpen)
            _buildExpandableLedDrawer(ledProvider, ledState),

          // Chat Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _buildLoadingBubble(aiService.currentModelId);
                }
                final msg = _messages[index];
                final shouldStream =
                    !msg.isUser && !_animatedMessageIds.contains(msg.id);
                final isThisSpeaking =
                    _isSpeaking && _speakingMessageId == msg.id;

                return _ChatBubble(
                  key: ValueKey(msg.id),
                  message: msg,
                  shouldStreamText: shouldStream,
                  isSpeaking: isThisSpeaking,
                  onStreamProgress: _scrollToBottom,
                  onStreamComplete: () {
                    _animatedMessageIds.add(msg.id);
                  },
                  onToggleSpeak: () {
                    if (isThisSpeaking) {
                      _stopSpeaking();
                    } else {
                      _speakText(msg.id, msg.content);
                    }
                  },
                );
              },
            ),
          ),

          // Active Voice Recording Bar OR Quick Suggestion Chips
          if (_isListening)
            _buildVoiceRecordingBar()
          else if (!isKeyboardOpen)
            _buildQuickChipsRow(),

          // Sleek Floating Input Capsule
          Padding(
            padding: EdgeInsets.fromLTRB(14, 6, 14, bottomPad),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _isListening
                      ? AppTheme.accentRed
                      : const Color(0xFFCBD5E1),
                  width: 1.3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.09),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Voice Microphone Button
                  GestureDetector(
                    onTap: _isLoading ? null : _toggleListening,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: _isListening
                            ? AppTheme.warmGradient
                            : const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFF0FDFA),
                                  Color(0xFFE0F2FE),
                                ],
                              ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isListening
                              ? AppTheme.accentRed
                              : AppTheme.accentCyan.withValues(alpha: 0.55),
                          width: 1.2,
                        ),
                        boxShadow: _isListening
                            ? [
                                BoxShadow(
                                  color:
                                      AppTheme.accentRed.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                        color:
                            _isListening ? Colors.white : AppTheme.accentCyan,
                        size: 21,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Text Input Field
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textAlignVertical: TextAlignVertical.center,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                      decoration: InputDecoration(
                        hintText: _isListening
                            ? 'Đang thu giọng nói tiếng Việt...'
                            : 'Nhắn tin hoặc chạm 🎙️ để nói...',
                        hintStyle: const TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 13.5,
                          height: 1.2,
                        ),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 11,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Send Button
                  GestureDetector(
                    onTap: _isLoading ? null : () => _sendMessage(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentCyan.withValues(alpha: 0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isLoading
                            ? Icons.hourglass_top_rounded
                            : Icons.send_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedHeader(
    AiService aiService,
    LedProvider ledProvider,
    LedState ledState,
  ) {
    final isOn = ledState.isOn;
    final ledColor = ledState.color;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: LiquidGlassCard(
        borderRadius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Animated AI / Voice Avatar
            AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                final active = _isSpeaking || _isListening;
                return GestureDetector(
                  onTap: _showModelSelectorSheet,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: _isListening
                          ? AppTheme.warmGradient
                          : AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: (_isListening
                                        ? AppTheme.accentRed
                                        : AppTheme.accentCyan)
                                    .withValues(
                                  alpha: 0.3 + _waveController.value * 0.35,
                                ),
                                blurRadius: 12 + _waveController.value * 6,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      _isListening
                          ? Icons.mic_rounded
                          : _isSpeaking
                              ? Icons.graphic_eq_rounded
                              : Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 10),

            // Title & Model Selector Pill
            Expanded(
              child: GestureDetector(
                onTap: _showModelSelectorSheet,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trợ Lý AI Đèn LED',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isListening
                                ? AppTheme.accentRed
                                : _isSpeaking
                                    ? AppTheme.accentCyan
                                    : AppTheme.accentGreen,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            _isListening
                                ? 'Đang nghe tiếng Việt...'
                                : _isSpeaking
                                    ? 'Đang phát giọng nói...'
                                    : aiService.currentModelId,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _isListening
                                  ? AppTheme.accentRed
                                  : AppTheme.accentCyan,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 14,
                          color: AppTheme.accentCyan,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Compact Live LED Status Pill (Tap to open quick controls, Long-press to toggle power)
            GestureDetector(
              onTap: () =>
                  setState(() => _showQuickControls = !_showQuickControls),
              onLongPress: () => ledProvider.togglePower(!isOn),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isOn
                      ? AppTheme.accentGreen.withValues(alpha: 0.1)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isOn
                        ? AppTheme.accentGreen.withValues(alpha: 0.55)
                        : const Color(0xFFCBD5E1),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isOn ? ledColor : const Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF475569),
                          width: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isOn ? '${ledState.brightness}%' : 'TẮT',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isOn
                            ? AppTheme.accentGreen
                            : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      _showQuickControls
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Voice Toggle Button
            _GlassIconButton(
              tooltip: _voiceEnabled
                  ? 'Đang bật đọc tiếng Việt'
                  : 'Đang tắt giọng đọc AI',
              onTap: _toggleVoiceEnabled,
              icon: _voiceEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              iconColor:
                  _voiceEnabled ? AppTheme.accentCyan : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),

            // Reset Chat Button
            _GlassIconButton(
              tooltip: 'Làm mới hội thoại',
              onTap: _resetChat,
              icon: Icons.refresh_rounded,
              iconColor: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableLedDrawer(
    LedProvider ledProvider,
    LedState ledState,
  ) {
    final isOn = ledState.isOn;
    final color = ledState.color;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      child: LiquidGlassCard(
        borderRadius: 16,
        tintColor: isOn ? color : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => ledProvider.togglePower(!isOn),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isOn
                          ? AppTheme.accentGreen.withValues(alpha: 0.14)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isOn
                            ? AppTheme.accentGreen
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.power_settings_new_rounded,
                          size: 14,
                          color: isOn
                              ? AppTheme.accentGreen
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isOn ? 'Đang BẬT' : 'Đang TẮT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isOn
                                ? AppTheme.accentGreen
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.brightness_6_rounded,
                  size: 15,
                  color: AppTheme.accentOrange,
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12,
                      ),
                      activeTrackColor: AppTheme.accentCyan,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: ledState.brightness.toDouble(),
                      min: 0,
                      max: 100,
                      onChanged: (v) => ledProvider.setBrightness(v.toInt()),
                    ),
                  ),
                ),
                Text(
                  '${ledState.brightness}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentCyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 26,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final preset in const [
                    Color(0xFFFFFFFF),
                    Color(0xFFFFB464),
                    Color(0xFFFF007A),
                    Color(0xFF00F2FE),
                    Color(0xFF10B981),
                    Color(0xFFA855F7),
                    Color(0xFFF59E0B),
                    Color(0xFF0066FF),
                  ])
                    GestureDetector(
                      onTap: () => ledProvider.setColor(preset),
                      child: Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: preset,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF64748B),
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceRecordingBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      child: LiquidGlassCard(
        borderRadius: 18,
        tintColor: AppTheme.accentRed,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Animated Equalizer Wave Bars reactive to mic level
            AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                final v = _waveController.value;
                final amp = (0.35 + 0.65 * _currentMicLevel).clamp(0.35, 1.0);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final factor in [0.45, 0.9, 0.6, 1.0, 0.5])
                      Container(
                        width: 3,
                        height: 6 + (15 * factor * amp * (0.4 + 0.6 * v)),
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: AppTheme.accentRed,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _partialSpeech.isEmpty
                    ? '🎙️ Đang nghe tiếng Việt... Hãy nói câu lệnh đèn LED'
                    : _partialSpeech,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: _cancelListening,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Hủy',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ),
            if (_isRecordingDirectAudio) ...[
              const SizedBox(width: 4),
              OutlinedButton(
                onPressed: () => _stopAndSendDirectAudioRecording(
                  insertIntoTextFieldOnly: true,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentCyan,
                  side: BorderSide(
                    color: AppTheme.accentCyan.withValues(alpha: 0.55),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                child: const Text(
                  'Chuyển chữ',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
            const SizedBox(width: 4),
            ElevatedButton(
              onPressed: _toggleListening,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Gửi ngay',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChipsRow() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          _QuickChip(
            label: '💡 Bật đèn sáng',
            onTap: () => _sendMessage('Bật đèn sáng lên giúp mình'),
          ),
          _QuickChip(
            label: '📚 Đèn học bài',
            onTap: () => _sendMessage(
              'Chỉnh đèn sáng trắng mát tập trung để mình học bài',
            ),
          ),
          _QuickChip(
            label: '🌙 Đèn ngủ ấm',
            onTap: () => _sendMessage('Bật đèn ngủ màu vàng ấm độ sáng 20%'),
          ),
          _QuickChip(
            label: '🌈 Cầu vồng',
            onTap: () => _sendMessage('Cho đèn chạy hiệu ứng cầu vồng'),
          ),
          _QuickChip(
            label: '🔆 Tăng sáng',
            onTap: () =>
                _sendMessage('Hơi tối, tăng độ sáng đèn lên thêm chút đi'),
          ),
          _QuickChip(
            label: '🔅 Giảm sáng',
            onTap: () =>
                _sendMessage('Hơi chói mắt, giảm độ sáng đèn xuống giúp mình'),
          ),
          _QuickChip(
            label: '❓ Trạng thái đèn',
            onTap: () => _sendMessage(
              'Cho mình hỏi đèn hiện tại đang màu gì, độ sáng bao nhiêu và cảm biến báo thế nào?',
            ),
          ),
          _QuickChip(
            label: '⏹️ Tắt đèn',
            onTap: () => _sendMessage('Tắt đèn đi giúp mình'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingBubble(String currentModel) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 10, right: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(
            color: AppTheme.accentCyan.withValues(alpha: 0.45),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.accentCyan,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'AI ($currentModel) đang phản hồi...',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatefulWidget {
  final ChatMessage message;
  final bool shouldStreamText;
  final bool isSpeaking;
  final VoidCallback onStreamProgress;
  final VoidCallback onStreamComplete;
  final VoidCallback onToggleSpeak;

  const _ChatBubble({
    super.key,
    required this.message,
    required this.shouldStreamText,
    required this.isSpeaking,
    required this.onStreamProgress,
    required this.onStreamComplete,
    required this.onToggleSpeak,
  });

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble> {
  String _displayedText = '';
  bool _isStreaming = false;
  bool _showRawSignal = false;
  Timer? _typewriterTimer;
  int _charIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.shouldStreamText && !widget.message.isUser) {
      _startTypewriter();
    } else {
      _displayedText = widget.message.content;
    }
  }

  @override
  void didUpdateWidget(covariant _ChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.content != widget.message.content) {
      if (widget.shouldStreamText && !widget.message.isUser) {
        _startTypewriter();
      } else {
        _typewriterTimer?.cancel();
        _isStreaming = false;
        _displayedText = widget.message.content;
      }
    }
  }

  void _startTypewriter() {
    final fullText = widget.message.content;
    if (fullText.isEmpty) {
      _displayedText = '';
      widget.onStreamComplete();
      return;
    }

    _isStreaming = true;
    _charIndex = 0;
    _displayedText = '';

    _typewriterTimer =
        Timer.periodic(const Duration(milliseconds: 35), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_charIndex < fullText.length) {
        final step = fullText.length > 120 ? 2 : 1;
        _charIndex = (_charIndex + step).clamp(0, fullText.length);
        setState(() {
          _displayedText = fullText.substring(0, _charIndex);
        });
        if (_charIndex % 12 == 0 || _charIndex == fullText.length) {
          widget.onStreamProgress();
        }
      } else {
        timer.cancel();
        setState(() {
          _isStreaming = false;
          _displayedText = fullText;
        });
        widget.onStreamComplete();
      }
    });
  }

  void _finishImmediately() {
    if (!_isStreaming) return;
    _typewriterTimer?.cancel();
    setState(() {
      _isStreaming = false;
      _displayedText = widget.message.content;
    });
    widget.onStreamComplete();
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUser;
    final commands = widget.message.allCommands;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: _isStreaming ? _finishImmediately : null,
        child: Container(
          margin: EdgeInsets.only(
            top: 10,
            left: isUser ? 44 : 0,
            right: isUser ? 0 : 28,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: isUser
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1E3A8A),
                      Color(0xFF005A70),
                    ],
                  )
                : null,
            color: isUser ? null : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 5),
              bottomRight: Radius.circular(isUser ? 5 : 18),
            ),
            border: Border.all(
              color: isUser
                  ? const Color(0xFF1E3A8A)
                  : (widget.isSpeaking
                      ? AppTheme.accentCyan
                      : const Color(0xFFCBD5E1)),
              width: widget.isSpeaking ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Role & Timestamp Header
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUser
                        ? Icons.person_rounded
                        : Icons.smart_toy_outlined,
                    size: 13,
                    color: isUser
                        ? Colors.white
                        : AppTheme.accentCyan,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      isUser ? 'Bạn' : 'Trợ lý AI Đèn LED',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isUser
                            ? Colors.white
                            : AppTheme.accentCyan,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatTime(widget.message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isUser
                          ? Colors.white
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Message Text Content
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: isUser ? Colors.white : AppTheme.textPrimary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                  children: [
                    TextSpan(text: _displayedText),
                    if (_isStreaming)
                      const TextSpan(
                        text: ' ▍',
                        style: TextStyle(
                          color: AppTheme.accentCyan,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),

              // Executed MQTT Command Badges
              if (commands.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: commands.map(_buildCommandBadge).toList(),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () =>
                      setState(() => _showRawSignal = !_showRawSignal),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showRawSignal
                            ? Icons.code_off_rounded
                            : Icons.code_rounded,
                        size: 13,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _showRawSignal
                            ? 'Ẩn tín hiệu JSON'
                            : 'Xem tín hiệu MQTT (${commands.length} lệnh)',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showRawSignal) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF334155),
                      ),
                    ),
                    child: Text(
                      const JsonEncoder.withIndent('  ').convert(commands),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Color(0xFF7DD3FC),
                      ),
                    ),
                  ),
                ],
              ],

              // AI Message Action Bar: Speak button & Model badge
              if (!isUser) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    InkWell(
                      onTap: widget.onToggleSpeak,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: widget.isSpeaking
                              ? AppTheme.accentCyan.withValues(alpha: 0.14)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: widget.isSpeaking
                                ? AppTheme.accentCyan
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.isSpeaking
                                  ? Icons.stop_circle_outlined
                                  : Icons.volume_up_rounded,
                              size: 13,
                              color: widget.isSpeaking
                                  ? AppTheme.accentCyan
                                  : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              widget.isSpeaking
                                  ? 'Đang đọc (Dừng)'
                                  : 'Đọc tiếng Việt',
                              style: TextStyle(
                                fontSize: 11,
                                color: widget.isSpeaking
                                    ? AppTheme.accentCyan
                                    : AppTheme.textSecondary,
                                fontWeight: widget.isSpeaking
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.message.modelUsed != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          widget.message.modelUsed!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommandBadge(Map<String, dynamic> cmd) {
    final action = cmd['action'] as String? ?? '';
    IconData icon = Icons.check_circle_outline;
    String label = 'Đã thực thi';
    Color badgeColor = AppTheme.accentGreen;
    Widget? leadingDot;

    switch (action) {
      case 'power':
        final isOn = cmd['state'] == 'on';
        icon = isOn ? Icons.power_settings_new_rounded : Icons.power_off_rounded;
        label = isOn ? 'Nguồn: BẬT' : 'Nguồn: TẮT';
        badgeColor = isOn ? AppTheme.accentGreen : AppTheme.accentRed;
        break;
      case 'color':
        final r = (cmd['r'] as num?)?.toInt() ?? 255;
        final g = (cmd['g'] as num?)?.toInt() ?? 255;
        final b = (cmd['b'] as num?)?.toInt() ?? 255;
        final c = Color.fromARGB(255, r, g, b);
        leadingDot = Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF475569), width: 1.2),
          ),
        );
        label = 'RGB($r, $g, $b)';
        badgeColor = AppTheme.accentCyan;
        break;
      case 'brightness':
        final val = (cmd['value'] as num?)?.toInt() ?? 100;
        icon = Icons.brightness_6_rounded;
        label = 'Độ sáng: $val%';
        badgeColor = AppTheme.accentOrange;
        break;
      case 'effect':
        final type = cmd['type'] as String? ?? 'none';
        final speed = (cmd['speed'] as num?)?.toInt() ?? 500;
        final eff = LedEffect.values.firstWhere(
          (e) => e.mqttValue == type,
          orElse: () => LedEffect.none,
        );
        icon = Icons.auto_awesome_rounded;
        label = '${eff.displayName} (${speed}ms)';
        badgeColor = AppTheme.accentPurple;
        break;
      case 'auto_mode':
        final enabled = cmd['enabled'] as bool? ?? false;
        icon = Icons.sensors_rounded;
        label = 'Tự động: ${enabled ? "BẬT" : "TẮT"}';
        badgeColor = AppTheme.accentCyan;
        break;
      case 'num_leds':
        final count = (cmd['count'] as num?)?.toInt() ?? 8;
        icon = Icons.linear_scale_rounded;
        label = '$count bóng LED';
        badgeColor = AppTheme.accentGreen;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingDot != null)
            leadingDot
          else
            Icon(icon, color: badgeColor, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: badgeColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFCBD5E1),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onTap;
  final IconData icon;
  final Color iconColor;

  const _GlassIconButton({
    required this.tooltip,
    required this.onTap,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFCBD5E1),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: iconColor, size: 17),
        ),
      ),
    );
  }
}
