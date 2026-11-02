/// Helper utility that normalizes technical Smart LED & IoT terms into
/// natural Vietnamese phonetic words for high-quality TTS playback
/// (supporting VieNeu-TTS neural engine and local fallback engines).
class PronunciationHelper {
  PronunciationHelper._();

  /// Known hex color mappings for smooth spoken response
  static final Map<String, String> _hexColorNames = {
    '#FF0000': 'màu đỏ',
    '#00FF00': 'màu xanh lá',
    '#0000FF': 'màu xanh dương',
    '#FFFF00': 'màu vàng',
    '#FFA500': 'màu cam',
    '#800080': 'màu tím',
    '#FF00FF': 'màu hồng cánh sen',
    '#FFC0CB': 'màu hồng phấn',
    '#00FFFF': 'màu xanh ngọc',
    '#FFFFFF': 'màu trắng',
    '#000000': 'tắt đèn',
  };

  /// Main normalization function for Smart LED speech
  static String normalizeForTts(String input) {
    if (input.trim().isEmpty) return '';

    String text = input;

    // 1. Remove markdown code blocks (e.g. ```json ... ``` or ``` ... ```)
    text = text.replaceAll(RegExp(r'```[\s\S]*?```', multiLine: true), ' ');

    // 2. Remove inline code snippets like `command`
    text = text.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m[1] ?? '');

    // 3. Remove URLs
    text = text.replaceAll(RegExp(r'https?:\/\/[^\s]+'), ' ');

    // 4. Map known hex colors (#RRGGBB) to Vietnamese color names
    for (final entry in _hexColorNames.entries) {
      text = text.replaceAll(RegExp(entry.key, caseSensitive: false), entry.value);
    }
    // Remove any remaining raw hex codes (e.g. #AABBCC)
    text = text.replaceAll(RegExp(r'#[0-9a-fA-F]{6}'), ' ');

    // 5. Replace percentage and math symbols
    text = text.replaceAll('%', ' phần trăm');
    text = text.replaceAll('+', ' cộng ');
    text = text.replaceAll('±', ' xấp xỉ ');

    // 6. Replace temperature & color temperature
    text = text.replaceAllMapped(
      RegExp(r'(\d+)\s*°C', caseSensitive: false),
      (m) => '${m[1]} độ xê',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d{3,5})\s*K\b'),
      (m) => '${m[1]} ken-vin',
    );

    // 7. Time and electrical units attached to numbers
    text = text.replaceAllMapped(
      RegExp(r'(\d+)\s*ms\b', caseSensitive: false),
      (m) => '${m[1]} mili giây',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+)\s*mA\b'),
      (m) => '${m[1]} mili am-pe',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+)\s*A\b'),
      (m) => '${m[1]} am-pe',
    );
    // Vôn (case sensitive so it doesn't match Vietnamese words starting with v)
    text = text.replaceAllMapped(
      RegExp(r'(\d+)\s*V\b'),
      (m) => '${m[1]} vôn',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+)\s*W\b'),
      (m) => '${m[1]} oát',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+)\s*lux\b', caseSensitive: false),
      (m) => '${m[1]} lắc',
    );
    text = text.replaceAll(RegExp(r'\blux\b', caseSensitive: false), 'lắc');

    // 8. Smart LED & IoT hardware acronyms
    // WS2812 / WS2812B
    text = text.replaceAll(
      RegExp(r'WS2812B', caseSensitive: false),
      'đúp-liu ét hai tám một hai bê',
    );
    text = text.replaceAll(
      RegExp(r'WS2812', caseSensitive: false),
      'đúp-liu ét hai tám một hai',
    );

    // RGB / RGBW
    text = text.replaceAll(
      RegExp(r'RGBW', caseSensitive: false),
      'rờ gờ bê đúp-liu',
    );
    text = text.replaceAll(
      RegExp(r'RGB', caseSensitive: false),
      'rờ gờ bê',
    );

    // LED / LEDs pronunciation
    // "đèn LED" -> "đèn lét"
    text = text.replaceAll(RegExp(r'đèn\s+LED', caseSensitive: false), 'đèn lét');
    text = text.replaceAll(RegExp(r'dải\s+LED', caseSensitive: false), 'dải lét');
    text = text.replaceAll(RegExp(r'thanh\s+LED', caseSensitive: false), 'thanh lét');
    text = text.replaceAll(RegExp(r'bóng\s+LED', caseSensitive: false), 'bóng lét');
    text = text.replaceAll(RegExp(r'LEDs', caseSensitive: false), 'các bóng lét');
    text = text.replaceAll(RegExp(r'\bLED\b', caseSensitive: false), 'lét');

    // Microcontrollers
    text = text.replaceAll(
      RegExp(r'ESP32', caseSensitive: false),
      'e-ét-pi ba hai',
    );
    text = text.replaceAll(
      RegExp(r'ESP8266', caseSensitive: false),
      'e-ét-pi tám hai sáu sáu',
    );
    text = text.replaceAll(
      RegExp(r'\bESP\b', caseSensitive: false),
      'e-ét-pi',
    );

    // Sensors
    text = text.replaceAll(
      RegExp(r'BH1750', caseSensitive: false),
      'bê-hát một bảy năm không',
    );
    text = text.replaceAll(
      RegExp(r'DHT11', caseSensitive: false),
      'đê-hát-tê mười một',
    );
    text = text.replaceAll(
      RegExp(r'DHT22', caseSensitive: false),
      'đê-hát-tê hai hai',
    );
    text = text.replaceAll(
      RegExp(r'cảm biến\s+PIR', caseSensitive: false),
      'cảm biến chuyển động pi-a',
    );
    text = text.replaceAll(
      RegExp(r'\bPIR\b', caseSensitive: false),
      'cảm biến chuyển động pi-a',
    );

    // Protocols & Network
    text = text.replaceAll(
      RegExp(r'\bMQTT\b', caseSensitive: false),
      'em quy tê tê',
    );
    text = text.replaceAll(
      RegExp(r'\bBroker\b', caseSensitive: false),
      'máy chủ bro-kơ',
    );
    text = text.replaceAll(
      RegExp(r'Wi[- ]?Fi', caseSensitive: false),
      'oai-fai',
    );
    text = text.replaceAll(
      RegExp(r'Bluetooth', caseSensitive: false),
      'bờ-lu-tút',
    );
    text = text.replaceAll(
      RegExp(r'\bIP\b', caseSensitive: false),
      'ai pi',
    );

    // Common Smart Home statuses
    text = text.replaceAll(RegExp(r'\bON\b'), 'bật');
    text = text.replaceAll(RegExp(r'\bOFF\b'), 'tắt');
    text = text.replaceAll(RegExp(r'\bAuto\b', caseSensitive: false), 'tự động');
    text = text.replaceAll(RegExp(r'\bManual\b', caseSensitive: false), 'thủ công');

    // 9. Remove markdown characters & decorative bullets
    text = text.replaceAll(RegExp(r'[*_#~>]'), ' ');
    text = text.replaceAll(RegExp(r'^[ \t]*[-+*]\s+', multiLine: true), '');

    // 10. Strip emoji unicode characters (common in AI outputs)
    text = text.replaceAll(
      RegExp(
        r'[\u{1F300}-\u{1F5FF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
        unicode: true,
      ),
      '',
    );

    // 11. Normalize whitespaces and clean up punctuation
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    text = text.replaceAll(RegExp(r'\s+([,.:?!])'), r'$1');
    text = text.replaceAll(RegExp(r'([,.:?!])\1+'), r'$1');

    return text.trim();
  }
}
