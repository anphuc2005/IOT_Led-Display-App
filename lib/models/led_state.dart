import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum LedEffect {
  none,
  blink,
  fade,
  rainbow,
  breathing,
  strobe,
  colorWipe,
  chase
}

extension LedEffectX on LedEffect {
  String get displayName => switch (this) {
        LedEffect.none => 'Không hiệu ứng',
        LedEffect.blink => 'Nhấp nháy',
        LedEffect.fade => 'Mờ dần',
        LedEffect.rainbow => 'Cầu vồng',
        LedEffect.breathing => 'Nhịp thở',
        LedEffect.strobe => 'Chớp nhanh',
        LedEffect.colorWipe => 'Quét màu',
        LedEffect.chase => 'Đuổi sáng',
      };

  String get description => switch (this) {
        LedEffect.none => 'Giữ một màu ổn định',
        LedEffect.blink => 'Bật và tắt theo nhịp',
        LedEffect.fade => 'Chuyển sáng tối mượt mà',
        LedEffect.rainbow => 'Dải màu chuyển động liên tục',
        LedEffect.breathing => 'Ánh sáng lên xuống như nhịp thở',
        LedEffect.strobe => 'Chớp trắng cường độ cao',
        LedEffect.colorWipe => 'Màu chạy lần lượt qua dải LED',
        LedEffect.chase => 'Điểm sáng đuổi nhau trên dải LED',
      };

  IconData get icon => switch (this) {
        LedEffect.none => Icons.horizontal_rule_rounded,
        LedEffect.blink => Icons.flash_on_rounded,
        LedEffect.fade => Icons.gradient_rounded,
        LedEffect.rainbow => Icons.looks_rounded,
        LedEffect.breathing => Icons.air_rounded,
        LedEffect.strobe => Icons.bolt_rounded,
        LedEffect.colorWipe => Icons.format_color_fill_rounded,
        LedEffect.chase => Icons.moving_rounded,
      };

  String get mqttValue => switch (this) {
        LedEffect.none => 'none',
        LedEffect.blink => 'blink',
        LedEffect.fade => 'fade',
        LedEffect.rainbow => 'rainbow',
        LedEffect.breathing => 'breathing',
        LedEffect.strobe => 'strobe',
        LedEffect.colorWipe => 'color_wipe',
        LedEffect.chase => 'chase',
      };
}

class LedState extends Equatable {
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

  LedState copyWith(
          {bool? isOn,
          Color? color,
          int? brightness,
          LedEffect? effect,
          int? effectSpeed,
          int? numLeds}) =>
      LedState(
        isOn: isOn ?? this.isOn,
        color: color ?? this.color,
        brightness: brightness ?? this.brightness,
        effect: effect ?? this.effect,
        effectSpeed: effectSpeed ?? this.effectSpeed,
        numLeds: numLeds ?? this.numLeds,
      );

  Map<String, dynamic> toColorJson() {
    final argb = color.toARGB32();
    return {
      'r': (argb >> 16) & 0xFF,
      'g': (argb >> 8) & 0xFF,
      'b': argb & 0xFF
    };
  }

  Map<String, dynamic> toEffectJson() =>
      {'type': effect.mqttValue, 'speed': effectSpeed};

  @override
  List<Object> get props =>
      [isOn, color, brightness, effect, effectSpeed, numLeds];
}
