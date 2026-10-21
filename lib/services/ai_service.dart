import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  String _apiKey = '';
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  void setApiKey(String value) => _apiKey = value.trim();
  bool get hasApiKey => _apiKey.isNotEmpty;

  Future<Map<String, dynamic>> processCommand(String userMessage) async {
    if (!hasApiKey) {
      return {
        'response': 'Bạn cần cấu hình Gemini API Key trong phần Cài đặt.',
        'command': null
      };
    }

    final prompt = '''
Bạn là trợ lý điều khiển đèn LED thông minh. Hãy trả về duy nhất JSON hợp lệ bằng tiếng Việt.

Lệnh hỗ trợ:
- {"action":"power","state":"on|off"}
- {"action":"color","r":0-255,"g":0-255,"b":0-255}
- {"action":"brightness","value":0-100}
- {"action":"effect","type":"blink|fade|rainbow|breathing|strobe|color_wipe|chase|none","speed":50-3000}
- {"action":"auto_mode","enabled":true|false}

Định dạng: {"response":"Câu trả lời thân thiện", "command":null hoặc một lệnh phía trên}
Người dùng: ${jsonEncode(userMessage)}
''';

    try {
      final response = await http
          .post(
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
                'temperature': 0.2,
                'maxOutputTokens': 500,
                'responseMimeType': 'application/json'
              },
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        return {
          'response':
              'Gemini đang tạm thời không phản hồi (mã ${response.statusCode}).',
          'command': null
        };
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = body['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw const FormatException('Không có kết quả');
      }
      final content = candidates.first as Map<String, dynamic>;
      final text = (((content['content'] as Map<String, dynamic>)['parts']
              as List<dynamic>)
          .first as Map<String, dynamic>)['text'] as String;
      final decoded = jsonDecode(_stripCodeFence(text)) as Map<String, dynamic>;
      return {
        'response': decoded['response'] as String? ?? 'Đã xử lý yêu cầu.',
        'command': decoded['command'] is Map<String, dynamic>
            ? decoded['command']
            : null,
      };
    } catch (_) {
      return {
        'response': 'Mình chưa thể xử lý yêu cầu này. Bạn hãy thử lại.',
        'command': null
      };
    }
  }

  String _stripCodeFence(String value) => value
      .trim()
      .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
      .replaceFirst(RegExp(r'\s*```$'), '')
      .trim();
}
