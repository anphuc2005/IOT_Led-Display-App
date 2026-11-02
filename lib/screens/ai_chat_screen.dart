import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
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

  bool _isLoading = false;
  bool _voiceEnabled = true;
  bool _isSpeaking = false;
  String? _speakingMessageId;

  // VieNeu-TTS settings
  bool _vieneuEnabled = false;
  String _vieneuUrl = '';
  String _vieneuVoice = 'Minh Quân';
  String _vieneuApiKey = '';

  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isUsingWyoming = false;
  bool _wyomingConfigured = false;
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
          'Xin chào! Mình là Smart LED Agent — trợ lý AI chuyên trách hệ thống đèn LED thông minh (hỗ trợ tự động xoay vòng 9 model Gemini khi hết lượt).\n\n'
          'Bạn có thể hỏi thông tin về đèn hoặc yêu cầu điều khiển đèn:\n'
          '❓ "Đèn đang màu gì, độ sáng bao nhiêu?"\n'
          '❓ "Hệ thống đèn có những hiệu ứng nào?"\n'
          '💡 "Bật đèn trắng mát để học bài"\n'
          '🔆 "Hơi tối, tăng độ sáng lên chút đi"\n'
          '🌈 "Cho đèn chạy hiệu ứng cầu vồng nhanh"',
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
    final wyEnabled = await storage.loadWyomingEnabled();
    final wyHost = await storage.loadWyomingHost();
    final vieneuEnabled = await storage.loadVieNeuTtsEnabled();
    final vieneuUrl = await storage.loadVieNeuTtsUrl();
    final vieneuVoice = await storage.loadVieNeuTtsVoice();
    final vieneuApiKey = await storage.loadVieNeuTtsApiKey();

    if (mounted) {
      setState(() {
        _voiceEnabled = savedVoice;
        _wyomingConfigured = wyEnabled && wyHost.isNotEmpty;
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
      }

      await _tts.setLanguage('vi-VN');
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

      // Try VieNeu-TTS if enabled
      if (_vieneuEnabled && _vieneuUrl.isNotEmpty) {
        final vieneu = context.read<VieNeuTtsService>();
        final ok = await vieneu.speak(
          text: normalized,
          baseUrl: _vieneuUrl,
          voice: _vieneuVoice,
          apiKey: _vieneuApiKey,
        );
        if (ok) return;
        debugPrint('VieNeu-TTS failed; falling back to local flutter_tts');
      }

      // Local device TTS fallback
      await _tts.speak(normalized);
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
      if (_isUsingWyoming) {
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
        _wyomingConfigured = true;
        _partialSpeech = 'Đang nghe bằng Wyoming Vietnamese STT ($wyHost:$wyPort)...';
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Wyoming lỗi: $err. Đang chuyển sang nhận diện trên máy.'),
              backgroundColor: AppTheme.accentOrange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          await _wyomingStt.cancelListening();
          _startDeviceListening();
        },
      );
      return;
    }

    _isUsingWyoming = false;
    await _startDeviceListening();
  }

  Future<void> _startDeviceListening() async {
    try {
      if (!_speechAvailable) {
        _speechAvailable = await _speech.initialize(
          onStatus: (status) {
            if ((status == 'done' || status == 'notListening') && mounted) {
              setState(() => _isListening = false);
            }
          },
          onError: (error) {
            debugPrint('Speech recognition error: $error');
            if (mounted) {
              setState(() => _isListening = false);
            }
          },
        );
      }

      if (!_speechAvailable) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Thiết bị chưa cấp quyền Micro hoặc không hỗ trợ nhận diện giọng nói.',
            ),
            backgroundColor: AppTheme.accentOrange,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      setState(() {
        _isListening = true;
        _isUsingWyoming = false;
        _partialSpeech = '';
      });

      await _speech.listen(
        localeId: 'vi_VN',
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 2),
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
      debugPrint('Error starting speech recognition: $e');
      if (mounted) {
        setState(() => _isListening = false);
      }
    }
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _controller.text).trim();
    if (text.isEmpty || _isLoading) return;

    final aiService = context.read<AiService>();
    final ledProvider = context.read<LedProvider>();

    if (_isListening) {
      if (_isUsingWyoming) {
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
      backgroundColor: AppTheme.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppTheme.borderDark,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(
                            Icons.autorenew_rounded,
                            color: AppTheme.accentCyan,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Xoay vòng Model Gemini AI',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
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
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Auto-rotate switch card
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.cardDark,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.borderDark),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Tự động đổi sang model khác khi hết lượt',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Khi 1 model báo hết quota (429) hoặc bận (503), Agent tự xoay sang model kế tiếp.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: ai.autoRotate,
                              activeColor: AppTheme.accentGreen,
                              onChanged: (v) =>
                                  ai.setModelPreference(autoRotate: v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
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
                                      ? AppTheme.accentBlue.withOpacity(0.12)
                                      : AppTheme.cardDark,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCurrent
                                        ? AppTheme.accentBlue
                                        : onCooldown
                                            ? AppTheme.accentOrange
                                                .withOpacity(0.5)
                                            : AppTheme.borderDark,
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
                                          ? AppTheme.accentBlue
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
                                              Text(
                                                m.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                  color: isCurrent
                                                      ? AppTheme.accentBlue
                                                      : AppTheme.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '(${m.id})',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.textSecondary,
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
                                              .withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(8),
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

    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, child) {
                    final active = _isSpeaking || _isListening;
                    return Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: _isListening
                            ? AppTheme.warmGradient
                            : AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: (_isListening
                                          ? AppTheme.accentRed
                                          : AppTheme.accentBlue)
                                      .withOpacity(
                                          0.25 + _waveController.value * 0.35),
                                  blurRadius: 12 + _waveController.value * 8,
                                  spreadRadius: 1 + _waveController.value * 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        _isListening
                            ? Icons.mic_rounded
                            : _isSpeaking
                                ? Icons.graphic_eq_rounded
                                : Icons.smart_toy_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _showModelSelectorSheet,
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Flexible(
                              child: Text(
                                'Smart LED Agent',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accentBlue.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppTheme.accentBlue.withOpacity(0.35),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.sync_rounded,
                                    size: 11,
                                    color: AppTheme.accentBlue,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    aiService.currentModelId,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.accentBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isListening
                                    ? AppTheme.accentRed
                                    : _isSpeaking
                                        ? AppTheme.accentCyan
                                        : aiService.hasApiKey
                                            ? AppTheme.accentGreen
                                            : AppTheme.accentOrange,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _isListening
                                    ? 'Đang nghe câu hỏi về đèn...'
                                    : _isSpeaking
                                        ? 'Agent đang nói & đồng bộ đèn...'
                                        : _isLoading
                                            ? 'Đang xử lý (${aiService.currentModelId})...'
                                            : 'Chuyên gia Đèn LED • Tự xoay 9 model',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _isListening
                                      ? AppTheme.accentRed
                                      : _isSpeaking
                                          ? AppTheme.accentCyan
                                          : aiService.hasApiKey
                                              ? AppTheme.accentGreen
                                              : AppTheme.accentOrange,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Model rotation selector button
                IconButton(
                  tooltip: 'Chọn / Xoay vòng Model Gemini',
                  onPressed: _showModelSelectorSheet,
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.cardDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppTheme.borderDark),
                    ),
                  ),
                  icon: const Icon(
                    Icons.autorenew_rounded,
                    color: AppTheme.accentCyan,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 4),
                // Toggle AI Voice button
                IconButton(
                  tooltip: _voiceEnabled
                      ? (_vieneuEnabled
                          ? 'Đang bật VieNeu-TTS 48kHz ($_vieneuVoice)'
                          : 'Đang bật giọng nói AI (Nhấn để tắt)')
                      : 'Đang tắt giọng nói AI (Nhấn để bật)',
                  onPressed: _toggleVoiceEnabled,
                  style: IconButton.styleFrom(
                    backgroundColor: _voiceEnabled
                        ? (_vieneuEnabled
                            ? AppTheme.accentPurple.withOpacity(0.18)
                            : AppTheme.accentBlue.withOpacity(0.15))
                        : AppTheme.cardDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: _voiceEnabled
                            ? (_vieneuEnabled
                                ? AppTheme.accentPurple.withOpacity(0.5)
                                : AppTheme.accentBlue.withOpacity(0.4))
                            : AppTheme.borderDark,
                      ),
                    ),
                  ),
                  icon: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        _voiceEnabled
                            ? (_vieneuEnabled
                                ? Icons.record_voice_over_rounded
                                : Icons.volume_up_rounded)
                            : Icons.volume_off_rounded,
                        color: _voiceEnabled
                            ? (_vieneuEnabled
                                ? AppTheme.accentPurple
                                : AppTheme.accentBlue)
                            : AppTheme.textSecondary,
                        size: 20,
                      ),
                      if (_voiceEnabled && _vieneuEnabled)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppTheme.accentPurple,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Reset conversation button
                IconButton(
                  tooltip: 'Làm mới hội thoại',
                  onPressed: _resetChat,
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.cardDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppTheme.borderDark),
                    ),
                  ),
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          // Live LED Status & Direct Control Strip inside AI Chat
          _buildLiveLedBar(ledProvider, ledState),
          const Divider(color: AppTheme.borderDark, height: 1),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
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

          // Active listening banner
          if (_isListening)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: (_isUsingWyoming
                        ? AppTheme.accentCyan
                        : AppTheme.accentRed)
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (_isUsingWyoming
                          ? AppTheme.accentCyan
                          : AppTheme.accentRed)
                      .withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isUsingWyoming
                        ? Icons.mic_external_on_rounded
                        : Icons.graphic_eq_rounded,
                    color: _isUsingWyoming
                        ? AppTheme.accentCyan
                        : AppTheme.accentRed,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _partialSpeech.isEmpty
                          ? (_isUsingWyoming
                              ? 'Đang nghe bằng Wyoming Vietnamese STT... (Bấm nút Mic để dừng)'
                              : 'Hãy đặt câu hỏi về đèn hoặc nói lệnh điều khiển...')
                          : _partialSpeech,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _toggleListening,
                    style: TextButton.styleFrom(
                      foregroundColor: _isUsingWyoming
                          ? AppTheme.accentCyan
                          : AppTheme.accentRed,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 28),
                    ),
                    child: Text(_isUsingWyoming ? 'Xong' : 'Gửi ngay'),
                  ),
                ],
              ),
            ),

          // Quick LED Q&A and Control chips
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _QuickChip(
                  label: '❓ Đèn đang trạng thái gì?',
                  onTap: () => _sendMessage(
                    'Cho mình hỏi đèn hiện tại đang màu gì, độ sáng bao nhiêu và cảm biến báo thế nào?',
                  ),
                ),
                _QuickChip(
                  label: '❓ Đèn có mấy hiệu ứng?',
                  onTap: () => _sendMessage(
                    'Hệ thống đèn LED này có những hiệu ứng nào và chế độ tự động hoạt động ra sao?',
                  ),
                ),
                _QuickChip(
                  label: '📚 Đèn học bài',
                  onTap: () => _sendMessage(
                    'Chỉnh đèn sáng trắng mát tập trung để mình học bài',
                  ),
                ),
                _QuickChip(
                  label: '🔆 Tăng sáng thêm',
                  onTap: () =>
                      _sendMessage('Hơi tối, tăng độ sáng đèn lên thêm chút đi'),
                ),
                _QuickChip(
                  label: '🔅 Giảm sáng bớt',
                  onTap: () => _sendMessage(
                    'Hơi chói mắt, giảm độ sáng đèn xuống giúp mình',
                  ),
                ),
                _QuickChip(
                  label: '🌈 Hiệu ứng cầu vồng',
                  onTap: () => _sendMessage('Cho đèn chạy hiệu ứng cầu vồng'),
                ),
                _QuickChip(
                  label: '🌙 Đèn ngủ ấm 20%',
                  onTap: () => _sendMessage(
                    'Bật đèn ngủ màu vàng ấm độ sáng 20%',
                  ),
                ),
                _QuickChip(
                  label: '⏹️ Tắt đèn',
                  onTap: () => _sendMessage('Tắt đèn đi giúp mình'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Input Bar with Mic + Text + Send
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              border: Border(
                top: BorderSide(color: AppTheme.borderDark.withOpacity(0.5)),
              ),
            ),
            child: Row(
              children: [
                // Microphone button for Speech-to-Text
                GestureDetector(
                  onTap: _isLoading ? null : _toggleListening,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _isListening
                          ? AppTheme.accentRed
                          : AppTheme.cardDark,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isListening
                            ? AppTheme.accentRed
                            : AppTheme.borderDark,
                      ),
                      boxShadow: _isListening
                          ? [
                              BoxShadow(
                                color: AppTheme.accentRed.withOpacity(0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          _isListening
                              ? Icons.stop_rounded
                              : (_wyomingConfigured
                                  ? Icons.mic_external_on_rounded
                                  : Icons.mic_rounded),
                          color: _isListening
                              ? Colors.white
                              : (_wyomingConfigured
                                  ? AppTheme.accentCyan
                                  : AppTheme.textPrimary),
                          size: 22,
                        ),
                        if (_wyomingConfigured && !_isListening)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppTheme.accentCyan,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: _isListening
                          ? 'Đang nghe câu hỏi về đèn...'
                          : 'Hỏi về đèn hoặc yêu cầu điều chỉnh đèn...',
                      filled: true,
                      fillColor: AppTheme.cardDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(23),
                  ),
                  child: IconButton(
                    onPressed: _isLoading ? null : () => _sendMessage(),
                    icon: Icon(
                      _isLoading ? Icons.hourglass_top : Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveLedBar(LedProvider ledProvider, LedState ledState) {
    final isOn = ledState.isOn;
    final color = ledState.color;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOn ? color.withOpacity(0.45) : AppTheme.borderDark,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Live glowing bulb icon
              GestureDetector(
                onTap: () => ledProvider.togglePower(!isOn),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color:
                        isOn ? color.withOpacity(0.25) : AppTheme.surfaceDark,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isOn ? color : AppTheme.borderDark,
                      width: 1.5,
                    ),
                    boxShadow: isOn
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.45),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    isOn
                        ? Icons.lightbulb_rounded
                        : Icons.lightbulb_outline_rounded,
                    color: isOn ? color : AppTheme.textSecondary,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _showQuickControls = !_showQuickControls),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isOn ? 'Đèn đang BẬT' : 'Đèn đang TẮT',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: isOn
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (ledProvider.autoMode)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accentCyan.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'AUTO',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentCyan,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Độ sáng: ${ledState.brightness}% • ${ledState.effect.icon} ${ledState.effect.displayName}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Expand/Collapse manual quick controls
              IconButton(
                tooltip: 'Mở bảng chỉnh nhanh',
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    setState(() => _showQuickControls = !_showQuickControls),
                icon: Icon(
                  _showQuickControls
                      ? Icons.expand_less_rounded
                      : Icons.tune_rounded,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
              ),
              // Quick Power Switch
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: isOn,
                  onChanged: (v) => ledProvider.togglePower(v),
                  activeColor: AppTheme.accentBlue,
                ),
              ),
            ],
          ),

          // Expandable direct controls right inside AI Chat
          if (_showQuickControls) ...[
            const Divider(color: AppTheme.borderDark, height: 14),
            Row(
              children: [
                const Icon(
                  Icons.brightness_6_rounded,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                    ),
                    child: Slider(
                      value: ledState.brightness.toDouble(),
                      min: 0,
                      max: 100,
                      activeColor: AppTheme.accentBlue,
                      onChanged: (v) => ledProvider.setBrightness(v.toInt()),
                    ),
                  ),
                ),
                SizedBox(
                  width: 38,
                  child: Text(
                    '${ledState.brightness}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accentBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Quick color dots
            SizedBox(
              height: 28,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final preset in const [
                    Color(0xFFFFFFFF),
                    Color(0xFFFFB464),
                    Color(0xFFFF0000),
                    Color(0xFF00FF00),
                    Color(0xFF0066FF),
                    Color(0xFFFFFF00),
                    Color(0xFF8A2BE2),
                    Color(0xFF00FFFF),
                    Color(0xFFFF69B4),
                  ])
                    GestureDetector(
                      onTap: () {
                        if (!ledState.isOn) ledProvider.togglePower(true);
                        ledProvider.setColor(preset);
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: preset,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white54,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingBubble(String currentModel) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 8, right: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.accentBlue.withOpacity(0.8),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Smart LED Agent ($currentModel) đang xử lý...',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
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

    // ~38ms per character matches Vietnamese TTS speaking cadence naturally
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 38), (timer) {
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
            left: isUser ? 52 : 0,
            right: isUser ? 0 : 36,
          ),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: isUser ? AppTheme.primaryGradient : null,
            color: isUser ? null : AppTheme.cardDark,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            border: isUser
                ? null
                : Border.all(
                    color: widget.isSpeaking
                        ? AppTheme.accentCyan.withOpacity(0.6)
                        : AppTheme.borderDark,
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Text content with streaming cursor when active
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

              // Executed MQTT command badges
              if (commands.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: commands.map(_buildCommandBadge).toList(),
                ),
                const SizedBox(height: 6),
                // Toggleable raw JSON signal view
                GestureDetector(
                  onTap: () => setState(() => _showRawSignal = !_showRawSignal),
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
                            : 'Xem tín hiệu điều khiển (${commands.length} lệnh)',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderDark),
                    ),
                    child: Text(
                      const JsonEncoder.withIndent('  ').convert(commands),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppTheme.accentCyan,
                      ),
                    ),
                  ),
                ],
              ],

              // Bottom row for AI message: Speak/Replay button & Model badge
              if (!isUser) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    InkWell(
                      onTap: widget.onToggleSpeak,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: widget.isSpeaking
                              ? AppTheme.accentCyan.withOpacity(0.15)
                              : AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.isSpeaking
                                ? AppTheme.accentCyan.withOpacity(0.4)
                                : AppTheme.borderDark,
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
                            const SizedBox(width: 4),
                            Text(
                              widget.isSpeaking ? 'Đang nói (Dừng)' : 'Đọc lại',
                              style: TextStyle(
                                fontSize: 11,
                                color: widget.isSpeaking
                                    ? AppTheme.accentCyan
                                    : AppTheme.textSecondary,
                                fontWeight: widget.isSpeaking
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.message.modelUsed != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderDark),
                        ),
                        child: Text(
                          '🤖 ${widget.message.modelUsed}',
                          style: const TextStyle(
                            fontSize: 10,
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
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white54, width: 1),
          ),
        );
        label = 'Màu RGB($r, $g, $b)';
        badgeColor = AppTheme.accentBlue;
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
        label = 'Hiệu ứng: ${eff.displayName} (${speed}ms)';
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
        label = 'Số LED: $count bóng';
        badgeColor = AppTheme.accentGreen;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingDot != null)
            leadingDot
          else
            Icon(icon, color: badgeColor, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: badgeColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
