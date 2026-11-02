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

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
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
              'Chọn các hiệu ứng ánh sáng động cho dải LED WS2812',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 22),

            // Current effect info (3D Liquid Glass Card)
            LiquidGlassCard(
              borderRadius: 24,
              tintColor: AppTheme.accentPurple,
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: AppTheme.purpleGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentPurple.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.auto_awesome, color: Colors.white, size: 26),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hiệu ứng đang hoạt động',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${state.effect.icon} ${state.effect.displayName}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Speed slider (3D Liquid Glass Card)
            LiquidGlassCard(
              borderRadius: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.speed_rounded,
                            size: 20,
                            color: AppTheme.accentPurple,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Tốc Độ Hiệu Ứng',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentPurple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.accentPurple.withValues(alpha: 0.35),
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
                  const SizedBox(height: 6),
                  const Text(
                    'Thời gian chu kỳ (giá trị nhỏ = tốc độ nhanh)',
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: AppTheme.accentPurple,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                      thumbColor: Colors.white,
                      overlayColor: AppTheme.accentPurple.withValues(alpha: 0.2),
                      trackHeight: 7,
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
                        '⚡ Cực nhanh (50ms)',
                        style: TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Thư thái (3000ms) 🌙',
                        style: TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Effect grid
            const Text(
              'Danh Sách Hiệu Ứng',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
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

class _LiquidEffectCard extends StatelessWidget {
  final LedEffect effect;
  final bool isSelected;
  final VoidCallback onTap;

  const _LiquidEffectCard({
    required this.effect,
    required this.isSelected,
    required this.onTap,
  });

  Color get _cardColor {
    switch (effect) {
      case LedEffect.none:
        return AppTheme.textSecondary;
      case LedEffect.blink:
        return AppTheme.accentOrange;
      case LedEffect.fade:
        return AppTheme.accentBlue;
      case LedEffect.rainbow:
        return AppTheme.accentPurple;
      case LedEffect.breathing:
        return AppTheme.accentCyan;
      case LedEffect.strobe:
        return AppTheme.accentRed;
      case LedEffect.colorWipe:
        return AppTheme.accentGreen;
      case LedEffect.chase:
        return AppTheme.accentPink;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      tintColor: isSelected ? _cardColor : null,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                effect.icon,
                style: const TextStyle(fontSize: 26),
              ),
              if (isSelected)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _cardColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _cardColor.withValues(alpha: 0.8),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                effect.displayName,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                effect.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
