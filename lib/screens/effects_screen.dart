import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/led_provider.dart';
import '../models/led_state.dart';
import '../theme/app_theme.dart';

class EffectsScreen extends StatelessWidget {
  const EffectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final led = context.watch<LedProvider>();
    final state = led.ledState;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hiệu Ứng LED',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Chọn hiệu ứng ánh sáng cho dải LED',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),

            // Current effect info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentPurple.withOpacity(0.15),
                    AppTheme.accentBlue.withOpacity(0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.accentPurple.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Icon(Icons.auto_awesome, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hiệu ứng hiện tại',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${state.effect.icon} ${state.effect.displayName}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Speed slider
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.speed_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Tốc độ hiệu ứng',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${state.effectSpeed}ms',
                          style: const TextStyle(
                            color: AppTheme.accentPurple,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Giá trị nhỏ = nhanh hơn',
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: AppTheme.accentPurple,
                      inactiveTrackColor:
                          AppTheme.accentPurple.withOpacity(0.15),
                      thumbColor: Colors.white,
                      overlayColor: AppTheme.accentPurple.withOpacity(0.15),
                      trackHeight: 6,
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
                      Text('Nhanh', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                      Text('Chậm', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Effect grid
            Text(
              'Chọn hiệu ứng',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
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
                childAspectRatio: 1.3,
              ),
              itemCount: LedEffect.values.length,
              itemBuilder: (context, index) {
                final effect = LedEffect.values[index];
                final isSelected = state.effect == effect;
                return _EffectCard(
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

class _EffectCard extends StatelessWidget {
  final LedEffect effect;
  final bool isSelected;
  final VoidCallback onTap;

  const _EffectCard({
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
        return const Color(0xFFFF69B4);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? _cardColor.withOpacity(0.15)
              : AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _cardColor : AppTheme.borderDark,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _cardColor.withOpacity(0.2),
                    blurRadius: 12,
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  effect.icon,
                  style: const TextStyle(fontSize: 28),
                ),
                if (isSelected)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _cardColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
              ],
            ),
            Text(
              effect.displayName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isSelected ? _cardColor : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
