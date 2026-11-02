import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/led_provider.dart';
import '../models/led_state.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_glass.dart';

class EffectsScreen extends StatelessWidget {
  const EffectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final led = context.watch<LedProvider>();
    final state = led.ledState;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth > 600;
    final crossAxisCount = screenWidth > 950 ? 4 : (isTablet ? 3 : 2);
    final childAspectRatio = isTablet ? (screenWidth > 950 ? 1.4 : 1.35) : 1.28;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hiệu Ứng LED',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Kho hiệu ứng ánh sáng động cho dải LED WS2812',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: state.effect.themeColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: state.effect.themeColor.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: state.isOn
                              ? state.effect.themeColor
                              : AppTheme.textSecondary,
                          boxShadow: state.isOn
                              ? [
                                  BoxShadow(
                                    color: state.effect.themeColor.withValues(alpha: 0.8),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        state.isOn ? state.effect.displayName : 'Đang tắt',
                        style: TextStyle(
                          color: state.effect.themeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // WS2812 Realtime Strip Preview Simulator
            _Ws2812StripSimulator(
              effect: state.effect,
              baseColor: state.isOn ? state.color : Colors.black,
              speedMs: state.effectSpeed,
              isOn: state.isOn,
            ),
            const SizedBox(height: 18),

            // Speed Slider Card
            LiquidGlassCard(
              borderRadius: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.accentPurple.withValues(alpha: 0.18),
                              border: Border.all(
                                color: AppTheme.accentPurple.withValues(alpha: 0.35),
                              ),
                            ),
                            child: const Icon(
                              Icons.speed_rounded,
                              size: 18,
                              color: AppTheme.accentPurple,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tốc Độ Hiệu Ứng',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'Thời gian hoàn thành một chu kỳ',
                                style: TextStyle(
                                  color: AppTheme.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentPurple.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.accentPurple.withValues(alpha: 0.40),
                          ),
                        ),
                        child: Text(
                          '${state.effectSpeed} ms',
                          style: const TextStyle(
                            color: AppTheme.accentPurple,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: AppTheme.accentPurple,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                      thumbColor: Colors.white,
                      overlayColor: AppTheme.accentPurple.withValues(alpha: 0.2),
                      trackHeight: 6,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 9,
                        elevation: 4,
                      ),
                    ),
                    child: Slider(
                      value: state.effectSpeed.toDouble(),
                      min: 50,
                      max: 3000,
                      divisions: 59,
                      onChanged: (v) => led.setEffectSpeed(v.toInt()),
                    ),
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '⚡ 50ms (Cực nhanh)',
                        style: TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '3000ms (Thư thái) 🌙',
                        style: TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Preset speed pills
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [100, 300, 500, 1000, 2000].map((ms) {
                      final isSel = (state.effectSpeed - ms).abs() < 50;
                      return GestureDetector(
                        onTap: () => led.setEffectSpeed(ms),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSel
                                ? AppTheme.accentPurple.withValues(alpha: 0.28)
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSel
                                  ? AppTheme.accentPurple
                                  : Colors.white.withValues(alpha: 0.12),
                              width: isSel ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            '${ms}ms',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                              color: isSel ? AppTheme.accentPurple : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Effect Grid Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: AppTheme.accentCyan,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Danh Sách Hiệu Ứng',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${LedEffect.values.length} chế độ',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Effect Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: childAspectRatio,
              ),
              itemCount: LedEffect.values.length,
              itemBuilder: (context, index) {
                final effect = LedEffect.values[index];
                final isSelected = state.effect == effect;
                return _LiquidEffectCard(
                  effect: effect,
                  isSelected: isSelected,
                  onTap: () {
                    led.setEffect(effect);
                    if (!state.isOn && effect != LedEffect.none) {
                      led.togglePower(true);
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Dynamic WS2812 Strip Preview Simulator
class _Ws2812StripSimulator extends StatefulWidget {
  final LedEffect effect;
  final Color baseColor;
  final int speedMs;
  final bool isOn;

  const _Ws2812StripSimulator({
    required this.effect,
    required this.baseColor,
    required this.speedMs,
    required this.isOn,
  });

  @override
  State<_Ws2812StripSimulator> createState() => _Ws2812StripSimulatorState();
}

class _Ws2812StripSimulatorState extends State<_Ws2812StripSimulator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  static const int _pixelCount = 14;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.speedMs.clamp(200, 3000)),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant _Ws2812StripSimulator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speedMs != widget.speedMs) {
      _animController.duration =
          Duration(milliseconds: widget.speedMs.clamp(200, 3000));
      if (!_animController.isAnimating) {
        _animController.repeat();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color _getPixelColor(int index, double progress) {
    if (!widget.isOn) {
      return Colors.white.withValues(alpha: 0.04);
    }

    switch (widget.effect) {
      case LedEffect.none:
        return widget.baseColor;

      case LedEffect.rainbow:
        final hue = ((progress * 360) + (index * (360 / _pixelCount))) % 360;
        return HSVColor.fromAHSV(1.0, hue, 0.95, 1.0).toColor();

      case LedEffect.breathing:
        final factor = (math.sin(progress * 2 * math.pi) + 1) / 2;
        final alpha = 0.15 + (factor * 0.85);
        return widget.baseColor.withValues(alpha: alpha);

      case LedEffect.blink:
        final isOn = progress < 0.5;
        return isOn ? widget.baseColor : Colors.white.withValues(alpha: 0.08);

      case LedEffect.strobe:
        final subProgress = (progress * 8) % 1.0;
        return subProgress < 0.3
            ? Colors.white
            : widget.baseColor.withValues(alpha: 0.1);

      case LedEffect.colorWipe:
        final activeIndex = (progress * _pixelCount).floor() % _pixelCount;
        return index <= activeIndex
            ? widget.baseColor
            : Colors.white.withValues(alpha: 0.08);

      case LedEffect.chase:
        final head = (progress * _pixelCount).floor() % _pixelCount;
        final diff = (index - head + _pixelCount) % _pixelCount;
        if (diff == 0) {
          return Colors.white;
        } else if (diff == 1) {
          return widget.baseColor;
        } else if (diff == 2) {
          return widget.baseColor.withValues(alpha: 0.6);
        } else if (diff == 3) {
          return widget.baseColor.withValues(alpha: 0.3);
        }
        return Colors.white.withValues(alpha: 0.06);

      case LedEffect.fade:
        final factor = (math.sin(progress * 2 * math.pi) + 1) / 2;
        return Color.lerp(
          widget.baseColor.withValues(alpha: 0.2),
          widget.baseColor,
          factor,
        )!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      borderRadius: 24,
      tintColor: widget.effect.themeColor,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.effect.themeColor.withValues(alpha: 0.18),
                      border: Border.all(
                        color: widget.effect.themeColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Icon(
                      widget.effect.iconData,
                      size: 16,
                      color: widget.effect.themeColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Mô Phỏng WS2812 Live Strip',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentGreen,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentGreen.withValues(alpha: 0.8),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      '$_pixelCount Pixels • Realtime',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // PCB Strip Chassis
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF090D18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // PCB Copper Trace Line
                Positioned.fill(
                  child: Center(
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.05),
                            Colors.white.withValues(alpha: 0.18),
                            Colors.white.withValues(alpha: 0.05),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Animated Pixels
                AnimatedBuilder(
                  animation: _animController,
                  builder: (context, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_pixelCount, (i) {
                        final pixelColor = _getPixelColor(i, _animController.value);
                        final isBright = pixelColor.a > 0.3;

                        return Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: pixelColor,
                            border: Border.all(
                              color: Colors.white.withValues(
                                alpha: isBright ? 0.6 : 0.15,
                              ),
                              width: 1,
                            ),
                            boxShadow: isBright
                                ? [
                                    BoxShadow(
                                      color: pixelColor.withValues(alpha: 0.8),
                                      blurRadius: 10,
                                      spreadRadius: 1.5,
                                    ),
                                  ]
                                : null,
                          ),
                        );
                      }),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hiệu ứng: ${widget.effect.displayName}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: widget.effect.themeColor,
                ),
              ),
              Text(
                'Chu kỳ: ${widget.speedMs}ms • WS2812B 800kHz',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Standardized 3D Liquid Glass Effect Card
class _LiquidEffectCard extends StatelessWidget {
  final LedEffect effect;
  final bool isSelected;
  final VoidCallback onTap;

  const _LiquidEffectCard({
    required this.effect,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = effect.themeColor;

    return LiquidGlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(14),
      tintColor: isSelected ? themeColor : null,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Standardized 3D Glass Icon Squircle
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isSelected
                      ? themeColor.withValues(alpha: 0.28)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: isSelected
                        ? themeColor.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.18),
                    width: 1.1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: themeColor.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Icon(
                    effect.iconData,
                    color: isSelected ? Colors.white : themeColor,
                    size: 20,
                  ),
                ),
              ),
              // Active status pill
              if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: themeColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: themeColor,
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.withValues(alpha: 0.8),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Đang chạy',
                        style: TextStyle(
                          color: themeColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 11,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                effect.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                effect.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.85)
                      : AppTheme.textSecondary,
                  fontSize: 11,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
