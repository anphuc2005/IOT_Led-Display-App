import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import '../providers/led_provider.dart';
import '../theme/app_theme.dart';

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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chọn Màu Sắc',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Chọn màu cho dải LED WS2812',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),

            // Color preview
            Container(
              width: double.infinity,
              height: 80,
              decoration: BoxDecoration(
                color: _currentColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _currentColor.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'R:${_currentColor.red}  G:${_currentColor.green}  B:${_currentColor.blue}',
                  style: TextStyle(
                    color: _currentColor.computeLuminance() > 0.5
                        ? Colors.black87
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Color wheel
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderDark),
              ),
              child: ColorPicker(
                pickerColor: _currentColor,
                onColorChanged: (color) {
                  setState(() => _currentColor = color);
                },
                enableAlpha: false,
                displayThumbColor: true,
                pickerAreaHeightPercent: 0.6,
                labelTypes: const [],
                pickerAreaBorderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 16),

            // RGB sliders
            _buildRGBSliders(),

            const SizedBox(height: 20),

            // Apply button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  led.setColor(_currentColor);
                  if (!state.isOn) led.togglePower(true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Đã áp dụng màu!'),
                      backgroundColor: AppTheme.accentGreen,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentColor,
                  foregroundColor: _currentColor.computeLuminance() > 0.5
                      ? Colors.black87
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Áp dụng màu',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Saved colors
            Text(
              'Bảng màu nhanh',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            _buildPresetGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildRGBSliders() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        children: [
          _ColorSlider(
            label: 'R',
            value: _currentColor.red.toDouble(),
            activeColor: Colors.red,
            onChanged: (v) {
              setState(() {
                _currentColor = _currentColor.withRed(v.toInt());
              });
            },
          ),
          const SizedBox(height: 8),
          _ColorSlider(
            label: 'G',
            value: _currentColor.green.toDouble(),
            activeColor: Colors.green,
            onChanged: (v) {
              setState(() {
                _currentColor = _currentColor.withGreen(v.toInt());
              });
            },
          ),
          const SizedBox(height: 8),
          _ColorSlider(
            label: 'B',
            value: _currentColor.blue.toDouble(),
            activeColor: Colors.blue,
            onChanged: (v) {
              setState(() {
                _currentColor = _currentColor.withBlue(v.toInt());
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPresetGrid() {
    final presets = [
      {'name': 'Hoàng hôn', 'color': const Color(0xFFFF6B35)},
      {'name': 'Lavender', 'color': const Color(0xFFE6E6FA)},
      {'name': 'Biển đêm', 'color': const Color(0xFF006994)},
      {'name': 'Rừng', 'color': const Color(0xFF228B22)},
      {'name': 'Cherry', 'color': const Color(0xFFDE3163)},
      {'name': 'Vàng ấm', 'color': const Color(0xFFFFD700)},
      {'name': 'Teal', 'color': const Color(0xFF008080)},
      {'name': 'Coral', 'color': const Color(0xFFFF7F50)},
      {'name': 'Đọc sách', 'color': const Color(0xFFFFE4B5)},
      {'name': 'Thư giãn', 'color': const Color(0xFF9370DB)},
      {'name': 'Năng lượng', 'color': const Color(0xFF00FF7F)},
      {'name': 'Lãng mạn', 'color': const Color(0xFFFF69B4)},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
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
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 2,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                preset['name'] as String,
                style: const TextStyle(
                  fontSize: 10,
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
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: activeColor,
              inactiveTrackColor: activeColor.withOpacity(0.15),
              thumbColor: activeColor,
              overlayColor: activeColor.withOpacity(0.15),
              trackHeight: 4,
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
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
