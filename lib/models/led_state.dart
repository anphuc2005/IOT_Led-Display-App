import 'package:flutter/material.dart';

enum LedEffect {
  none,
  blink,
  fade,
  rainbow,
  breathing,
  strobe,
  colorWipe,
  chase,
}

extension LedEffectExt on LedEffect {
  String get displayName {
    switch (this) {
      case LedEffect.none:
        return 'Không hiệu ứng';
      case LedEffect.blink:
        return 'Nhấp nháy';
      case LedEffect.fade:
        return 'Fade In/Out';
      case LedEffect.rainbow:
        return 'Cầu vồng';
      case LedEffect.breathing:
        return 'Thở';
      case LedEffect.strobe:
        return 'Strobe';
      case LedEffect.colorWipe:
        return 'Color Wipe';
      case LedEffect.chase:
        return 'Chase';
    }
  }

  String get icon {
    switch (this) {
      case LedEffect.none:
        return '⏹️';
      case LedEffect.blink:
        return '💡';
      case LedEffect.fade:
        return '🌅';
      case LedEffect.rainbow:
        return '🌈';
      case LedEffect.breathing:
        return '🫁';
      case LedEffect.strobe:
        return '⚡';
      case LedEffect.colorWipe:
        return '🎨';
      case LedEffect.chase:
        return '🏃';
    }
  }

  String get mqttValue {
    switch (this) {
      case LedEffect.none:
        return 'none';
      case LedEffect.blink:
        return 'blink';
      case LedEffect.fade:
        return 'fade';
      case LedEffect.rainbow:
        return 'rainbow';
      case LedEffect.breathing:
        return 'breathing';
      case LedEffect.strobe:
        return 'strobe';
      case LedEffect.colorWipe:
        return 'color_wipe';
      case LedEffect.chase:
        return 'chase';
    }
  }

  String get description {
    switch (this) {
      case LedEffect.none:
        return 'Tắt hiệu ứng, giữ màu tĩnh';
      case LedEffect.blink:
        return 'Nhấp nháy bật tắt tuần hoàn';
      case LedEffect.fade:
        return 'Mờ dần và sáng dần êm dịu';
      case LedEffect.rainbow:
        return 'Chuyển dải 7 sắc cầu vồng sinh động';
      case LedEffect.breathing:
        return 'Hiệu ứng nhịp thở thư giãn';
      case LedEffect.strobe:
        return 'Chớp nháy nhanh sôi động';
      case LedEffect.colorWipe:
        return 'Quét màu lần lượt qua từng bóng';
      case LedEffect.chase:
        return 'Hiệu ứng đuổi màu chạy dọc dải';
    }
  }

  IconData get iconData {
    switch (this) {
      case LedEffect.none:
        return Icons.wb_incandescent_outlined;
      case LedEffect.blink:
        return Icons.flash_on_rounded;
      case LedEffect.fade:
        return Icons.blur_on_rounded;
      case LedEffect.rainbow:
        return Icons.palette_rounded;
      case LedEffect.breathing:
        return Icons.air_rounded;
      case LedEffect.strobe:
        return Icons.bolt_rounded;
      case LedEffect.colorWipe:
        return Icons.brush_rounded;
      case LedEffect.chase:
        return Icons.fast_forward_rounded;
    }
  }

  Color get themeColor {
    switch (this) {
      case LedEffect.none:
        return const Color(0xFF334155); // 10.4:1 AAA Slate
      case LedEffect.blink:
        return const Color(0xFF9A3412); // 7.52:1 AAA Deep Amber
      case LedEffect.fade:
        return const Color(0xFF1E40AF); // 8.72:1 AAA Royal Blue
      case LedEffect.rainbow:
        return const Color(0xFF5B21B6); // 8.94:1 AAA Deep Violet
      case LedEffect.breathing:
        return const Color(0xFF005A70); // 8.02:1 AAA Deep Teal
      case LedEffect.strobe:
        return const Color(0xFF9F1239); // 8.51:1 AAA Deep Crimson
      case LedEffect.colorWipe:
        return const Color(0xFF065F46); // 7.73:1 AAA Deep Emerald
      case LedEffect.chase:
        return const Color(0xFF9D174D); // 8.21:1 AAA Deep Magenta
    }
  }
}

class LedState {
  final bool isOn;
  final Color color;
  final int brightness;
  final LedEffect effect;
  final int effectSpeed;
  final int numLeds;

  const LedState({
    this.isOn = false,
    this.color = const Color(0xFFFFFFFF),
    this.brightness = 100,
    this.effect = LedEffect.none,
    this.effectSpeed = 500,
    this.numLeds = 8,
  });

  LedState copyWith({
    bool? isOn,
    Color? color,
    int? brightness,
    LedEffect? effect,
    int? effectSpeed,
    int? numLeds,
  }) {
    return LedState(
      isOn: isOn ?? this.isOn,
      color: color ?? this.color,
      brightness: brightness ?? this.brightness,
      effect: effect ?? this.effect,
      effectSpeed: effectSpeed ?? this.effectSpeed,
      numLeds: numLeds ?? this.numLeds,
    );
  }

  Map<String, dynamic> toColorJson() => {
        'r': (color.r * 255.0).round().clamp(0, 255),
        'g': (color.g * 255.0).round().clamp(0, 255),
        'b': (color.b * 255.0).round().clamp(0, 255),
      };

  Map<String, dynamic> toEffectJson() => {
        'type': effect.mqttValue,
        'speed': effectSpeed,
      };
}
