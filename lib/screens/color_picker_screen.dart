import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import '../providers/led_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_glass.dart';

class ColorPickerScreen extends StatefulWidget {
  const ColorPickerScreen({super.key});

  @override
  State<ColorPickerScreen> createState() => _ColorPickerScreenState();
}

class _ColorPickerScreenState extends State<ColorPickerScreen> {
  late Color _currentColor;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _currentColor = context.read<LedProvider>().ledState.color;
      _initialized = true;
    }
  }

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
              'Chọn Màu Sắc',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pha trộn màu sắc 16 triệu màu cho dải LED WS2812',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 22),

            // 3D Liquid Crystal Color Slab
            LiquidGlassCard(
              borderRadius: 24,
              tintColor: _currentColor,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.3, -0.4),
                        radius: 0.85,
                        colors: [
                          Colors.white.withValues(alpha: 0.8),
                          _currentColor,
                          _currentColor.withValues(alpha: 0.8),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _currentColor.withValues(alpha: 0.6),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Màu đang chọn',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'R: ${_currentColor.red}   G: ${_currentColor.green}   B: ${_currentColor.blue}',
                          style: const TextStyle(
                            fontSize: 16,
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

            // 3D Liquid Glass Color Wheel
            LiquidGlassCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(16),
              child: ColorPicker(
                pickerColor: _currentColor,
                onColorChanged: (color) {
                  setState(() => _currentColor = color);
                },
                enableAlpha: false,
                displayThumbColor: true,
                pickerAreaHeightPercent: 0.58,
                labelTypes: const [],
                pickerAreaBorderRadius: BorderRadius.circular(18),
              ),
            ),
            const SizedBox(height: 16),

            // RGB Fine-tuning Sliders in 3D Liquid Glass
            LiquidGlassCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _ColorSlider(
                    label: 'R',
                    value: _currentColor.red.toDouble(),
                    activeColor: const Color(0xFFFF2D55),
                    onChanged: (v) {
                      setState(() {
                        _currentColor = _currentColor.withRed(v.toInt());
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _ColorSlider(
                    label: 'G',
                    value: _currentColor.green.toDouble(),
                    activeColor: const Color(0xFF00F5D4),
                    onChanged: (v) {
                      setState(() {
                        _currentColor = _currentColor.withGreen(v.toInt());
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _ColorSlider(
                    label: 'B',
                    value: _currentColor.blue.toDouble(),
                    activeColor: const Color(0xFF38BDF8),
                    onChanged: (v) {
                      setState(() {
                        _currentColor = _currentColor.withBlue(v.toInt());
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 3D Tactile Apply Button
            LiquidGlassButton(
              isPrimary: true,
              glowColor: _currentColor,
              borderRadius: 18,
              padding: const EdgeInsets.symmetric(vertical: 16),
              onPressed: () {
                led.setColor(_currentColor);
                if (!state.isOn) led.togglePower(true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('✨ Đã áp dụng màu sắc lên dải LED!'),
                    backgroundColor: AppTheme.accentGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Áp Dụng Màu Lên Đèn',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Saved colors
            const Text(
              'Bảng Màu Phổ Biến',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildPresetGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetGrid() {
    final presets = [
      {'name': 'Hoàng hôn', 'color': const Color(0xFFFF5E36)},
      {'name': 'Lavender', 'color': const Color(0xFFA855F7)},
      {'name': 'Biển sâu', 'color': const Color(0xFF0077B6)},
      {'name': 'Rừng ngọc', 'color': const Color(0xFF10B981)},
      {'name': 'Cherry', 'color': const Color(0xFFFF007A)},
      {'name': 'Vàng nắng', 'color': const Color(0xFFFFB703)},
      {'name': 'Cyber Teal', 'color': const Color(0xFF00F5D4)},
      {'name': 'San hô', 'color': const Color(0xFFFF6B6B)},
      {'name': 'Đọc sách', 'color': const Color(0xFFFFE0B2)},
      {'name': 'Thư giãn', 'color': const Color(0xFF8B5CF6)},
      {'name': 'Năng lượng', 'color': const Color(0xFF06D6A0)},
      {'name': 'Lãng mạn', 'color': const Color(0xFFF43F5E)},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 14,
        crossAxisSpacing: 12,
        childAspectRatio: 0.88,
      ),
      itemCount: presets.length,
      itemBuilder: (context, index) {
        final preset = presets[index];
        final color = preset['color'] as Color;
        return GestureDetector(
          onTap: () {
            setState(() => _currentColor = color);
            context.read<LedProvider>().setColor(color);
          },
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.35, -0.45),
                    radius: 0.85,
                    colors: [
                      Colors.white.withValues(alpha: 0.75),
                      color,
                      color.withValues(alpha: 0.85),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Text(
                preset['name'] as String,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ColorSlider extends StatelessWidget {
  final String label;
  final double value;
  final Color activeColor;
  final ValueChanged<double> onChanged;

  const _ColorSlider({
    required this.label,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          child: Text(
            label,
            style: TextStyle(
              color: activeColor,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: activeColor,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.10),
              thumbColor: Colors.white,
              overlayColor: activeColor.withValues(alpha: 0.20),
              trackHeight: 5,
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 255,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            value.toInt().toString(),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
