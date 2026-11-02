import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

class GeminiModelInfo {
  final String id;
  final String name;
  final String description;

  const GeminiModelInfo({
    required this.id,
    required this.name,
    required this.description,
  });
}

class AiService extends ChangeNotifier {
  String _apiKey = StorageService.defaultGeminiApiKey;
  String? _previousInteractionId;
  String? _lastInteractionModel;

  static const String _interactionsUrl =
      'https://generativelanguage.googleapis.com/v1beta/interactions';
  static const String _modelsBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Multi-model pool: Automatically rotates to the next model when quota/rate-limit (429) or overload (503) occurs
  static const List<GeminiModelInfo> modelPool = [
    GeminiModelInfo(
      id: 'gemini-2.5-flash',
      name: 'Gemini 2.5 Flash (Tức thì - 0s Thinking)',
      description: 'Phản hồi cực nhanh <1s, tắt hoàn toàn thinking delay',
    ),
    GeminiModelInfo(
      id: 'gemini-3.5-flash-lite',
      name: 'Gemini 3.5 Flash-Lite',
      description: 'Model thế hệ mới, nhẹ và tiết kiệm quota',
    ),
    GeminiModelInfo(
      id: 'gemini-3.1-flash-lite',
      name: 'Gemini 3.1 Flash-Lite',
      description: 'Nhẹ, tiết kiệm quota, độ trễ cực thấp',
    ),
    GeminiModelInfo(
      id: 'gemini-3.6-flash',
      name: 'Gemini 3.6 Flash',
      description: 'Model Flash ổn định, suy luận nhanh',
    ),
    GeminiModelInfo(
      id: 'gemini-3.5-flash',
      name: 'Gemini 3.5 Flash',
      description: 'Model cân bằng tốc độ & độ chính xác',
    ),
    GeminiModelInfo(
      id: 'gemini-3-flash-preview',
      name: 'Gemini 3 Flash Preview',
      description: 'Model dự phòng tốc độ cao',
    ),
    GeminiModelInfo(
      id: 'gemini-3.8-flash',
      name: 'Gemini 3.8 Flash',
      description: 'Model đa năng thế hệ mới nhất',
    ),
    GeminiModelInfo(
      id: 'gemma-4-26b-a4b-it',
      name: 'Gemma 4 26B MoE',
      description: 'Model Gemma 4 MoE dự phòng khi Gemini hết quota',
    ),
    GeminiModelInfo(
      id: 'gemma-4-31b-it',
      name: 'Gemma 4 31B',
      description: 'Model Gemma 4 Dense dự phòng độc lập',
    ),
    GeminiModelInfo(
      id: 'gemini-4-argon',
      name: 'Gemini 4 Argon',
      description: 'Model mạnh nhất dự phòng cuối',
    ),
  ];

  int _currentModelIndex = 0;
  bool _autoRotate = true;
  String _lastUsedModel = modelPool.first.id;
  final Map<String, DateTime> _modelCooldownUntil = {};
  final Map<String, String> _modelLastError = {};

  /// Pre-configured Smart LED Specialist Agent Prompt
  static const String _ledAgentSystemInstruction = '''
Bạn là "Smart LED Agent" — Trợ lý AI chuyên gia được cấu hình sẵn CHỈ ĐỂ giải đáp các câu hỏi về hệ thống đèn LED thông minh và điều khiển/điều chỉnh đèn LED qua MQTT.

1. PHẠM VI HOẠT ĐỘNG NGHIÊM NGẶT (CHỈ VỀ ĐÈN & ÁNH SÁNG):
- Bạn CHỈ trả lời các câu hỏi liên quan đến:
  + Trạng thái hiện tại của đèn (bật/tắt, màu sắc RGB, độ sáng %, hiệu ứng đang chạy, tốc độ nháy, số bóng LED).
  + Dữ liệu cảm biến của hệ thống đèn (cường độ ánh sáng phòng tính bằng lux từ BH1750, phát hiện chuyển động người từ PIR, chế độ tự động Auto Mode).
  + Kiến thức kỹ thuật & cách sử dụng hệ thống đèn này (mạch ESP32, dải LED WS2812 NeoPixel, 8 hiệu ứng ánh sáng, tư vấn phối màu/độ sáng cho giấc ngủ, học tập, thư giãn, tiệc tùng).
  + Thực hiện các yêu cầu bật/tắt, đổi màu, tăng/giảm độ sáng, đổi hiệu ứng, bật/tắt cảm biến tự động.
- NẾU người dùng hỏi các chủ đề NGOÀI LỀ không liên quan đến đèn, ánh sáng hoặc cảm biến trong phòng (ví dụ: giải toán, lịch sử, nấu ăn, thời sự, viết code không liên quan...):
  + Hãy lịch sự từ chối: "Mình là Agent chuyên trách hệ thống đèn LED thông minh. Mình chỉ hỗ trợ giải đáp các câu hỏi về đèn, cảm biến ánh sáng và giúp bạn điều khiển đèn thôi nhé!"
  + Trả về mảng "commands": [] (không thay đổi đèn).

2. KIẾN THỨC HỆ THỐNG ĐÈN ĐƯỢC NẠP SẴN CHO AGENT:
- Phần cứng: Vi điều khiển ESP32 kết nối WiFi & MQTT, điều khiển dải LED WS2812/NeoPixel (chân GPIO 18, mặc định 8 bóng, hỗ trợ 1-300 bóng, giới hạn an toàn công suất 80/255 mỗi kênh RGB).
- Cảm biến đi kèm:
  + BH1750 (chân SDA=GPIO 21, SCL=GPIO 22): Đo cường độ sáng môi trường (lux). Dưới 30 lux là phòng tối, trên 45 lux là phòng đủ sáng, dưới 5 lux là tối hoàn toàn.
  + PIR (chân GPIO 27): Cảm biến chuyển động hồng ngoại, thời gian khởi động 45 giây, tự giữ đèn sáng 60 giây sau chuyển động cuối.
  + DHT11 (chân GPIO 26): Cảm biến nhiệt độ & độ ẩm; ở chế độ tự động, nhiệt độ từ 20-35°C sẽ tự pha màu từ trắng sang vàng ấm.
- 8 Chế độ Hiệu ứng LED ("effect"):
  + "none": Sáng tĩnh một màu (Không hiệu ứng)
  + "blink": Nhấp nháy bật/tắt
  + "fade": Sáng dần rồi tối dần mượt mà (Fade In/Out)
  + "rainbow": Chuyển dải màu cầu vồng động
  + "breathing": Nhịp thở êm dịu mô phỏng hơi thở
  + "strobe": Chớp trắng tốc độ cao như đèn sân khấu
  + "color_wipe": Quét màu lần lượt từng bóng LED
  + "chase": Hiệu ứng rượt đuổi ánh sáng dọc dải LED
  (Tốc độ "speed" từ 50ms đến 3000ms: số càng nhỏ chạy càng nhanh; rất nhanh=100, nhanh=200, vừa=500, chậm=1200).

3. QUY TẮC PHÂN BIỆT "HỎI THÔNG TIN ĐÈN" VÀ "ĐIỀU KHIỂN ĐÈN":
- Khi người dùng CHỈ HỎI thông tin về đèn (ví dụ: "Đèn đang màu gì?", "Độ sáng bao nhiêu?", "Phòng đang bao nhiêu lux?", "Có mấy hiệu ứng?", "Chế độ tự động hoạt động sao?"):
  + Dựa vào [Trạng thái đèn hiện tại] và kiến thức trên để trả lời chính xác, rõ ràng bằng tiếng Việt.
  + Trả về "commands": [] (giữ nguyên đèn).
- Khi người dùng YÊU CẦU ĐIỀU KHIỂN / ĐIỀU CHỈNH ĐÈN hoặc NÊU NHU CẦU ÁNH SÁNG (ví dụ: "Bật đèn xanh", "Hơi tối tăng sáng lên", "Cho nháy nhanh hơn", "Chỉnh đèn học bài", "Chỉnh đèn đi ngủ", "Chói mắt quá"):
  + Trả lời xác nhận thân thiện và trả về đầy đủ các tín hiệu điều khiển trong mảng "commands":
    * Bật/tắt: {"action": "power", "state": "on" | "off"}
    * Đổi màu: {"action": "color", "color": {"r": 0-255, "g": 0-255, "b": 0-255}}
    * Độ sáng: {"action": "brightness", "brightness": 0-100}
    * Hiệu ứng: {"action": "effect", "effect": {"type": "none"|"blink"|"fade"|"rainbow"|"breathing"|"strobe"|"color_wipe"|"chase", "speed": 50-3000}}
    * Tự động: {"action": "auto_mode", "auto_mode": true | false}
    * Số bóng: {"action": "num_leds", "num_leds": 1-300}

4. QUY TẮC GIỌNG NÓI (TTS):
- Trường "response" sẽ được đọc bằng giọng nói tiếng Việt và chạy chữ Typewriter, vì vậy viết câu ngắn gọn (1-3 câu), tự nhiên, KHÔNG dùng ký tự markdown (*, #, `, ~).

BẢNG MÀU THAM CHIẾU CHUẨN:
- Đỏ: r=255, g=0, b=0 | Xanh lá: r=0, g=255, b=0 | Xanh dương: r=0, g=0, b=255
- Vàng: r=255, g=255, b=0 | Tím / Lavender: r=138, g=43, b=226 | Cam: r=255, g=140, b=0
- Hồng: r=255, g=105, b=180 | Trắng: r=255, g=255, b=255 | Cyan / Xanh ngọc: r=0, g=255, b=255
- Vàng ấm / Đèn ngủ: r=255, g=180, b=100 | Trắng mát / Học bài: r=180, g=220, b=255
''';

  /// Fixed JSON Schema for Gemini Structured Output
  static const Map<String, dynamic> _responseFormat = {
    'type': 'text',
    'mime_type': 'application/json',
    'schema': {
      'type': 'object',
      'properties': {
        'response': {
          'type': 'string',
          'description':
              'Câu trả lời tiếng Việt của Smart LED Agent để phát giọng nói TTS và hiển thị.',
        },
        'commands': {
          'type': 'array',
          'description':
              'Danh sách tín hiệu điều khiển đèn LED cần gửi qua MQTT. Rỗng [] nếu chỉ trả lời câu hỏi thông tin.',
          'items': {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': [
                  'power',
                  'color',
                  'brightness',
                  'effect',
                  'auto_mode',
                  'num_leds',
                ],
              },
              'state': {
                'type': 'string',
                'enum': ['on', 'off'],
              },
              'color': {
                'type': 'object',
                'properties': {
                  'r': {'type': 'integer'},
                  'g': {'type': 'integer'},
                  'b': {'type': 'integer'},
                },
                'required': ['r', 'g', 'b'],
              },
              'brightness': {
                'type': 'integer',
              },
              'effect': {
                'type': 'object',
                'properties': {
                  'type': {
                    'type': 'string',
                    'enum': [
                      'none',
                      'blink',
                      'fade',
                      'rainbow',
                      'breathing',
                      'strobe',
                      'color_wipe',
                      'chase',
                    ],
                  },
                  'speed': {'type': 'integer'},
                },
                'required': ['type', 'speed'],
              },
              'auto_mode': {
                'type': 'boolean',
              },
              'num_leds': {
                'type': 'integer',
              },
            },
            'required': ['action'],
          },
        },
      },
      'required': ['response', 'commands'],
    },
  };

  void setApiKey(String key) {
    final trimmed = key.trim();
    _apiKey = trimmed.isEmpty ? StorageService.defaultGeminiApiKey : trimmed;
    _modelCooldownUntil.clear();
    _modelLastError.clear();
    notifyListeners();
  }

  String get apiKey => _apiKey;
  bool get hasApiKey => _apiKey.isNotEmpty;
  bool get autoRotate => _autoRotate;
  String get currentModelId => modelPool[_currentModelIndex].id;
  GeminiModelInfo get currentModelInfo => modelPool[_currentModelIndex];
  String get lastUsedModel => _lastUsedModel;

  bool isModelOnCooldown(String modelId) {
    final until = _modelCooldownUntil[modelId];
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _modelCooldownUntil.remove(modelId);
      _modelLastError.remove(modelId);
      return false;
    }
    return true;
  }

  String? getModelStatusNote(String modelId) {
    if (!isModelOnCooldown(modelId)) return null;
    return _modelLastError[modelId] ?? 'Đang tạm nghỉ (hết quota/bận)';
  }

  /// Manually select a model or enable auto-rotation
  void setModelPreference({int? modelIndex, bool? autoRotate}) {
    if (autoRotate != null) {
      _autoRotate = autoRotate;
    }
    if (modelIndex != null &&
        modelIndex >= 0 &&
        modelIndex < modelPool.length) {
      _currentModelIndex = modelIndex;
      _modelCooldownUntil.remove(modelPool[modelIndex].id);
      if (_lastInteractionModel != modelPool[modelIndex].id) {
        _previousInteractionId = null;
      }
    }
    notifyListeners();
  }

  /// Rotate immediately to the next model in the pool
  String rotateToNextModel({String? reason}) {
    final oldModel = modelPool[_currentModelIndex].id;
    if (reason != null) {
      _modelCooldownUntil[oldModel] =
          DateTime.now().add(const Duration(minutes: 3));
      _modelLastError[oldModel] = reason;
    }

    for (int step = 1; step <= modelPool.length; step++) {
      final candidateIdx = (_currentModelIndex + step) % modelPool.length;
      final candidateId = modelPool[candidateIdx].id;
      if (!isModelOnCooldown(candidateId)) {
        _currentModelIndex = candidateIdx;
        break;
      }
    }
    _previousInteractionId = null;
    notifyListeners();
    return modelPool[_currentModelIndex].id;
  }

  void resetConversation() {
    _previousInteractionId = null;
    _lastInteractionModel = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>> processCommand(
    String userMessage, {
    String? deviceContext,
  }) async {
    if (_apiKey.isEmpty) {
      return _runLocalLedAgent(userMessage, deviceContext: deviceContext);
    }

    final enrichedInput = deviceContext != null && deviceContext.isNotEmpty
        ? '[$deviceContext]\nCâu hỏi / Yêu cầu của người dùng: "$userMessage"'
        : userMessage;

    // Build ordered list of models to try starting from _currentModelIndex
    final totalModels = modelPool.length;
    final candidateIndices = <int>[];

    // First pass: healthy models not on cooldown
    for (int offset = 0; offset < totalModels; offset++) {
      final idx = (_currentModelIndex + offset) % totalModels;
      if (!isModelOnCooldown(modelPool[idx].id)) {
        candidateIndices.add(idx);
      }
      if (!_autoRotate && offset == 0) break;
    }

    // If all models were marked on cooldown, clear cooldowns and try all again
    if (candidateIndices.isEmpty) {
      _modelCooldownUntil.clear();
      for (int offset = 0; offset < totalModels; offset++) {
        candidateIndices.add((_currentModelIndex + offset) % totalModels);
      }
    }

    for (final idx in candidateIndices) {
      final modelInfo = modelPool[idx];
      final modelId = modelInfo.id;

      try {
        Map<String, dynamic>? result;

        // 1. If gemini-2.5-flash, execute ultra-fast direct generateContent with 0s thinking delay
        if (modelId == 'gemini-2.5-flash' || modelId.startsWith('gemini-2.5')) {
          result = await _callFastGenerateContent(
            model: modelId,
            input: enrichedInput,
          );
        } else {
          final prevId =
              (_lastInteractionModel == modelId) ? _previousInteractionId : null;

          result = await _callInteractionsApi(
            model: modelId,
            input: enrichedInput,
            previousInteractionId: prevId,
          );

          result ??= await _callFastGenerateContent(
            model: modelId,
            input: enrichedInput,
          );
        }

        if (result != null) {
          _currentModelIndex = idx;
          _lastUsedModel = modelId;
          _lastInteractionModel = modelId;
          notifyListeners();
          return {
            ...result,
            'modelUsed': modelId,
          };
        }
      } catch (e) {
        debugPrint('Model $modelId failed, rotating to next model: $e');
        _markModelCooldown(modelId, e.toString());
      }
    }

    // Fallback to Built-in Local LED Agent if all cloud models are exhausted/offline
    final localResult =
        _runLocalLedAgent(userMessage, deviceContext: deviceContext);
    _lastUsedModel = 'local-led-agent';
    notifyListeners();
    return localResult;
  }

  void _markModelCooldown(String modelId, String errorMsg) {
    final isQuota = errorMsg.contains('429') ||
        errorMsg.toLowerCase().contains('quota') ||
        errorMsg.toLowerCase().contains('exhausted');
    final duration =
        isQuota ? const Duration(minutes: 5) : const Duration(seconds: 90);
    _modelCooldownUntil[modelId] = DateTime.now().add(duration);
    _modelLastError[modelId] =
        isQuota ? 'Hết lượt (429) - Đã xoay model' : 'Quá tải/Lỗi - Đã xoay model';
  }

  Future<Map<String, dynamic>?> _callInteractionsApi({
    required String model,
    required String input,
    String? previousInteractionId,
  }) async {
    final body = <String, dynamic>{
      'model': model,
      'system_instruction': _ledAgentSystemInstruction,
      'input': input,
      'response_format': _responseFormat,
      'generation_config': {
        'temperature': 0.25,
        'max_output_tokens': 600,
      },
    };

    if (previousInteractionId != null) {
      body['previous_interaction_id'] = previousInteractionId;
    }

    final response = await http
        .post(
          Uri.parse('$_interactionsUrl?key=$_apiKey'),
          headers: const {
            'Content-Type': 'application/json',
            'Api-Revision': '2026-05-20',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    // Retry without previous_interaction_id if session expired or switched model
    if (response.statusCode == 400 && previousInteractionId != null) {
      _previousInteractionId = null;
      return _callInteractionsApi(
        model: model,
        input: input,
        previousInteractionId: null,
      );
    }

    if (response.statusCode == 429 || response.statusCode == 503) {
      _markModelCooldown(model, 'HTTP ${response.statusCode}');
      // Automatically rotate index for future turns
      _currentModelIndex = (_currentModelIndex + 1) % modelPool.length;
      return null;
    }

    if (response.statusCode != 200) {
      // Try fast generateContent endpoint as secondary fallback for this model
      return _callFastGenerateContent(model: model, input: input);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final interactionId = data['id'] as String?;
    if (interactionId != null && interactionId.isNotEmpty) {
      _previousInteractionId = interactionId;
    }

    final outputText = _extractOutputText(data);
    if (outputText == null || outputText.isEmpty) {
      return null;
    }

    return _parseAgentJsonResponse(outputText);
  }

  Future<Map<String, dynamic>?> _callFastGenerateContent({
    required String model,
    required String input,
  }) async {
    final Map<String, dynamic> generationConfig = {
      'temperature': 0.1,
      'maxOutputTokens': 250,
      'responseMimeType': 'application/json',
    };

    // If model supports thinking (like gemini-2.5-flash), disable thinking budget to eliminate delay!
    if (model.contains('2.5')) {
      generationConfig['thinkingConfig'] = {'thinkingBudget': 0};
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_modelsBaseUrl/$model:generateContent?key=$_apiKey'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'systemInstruction': {
                'parts': [
                  {'text': _ledAgentSystemInstruction}
                ]
              },
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {
                      'text': '$input\n\n'
                          'Yêu cầu: Trả về DUY NHẤT một chuỗi JSON hợp lệ theo cấu trúc: {"response": "câu trả lời tiếng Việt ngắn gọn", "commands": [...]}.'
                    }
                  ]
                }
              ],
              'generationConfig': generationConfig,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 429 || response.statusCode == 503) {
        _markModelCooldown(model, 'HTTP ${response.statusCode}');
        _currentModelIndex = (_currentModelIndex + 1) % modelPool.length;
        return null;
      }

      if (response.statusCode != 200) {
        debugPrint(
          'Gemini generateContent Error ($model): ${response.statusCode}',
        );
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) return null;
      final parts =
          candidates.first['content']?['parts'] as List<dynamic>? ?? const [];
      final buffer = StringBuffer();
      for (final p in parts) {
        if (p is Map && p['text'] != null) {
          buffer.write(p['text']);
        }
      }
      final text = buffer.toString().trim();
      if (text.isEmpty) return null;
      return _parseAgentJsonResponse(text);
    } catch (e) {
      debugPrint('Fast generateContent error ($model): $e');
      return null;
    }
  }

  Map<String, dynamic>? _parseAgentJsonResponse(String rawText) {
    final parsed =
        jsonDecode(_cleanJsonString(rawText)) as Map<String, dynamic>;
    final reply = (parsed['response'] as String?)?.trim() ??
        'Mình đã xử lý yêu cầu về đèn cho bạn.';
    final rawCommands = (parsed['commands'] as List<dynamic>?) ??
        (parsed['command'] != null ? [parsed['command']] : const []);
    final normalizedCommands = _normalizeCommands(rawCommands);

    return {
      'response': reply,
      'command':
          normalizedCommands.isNotEmpty ? normalizedCommands.first : null,
      'commands': normalizedCommands,
    };
  }

  /// Built-in Local Smart LED Agent when all cloud models are out of quota or offline
  Map<String, dynamic> _runLocalLedAgent(
    String userMessage, {
    String? deviceContext,
  }) {
    final lower = userMessage.toLowerCase();
    final commands = <Map<String, dynamic>>[];

    // Check if user is asking a question about the LED state/system
    final isQuestion = lower.contains('đang') ||
        lower.contains('bao nhiêu') ||
        lower.contains('màu gì') ||
        lower.contains('hiệu ứng gì') ||
        lower.contains('là gì') ||
        lower.contains('như thế nào') ||
        lower.contains('có mấy') ||
        lower.contains('?');

    if (isQuestion &&
        !lower.contains('bật') &&
        !lower.contains('tắt') &&
        !lower.contains('đổi') &&
        !lower.contains('chỉnh') &&
        !lower.contains('tăng') &&
        !lower.contains('giảm')) {
      final ctxInfo = deviceContext ??
          'Hệ thống đèn LED ESP32 gồm 8 bóng WS2812, cảm biến ánh sáng BH1750 và chuyển động PIR.';
      return {
        'response':
            'Thông tin từ Agent đèn LED: $ctxInfo Bạn có muốn mình điều chỉnh độ sáng, màu sắc hay hiệu ứng gì không?',
        'command': null,
        'commands': <Map<String, dynamic>>[],
        'modelUsed': 'local-led-agent',
      };
    }

    // Parse control intents locally
    if (lower.contains('tắt đèn') || lower == 'tắt') {
      commands.add({'action': 'power', 'state': 'off'});
      return {
        'response': 'Mình đã tắt đèn LED cho bạn rồi nhé.',
        'command': commands.first,
        'commands': commands,
        'modelUsed': 'local-led-agent',
      };
    }

    if (lower.contains('tự động')) {
      final enable = !lower.contains('tắt tự động');
      commands.add({'action': 'auto_mode', 'enabled': enable});
      return {
        'response': enable
            ? 'Mình đã bật chế độ cảm biến tự động theo ánh sáng và chuyển động.'
            : 'Mình đã tắt chế độ tự động để bạn điều khiển đèn thủ công.',
        'command': commands.first,
        'commands': commands,
        'modelUsed': 'local-led-agent',
      };
    }

    // Color matching
    final colorMap = <String, List<int>>{
      'đỏ': [255, 0, 0],
      'xanh lá': [0, 255, 0],
      'xanh dương': [0, 0, 255],
      'xanh biển': [0, 0, 255],
      'xanh ngọc': [0, 255, 255],
      'cyan': [0, 255, 255],
      'vàng ấm': [255, 180, 100],
      'ấm': [255, 180, 100],
      'ngủ': [255, 180, 100],
      'vàng': [255, 255, 0],
      'tím': [138, 43, 226],
      'cam': [255, 140, 0],
      'hồng': [255, 105, 180],
      'trắng mát': [180, 220, 255],
      'học bài': [180, 220, 255],
      'trắng': [255, 255, 255],
    };

    for (final entry in colorMap.entries) {
      if (lower.contains(entry.key)) {
        commands.add({'action': 'power', 'state': 'on'});
        commands.add({
          'action': 'color',
          'r': entry.value[0],
          'g': entry.value[1],
          'b': entry.value[2],
        });
        break;
      }
    }

    // Effect matching
    final effectMap = <String, String>{
      'cầu vồng': 'rainbow',
      'rainbow': 'rainbow',
      'nhấp nháy': 'blink',
      'nháy': 'blink',
      'thở': 'breathing',
      'mờ dần': 'fade',
      'fade': 'fade',
      'chớp': 'strobe',
      'strobe': 'strobe',
      'quét': 'color_wipe',
      'đuổi': 'chase',
      'đứng yên': 'none',
    };

    for (final entry in effectMap.entries) {
      if (lower.contains(entry.key)) {
        final speed = lower.contains('nhanh')
            ? 150
            : lower.contains('chậm')
                ? 1200
                : 500;
        commands.add({
          'action': 'effect',
          'type': entry.value,
          'speed': speed,
        });
        break;
      }
    }

    // Brightness matching
    final numMatch = RegExp(r'(\d{1,3})\s*%').firstMatch(lower);
    if (numMatch != null) {
      final val = int.tryParse(numMatch.group(1)!) ?? 80;
      commands.add({'action': 'brightness', 'value': val.clamp(0, 100)});
    } else if (lower.contains('tăng sáng') || lower.contains('sáng lên')) {
      commands.add({'action': 'brightness', 'value': 90});
    } else if (lower.contains('giảm sáng') ||
        lower.contains('tối bớt') ||
        lower.contains('chói')) {
      commands.add({'action': 'brightness', 'value': 30});
    }

    if (commands.isEmpty && lower.contains('bật')) {
      commands.add({'action': 'power', 'state': 'on'});
    }

    if (commands.isNotEmpty) {
      return {
        'response':
            'Mình đã thực hiện điều chỉnh đèn LED theo yêu cầu của bạn rồi nhé.',
        'command': commands.first,
        'commands': commands,
        'modelUsed': 'local-led-agent',
      };
    }

    return {
      'response':
          'Mình là Agent chuyên trách hệ thống đèn LED thông minh. Bạn có thể hỏi mình về trạng thái đèn, độ sáng lux trong phòng, hoặc bảo mình bật tắt, đổi màu, chỉnh hiệu ứng đèn nhé!',
      'command': null,
      'commands': <Map<String, dynamic>>[],
      'modelUsed': 'local-led-agent',
    };
  }

  String? _extractOutputText(Map<String, dynamic> interactionData) {
    final steps = interactionData['steps'] as List<dynamic>?;
    if (steps == null) return null;

    final buffer = StringBuffer();
    for (final step in steps) {
      if (step is Map<String, dynamic> && step['type'] == 'model_output') {
        final contentList = step['content'] as List<dynamic>?;
        if (contentList != null) {
          for (final item in contentList) {
            if (item is Map<String, dynamic> && item['type'] == 'text') {
              buffer.write(item['text'] ?? '');
            }
          }
        }
      }
    }
    final result = buffer.toString().trim();
    return result.isEmpty ? null : result;
  }

  String _cleanJsonString(String raw) {
    String jsonStr = raw.trim();
    if (jsonStr.startsWith('```json')) {
      jsonStr = jsonStr.substring(7);
    } else if (jsonStr.startsWith('```')) {
      jsonStr = jsonStr.substring(3);
    }
    if (jsonStr.endsWith('```')) {
      jsonStr = jsonStr.substring(0, jsonStr.length - 3);
    }
    return jsonStr.trim();
  }

  List<Map<String, dynamic>> _normalizeCommands(List<dynamic> rawCommands) {
    final result = <Map<String, dynamic>>[];

    for (final item in rawCommands) {
      if (item is! Map) continue;
      final cmd = Map<String, dynamic>.from(item);
      final action = cmd['action']?.toString().toLowerCase().trim();
      if (action == null) continue;

      if (action == 'power' ||
          action == 'turn_on' ||
          action == 'turnon' ||
          action == 'turn_off' ||
          action == 'turnoff') {
        final state = (action.contains('off') ||
                (cmd['state'] ?? cmd['value'])?.toString().toLowerCase() ==
                    'off')
            ? 'off'
            : 'on';
        result.add({
          'action': 'power',
          'state': state,
        });
      } else if (action == 'color' || action == 'set_color') {
        int r = 255, g = 255, b = 255;
        if (cmd['color'] is Map) {
          final m = cmd['color'] as Map;
          r = ((m['r'] as num?)?.toInt() ?? 255).clamp(0, 255);
          g = ((m['g'] as num?)?.toInt() ?? 255).clamp(0, 255);
          b = ((m['b'] as num?)?.toInt() ?? 255).clamp(0, 255);
        } else if (cmd['r'] != null || cmd['g'] != null || cmd['b'] != null) {
          r = ((cmd['r'] as num?)?.toInt() ?? 255).clamp(0, 255);
          g = ((cmd['g'] as num?)?.toInt() ?? 255).clamp(0, 255);
          b = ((cmd['b'] as num?)?.toInt() ?? 255).clamp(0, 255);
        } else {
          final val = (cmd['value'] ?? cmd['color'] ?? '')
              .toString()
              .toLowerCase()
              .trim();
          final named = {
            'red': [255, 0, 0],
            'đỏ': [255, 0, 0],
            'green': [0, 255, 0],
            'xanh lá': [0, 255, 0],
            'blue': [0, 0, 255],
            'xanh dương': [0, 0, 255],
            'yellow': [255, 255, 0],
            'vàng': [255, 255, 0],
            'purple': [138, 43, 226],
            'tím': [138, 43, 226],
            'orange': [255, 140, 0],
            'cam': [255, 140, 0],
            'pink': [255, 105, 180],
            'hồng': [255, 105, 180],
            'white': [255, 255, 255],
            'trắng': [255, 255, 255],
            'cyan': [0, 255, 255],
            'xanh ngọc': [0, 255, 255],
          }[val];
          if (named != null) {
            r = named[0];
            g = named[1];
            b = named[2];
          }
        }
        result.add({
          'action': 'color',
          'r': r,
          'g': g,
          'b': b,
        });
      } else if (action == 'brightness' || action == 'set_brightness') {
        final val = (cmd['brightness'] ?? cmd['value']) as num?;
        result.add({
          'action': 'brightness',
          'value': (val?.toInt() ?? 80).clamp(0, 100),
        });
      } else if (action == 'effect' || action == 'set_effect') {
        final effectMap = cmd['effect'] is Map
            ? Map<String, dynamic>.from(cmd['effect'] as Map)
            : cmd;
        final type =
            (effectMap['type'] ?? effectMap['value'] as String?) ?? 'none';
        final speed =
            ((effectMap['speed'] as num?)?.toInt() ?? 500).clamp(50, 3000);
        result.add({
          'action': 'effect',
          'type': type,
          'speed': speed,
        });
      } else if (action == 'auto_mode') {
        final enabled =
            (cmd['auto_mode'] ?? cmd['enabled'] ?? cmd['value']) as bool? ??
                true;
        result.add({
          'action': 'auto_mode',
          'enabled': enabled,
        });
      } else if (action == 'num_leds') {
        final count =
            (cmd['num_leds'] ?? cmd['count'] ?? cmd['value']) as num?;
        result.add({
          'action': 'num_leds',
          'count': (count?.toInt() ?? 8).clamp(1, 300),
        });
      }
    }

    return result;
  }
}
