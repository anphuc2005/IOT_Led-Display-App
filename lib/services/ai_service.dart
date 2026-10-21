import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AiService {
  String _apiKey = '';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  void setApiKey(String key) {
    _apiKey = key;
  }

  bool get hasApiKey => _apiKey.isNotEmpty;

  Future<Map<String, dynamic>> processCommand(String userMessage) async {
    if (_apiKey.isEmpty) {
      return {
        'response': 'Vui lòng cấu hình Gemini API Key trong phần Cài đặt.',
        'command': null,
      };
    }

    try {
      final prompt = '''
Bạn là trợ lý AI điều khiển đèn LED thông minh. Phân tích câu nói của người dùng và trả về JSON response.

Các lệnh bạn có thể thực hiện:
1. Bật/tắt đèn: {"action": "power", "state": "on"/"off"}
2. Đổi màu: {"action": "color", "r": 0-255, "g": 0-255, "b": 0-255}
3. Chỉnh độ sáng: {"action": "brightness", "value": 0-100}
4. Hiệu ứng: {"action": "effect", "type": "blink"/"fade"/"rainbow"/"breathing"/"strobe"/"color_wipe"/"chase"/"none", "speed": 100-2000}
5. Chế độ tự động: {"action": "auto_mode", "enabled": true/false}

Bảng tham chiếu màu:
- Đỏ: r=255, g=0, b=0
- Xanh lá: r=0, g=255, b=0
- Xanh dương: r=0, g=0, b=255
- Vàng: r=255, g=255, b=0
- Tím: r=128, g=0, b=255
- Cam: r=255, g=165, b=0
- Hồng: r=255, g=105, b=180
- Trắng: r=255, g=255, b=255
- Cyan: r=0, g=255, b=255
- Ấm: r=255, g=180, b=100
- Mát: r=100, g=180, b=255

Trả về JSON với format:
{
  "response": "Câu trả lời thân thiện bằng tiếng Việt",
  "command": {lệnh tương ứng hoặc null nếu không phải lệnh điều khiển}
}

Chỉ trả về JSON, không có text khác.

Người dùng nói: "$userMessage"
''';

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.3,
            'maxOutputTokens': 500,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'];

        // Extract JSON from response (handle markdown code blocks)
        String jsonStr = text.trim();
        if (jsonStr.startsWith('```json')) {
          jsonStr = jsonStr.substring(7);
        }
        if (jsonStr.startsWith('```')) {
          jsonStr = jsonStr.substring(3);
        }
        if (jsonStr.endsWith('```')) {
          jsonStr = jsonStr.substring(0, jsonStr.length - 3);
        }
        jsonStr = jsonStr.trim();

        final result = jsonDecode(jsonStr);
        return {
          'response': result['response'] ?? 'Đã xử lý lệnh.',
          'command': result['command'],
        };
      } else {
        debugPrint('Gemini API Error: ${response.statusCode} ${response.body}');
        return {
          'response': 'Lỗi kết nối API. Mã lỗi: ${response.statusCode}',
          'command': null,
        };
      }
    } catch (e) {
      debugPrint('AI Service Error: $e');
      return {
        'response': 'Xin lỗi, tôi gặp lỗi khi xử lý. Vui lòng thử lại.',
        'command': null,
      };
    }
  }
}
