import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  double _kelvin = 4000;

  int get _r => (_currentColor.r * 255.0).round().clamp(0, 255);
  int get _g => (_currentColor.g * 255.0).round().clamp(0, 255);
  int get _b => (_currentColor.b * 255.0).round().clamp(0, 255);

  String get _hexCode {
    return '#${_r.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${_g.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${_b.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }

  // Convert Kelvin (2000 - 8000K) to natural white light RGB
  Color _kelvinToRgb(double kelvin) {
    final temp = kelvin / 100.0;
    double red, green, blue;

    if (temp <= 66) {
      red = 255;
    } else {
      red = temp - 60;
      red = 329.698727446 * (pow(red, -0.1332047592));
      red = red.clamp(0, 255);
    }

    if (temp <= 66) {
      green = temp;
      green = 99.4708025861 * log(green) - 161.1195681661;
      green = green.clamp(0, 255);
    } else {
      green = temp - 60;
      green = 288.1221695283 * (pow(green, -0.0755148492));
      green = green.clamp(0, 255);
    }

    if (temp >= 66) {
      blue = 255;
    } else if (temp <= 19) {
      blue = 0;
    } else {
      blue = temp - 10;
      blue = 138.5177312231 * log(blue) - 305.0447927307;
      blue = blue.clamp(0, 255);
    }

    return Color.fromARGB(255, red.round(), green.round(), blue.round());
  }

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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Màu đang chọn',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: _hexCode));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('📋 Đã sao chép mã màu: $_hexCode'),
                                    backgroundColor: AppTheme.accentCyan,
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _hexCode,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.accentCyan,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.copy_rounded, size: 12, color: AppTheme.accentCyan),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'R: $_r   G: $_g   B: $_b',
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

            // Kelvin Color Temperature Card (2200K - 6500K)
            LiquidGlassCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.wb_incandescent_rounded,
                              size: 18, color: AppTheme.accentOrange),
                          SizedBox(width: 8),
                          Text(
                            'Nhiệt Độ Màu Tự Nhiên (Kelvin)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${_kelvin.round()}K',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accentOrange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: const Color(0xFFFFB464),
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                      thumbColor: Colors.white,
                      overlayColor: const Color(0xFFFFB464).withValues(alpha: 0.2),
                      trackHeight: 6,
                    ),
                    child: Slider(
                      value: _kelvin,
                      min: 2200,
                      max: 6500,
                      onChanged: (v) {
                        setState(() {
                          _kelvin = v;
                          _currentColor = _kelvinToRgb(v);
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildKelvinChip('🕯️ 2200K', 2200),
                      _buildKelvinChip('🌅 2700K', 2700),
                      _buildKelvinChip('☀️ 4000K', 4000),
                      _buildKelvinChip('💡 6500K', 6500),
                    ],
                  ),
                ],
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
                    value: _r.toDouble(),
                    activeColor: const Color(0xFFFF2D55),
                    onChanged: (v) {
                      setState(() {
                        _currentColor = Color.fromARGB(255, v.toInt(), _g, _b);
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _ColorSlider(
                    label: 'G',
                    value: _g.toDouble(),
                    activeColor: const Color(0xFF00F5D4),
                    onChanged: (v) {
                      setState(() {
                        _currentColor = Color.fromARGB(255, _r, v.toInt(), _b);
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _ColorSlider(
                    label: 'B',
                    value: _b.toDouble(),
                    activeColor: const Color(0xFF38BDF8),
                    onChanged: (v) {
                      setState(() {
                        _currentColor = Color.fromARGB(255, _r, _g, v.toInt());
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

  Widget _buildKelvinChip(String label, double kelvinVal) {
    final isSelected = (_kelvin - kelvinVal).abs() < 100;
    return GestureDetector(
      onTap: () {
        setState(() {
          _kelvin = kelvinVal;
          _currentColor = _kelvinToRgb(kelvinVal);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFB464).withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFFB464)
                : Colors.white.withValues(alpha: 0.14),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? const Color(0xFFFFB464) : AppTheme.textSecondary,
          ),
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
