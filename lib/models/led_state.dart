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
    this.numLeds = 30,
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
        'r': color.red,
        'g': color.green,
        'b': color.blue,
      };

  Map<String, dynamic> toEffectJson() => {
        'type': effect.mqttValue,
        'speed': effectSpeed,
      };
}
