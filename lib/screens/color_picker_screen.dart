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
  int _selectedTab = 0; // 0: Vòng Màu, 1: Kelvin, 2: Kênh RGB, 3: Bộ Sưu Tập
  bool _wheelMode = true; // true: Bánh xe tròn, false: Bảng vuông HSV
  bool _liveSync = true; // Đồng bộ tức thì lên đèn
  double _kelvin = 4000;

  int get _r => (_currentColor.r * 255.0).round().clamp(0, 255);
  int get _g => (_currentColor.g * 255.0).round().clamp(0, 255);
  int get _b => (_currentColor.b * 255.0).round().clamp(0, 255);

  String get _hexCode {
    return '#${_r.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${_g.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${_b.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }

  String _getColorName(Color color) {
    final hsv = HSVColor.fromColor(color);
    if (hsv.saturation < 0.12) {
      if (hsv.value > 0.85) return 'Trắng Tinh Khiết';
      if (hsv.value > 0.35) return 'Bạc Ánh Kim';
      return 'Đen Ánh Tối';
    }
    final hue = hsv.hue;
    if (hue < 15 || hue >= 345) return 'Đỏ Ruby Neon';
    if (hue < 45) return 'Cam San Hô';
    if (hue < 70) return 'Vàng Nắng Hổ Phách';
    if (hue < 150) return 'Xanh Lục Emerald';
    if (hue < 195) return 'Xanh Cyan Điện Quang';
    if (hue < 255) return 'Xanh Lam Cyber';
    if (hue < 290) return 'Tím Lavender Hoàng Gia';
    if (hue < 330) return 'Hồng Neon Sôi Động';
    return 'Đỏ Hồng Cherry';
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

  void _onColorChanged(Color color) {
    setState(() => _currentColor = color);
    if (_liveSync) {
      final led = context.read<LedProvider>();
      led.setColor(color);
      if (!led.ledState.isOn) {
        led.togglePower(true);
      }
    }
  }

  void _applyCurrentColor() {
    final led = context.read<LedProvider>();
    led.setColor(_currentColor);
    if (!led.ledState.isOn) {
      led.togglePower(true);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✨ Đã áp dụng ${_getColorName(_currentColor)} ($_hexCode) lên dải LED!'),
        backgroundColor: AppTheme.accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth > 720;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            _buildTopBar(),
            const SizedBox(height: 16),

            if (isTablet)
              // Tablet / iPad Two-Column Studio Layout
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Studio Column: Tabs + Interactive Area
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        _buildTabSelector(),
                        const SizedBox(height: 14),
                        _buildActiveTabContent(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  // Right Studio Column: Color Hero + Strip Preview + Actions
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        _buildHeroPreviewCard(),
                        const SizedBox(height: 14),
                        _buildQuickPaletteCard(),
                      ],
                    ),
                  ),
                ],
              )
            else
              // Phone Unified Vertical Flow (Tight & Compact)
              Column(
                children: [
                  _buildHeroPreviewCard(),
                  const SizedBox(height: 14),
                  _buildTabSelector(),
                  const SizedBox(height: 14),
                  _buildActiveTabContent(),
                  const SizedBox(height: 14),
                  _buildQuickPaletteCard(),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // Top header with Live Sync Toggle
  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Studio Màu Sắc',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Không gian 16.7 triệu màu • WS2812B Engine',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Live Sync Pill
        GestureDetector(
          onTap: () {
            setState(() => _liveSync = !_liveSync);
            if (_liveSync) {
              context.read<LedProvider>().setColor(_currentColor);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _liveSync
                  ? AppTheme.accentGreen.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _liveSync
                    ? AppTheme.accentGreen.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.15),
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
                    color: _liveSync ? AppTheme.accentGreen : AppTheme.textSecondary,
                    boxShadow: _liveSync
                        ? [
                            BoxShadow(
                              color: AppTheme.accentGreen.withValues(alpha: 0.8),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _liveSync ? 'Live Sync: BẬT' : 'Live Sync: TẮT',
                  style: TextStyle(
                    color: _liveSync ? AppTheme.accentGreen : AppTheme.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Unified Hero 3D Color Preview Slab
  Widget _buildHeroPreviewCard() {
    return LiquidGlassCard(
      borderRadius: 22,
      tintColor: _currentColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              // 3D Gemstone Sphere
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.35, -0.45),
                    radius: 0.85,
                    colors: [
                      Colors.white.withValues(alpha: 0.85),
                      _currentColor,
                      _currentColor.withValues(alpha: 0.8),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 1.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _currentColor.withValues(alpha: 0.65),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Info Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _getColorName(_currentColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Copy Hex Pill
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
                                const Icon(Icons.copy_rounded, size: 11, color: AppTheme.accentCyan),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // RGB Badges
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildRgbPill('R', _r, const Color(0xFFFF2D55)),
                        _buildRgbPill('G', _g, const Color(0xFF00F5D4)),
                        _buildRgbPill('B', _b, const Color(0xFF38BDF8)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Mini 8-dot WS2812 Visualizer
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF080D1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(8, (i) {
                return Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentColor,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _currentColor.withValues(alpha: 0.7),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),

          // Direct Apply Button
          LiquidGlassButton(
            isPrimary: true,
            glowColor: _currentColor,
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(vertical: 12),
            onPressed: _applyCurrentColor,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Áp Dụng Lên Đèn Ngay',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRgbPill(String label, int val, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label: $val',
        style: TextStyle(
          color: c,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  // Segmented Studio Navigation Tab Capsule
  Widget _buildTabSelector() {
    final tabs = [
      {'label': 'Vòng Màu', 'icon': Icons.palette_rounded},
      {'label': 'Kelvin Trắng', 'icon': Icons.wb_incandescent_rounded},
      {'label': 'Kênh RGB', 'icon': Icons.tune_rounded},
      {'label': 'Bộ Sưu Tập', 'icon': Icons.grid_view_rounded},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final idx = entry.key;
          final tab = entry.value;
          final isSelected = _selectedTab == idx;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.accentCyan.withValues(alpha: 0.25)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(
                          color: AppTheme.accentCyan.withValues(alpha: 0.5),
                          width: 1.1,
                        )
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tab['icon'] as IconData,
                      size: 14,
                      color: isSelected ? AppTheme.accentCyan : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        tab['label'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Active Tab Content
  Widget _buildActiveTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildColorWheelTab();
      case 1:
        return _buildKelvinTab();
      case 2:
        return _buildRgbFineTuneTab();
      case 3:
        return _buildThemedPalettesTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // TAB 0: Color Wheel & HSV Disc
  Widget _buildColorWheelTab() {
    return LiquidGlassCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Bánh Xe Màu Trực Quan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Wheel vs Square Mode Switch
              GestureDetector(
                onTap: () => setState(() => _wheelMode = !_wheelMode),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _wheelMode ? Icons.circle_outlined : Icons.crop_square_rounded,
                        size: 13,
                        color: AppTheme.accentCyan,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _wheelMode ? 'Bánh xe' : 'Bảng vuông',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentCyan,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Color Picker Container (Constrained & perfectly centered)
          LayoutBuilder(
            builder: (context, constraints) {
              final pickerWidth =
                  (constraints.maxWidth - 16).clamp(170.0, 230.0);
              return Center(
                child: ColorPicker(
                  pickerColor: _currentColor,
                  onColorChanged: _onColorChanged,
                  enableAlpha: false,
                  displayThumbColor: true,
                  paletteType: _wheelMode
                      ? PaletteType.hueWheel
                      : PaletteType.hsvWithHue,
                  colorPickerWidth: pickerWidth,
                  pickerAreaHeightPercent: _wheelMode ? 0.88 : 0.65,
                  portraitOnly: true,
                  labelTypes: const [],
                  pickerAreaBorderRadius: BorderRadius.circular(18),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // TAB 1: Natural Kelvin White Spectrum
  Widget _buildKelvinTab() {
    final kelvinPresets = [
      {'label': 'Nến vàng', 'desc': 'Ấm cúng & Ngủ ngon', 'k': 2200.0, 'icon': Icons.nightlight_rounded},
      {'label': 'Hoàng hôn', 'desc': 'Chill & Xem phim', 'k': 2700.0, 'icon': Icons.wb_twilight_rounded},
      {'label': 'Vàng ấm', 'desc': 'Thư giãn phòng khách', 'k': 3200.0, 'icon': Icons.coffee_rounded},
      {'label': 'Trung tính', 'desc': 'Học bài & Làm việc', 'k': 4000.0, 'icon': Icons.menu_book_rounded},
      {'label': 'Trắng ban ngày', 'desc': 'Sáng rõ & Tỉnh táo', 'k': 6500.0, 'icon': Icons.wb_sunny_rounded},
    ];

    return LiquidGlassCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.wb_incandescent_rounded, size: 18, color: AppTheme.accentOrange),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Nhiệt Độ Màu Trắng (Kelvin)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.35)),
                ),
                child: Text(
                  '${_kelvin.round()}K',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accentOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Realtime Natural Kelvin Gradient Bar
          Container(
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF8500), // 2000K
                  Color(0xFFFFB464), // 2700K
                  Color(0xFFFFD166), // 3500K
                  Color(0xFFFFFFFF), // 5000K
                  Color(0xFFB4D8FF), // 6500K
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
          ),
          const SizedBox(height: 6),

          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFFFFB464),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
              thumbColor: Colors.white,
              overlayColor: const Color(0xFFFFB464).withValues(alpha: 0.2),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9, elevation: 4),
            ),
            child: Slider(
              value: _kelvin,
              min: 2000,
              max: 6500,
              divisions: 45,
              onChanged: (v) {
                setState(() => _kelvin = v);
                _onColorChanged(_kelvinToRgb(v));
              },
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('2000K (Nến ấm)', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
              Text('6500K (Trắng mát)', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 16),

          // Curated Kelvin Scene List
          Column(
            children: kelvinPresets.map((preset) {
              final kVal = preset['k'] as double;
              final isSel = (_kelvin - kVal).abs() < 150;
              final previewColor = _kelvinToRgb(kVal);

              return GestureDetector(
                onTap: () {
                  setState(() => _kelvin = kVal);
                  _onColorChanged(previewColor);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSel
                        ? previewColor.withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSel ? previewColor : Colors.white.withValues(alpha: 0.12),
                      width: isSel ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: previewColor,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                          boxShadow: [
                            BoxShadow(
                              color: previewColor.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Icon(
                          preset['icon'] as IconData,
                          size: 16,
                          color: kVal < 4500 ? const Color(0xFF1E293B) : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              preset['label'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: isSel ? Colors.white : AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              preset['desc'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isSel ? previewColor : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${kVal.round()}K',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isSel ? previewColor : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // TAB 2: Precision RGB Fine-tune Sliders
  Widget _buildRgbFineTuneTab() {
    return LiquidGlassCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Kênh Màu Độc Lập (0 - 255)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Phối màu cộng RGB',
                style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildRgbSliderRow(
            label: 'Red',
            value: _r.toDouble(),
            color: const Color(0xFFFF2D55),
            onChanged: (v) => _onColorChanged(Color.fromARGB(255, v.toInt(), _g, _b)),
          ),
          const SizedBox(height: 12),

          _buildRgbSliderRow(
            label: 'Green',
            value: _g.toDouble(),
            color: const Color(0xFF00F5D4),
            onChanged: (v) => _onColorChanged(Color.fromARGB(255, _r, v.toInt(), _b)),
          ),
          const SizedBox(height: 12),

          _buildRgbSliderRow(
            label: 'Blue',
            value: _b.toDouble(),
            color: const Color(0xFF38BDF8),
            onChanged: (v) => _onColorChanged(Color.fromARGB(255, _r, _g, v.toInt())),
          ),
          const SizedBox(height: 16),

          // Additive Color Mixing Spectrum
          Container(
            height: 14,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              gradient: LinearGradient(
                colors: [
                  Color.fromARGB(255, _r, 0, 0),
                  Color.fromARGB(255, _r, _g, 0),
                  Color.fromARGB(255, 0, _g, 0),
                  Color.fromARGB(255, 0, _g, _b),
                  Color.fromARGB(255, 0, 0, _b),
                  Color.fromARGB(255, _r, 0, _b),
                  _currentColor,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRgbSliderRow({
    required String label,
    required double value,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Text(
            label[0],
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
              thumbColor: Colors.white,
              overlayColor: color.withValues(alpha: 0.2),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8, elevation: 3),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 255,
              divisions: 255,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 38,
          child: Text(
            value.toInt().toString(),
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // TAB 3: Curated Aesthetic Palettes
  Widget _buildThemedPalettesTab() {
    final categories = [
      {
        'title': '⚡ Cyberpunk & Neon',
        'colors': [
          {'name': 'Cyan Neon', 'color': const Color(0xFF00F5D4)},
          {'name': 'Laser Purple', 'color': const Color(0xFFA855F7)},
          {'name': 'Hot Pink', 'color': const Color(0xFFFF007A)},
          {'name': 'Acid Lime', 'color': const Color(0xFF10B981)},
          {'name': 'Cyber Blue', 'color': const Color(0xFF00F2FE)},
        ],
      },
      {
        'title': '☕ Ấm Áp & Thư Giãn',
        'colors': [
          {'name': 'Hổ Phách', 'color': const Color(0xFFFF8500)},
          {'name': 'Nắng Thu', 'color': const Color(0xFFFFB703)},
          {'name': 'San Hô', 'color': const Color(0xFFFF6B6B)},
          {'name': 'Latte Nâu', 'color': const Color(0xFFFFD166)},
          {'name': 'Rose Quartz', 'color': const Color(0xFFF43F5E)},
        ],
      },
      {
        'title': '🌊 Thiên Nhiên & Yên Bình',
        'colors': [
          {'name': 'Biển Sâu', 'color': const Color(0xFF0077B6)},
          {'name': 'Rừng Ngọc', 'color': const Color(0xFF059669)},
          {'name': 'Bạc Hà', 'color': const Color(0xFF06D6A0)},
          {'name': 'Lavender', 'color': const Color(0xFF8B5CF6)},
          {'name': 'Sky Glow', 'color': const Color(0xFF38BDF8)},
        ],
      },
    ];

    return LiquidGlassCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: categories.map((cat) {
          final colors = cat['colors'] as List<Map<String, dynamic>>;

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat['title'] as String,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: colors.map((item) {
                    final color = item['color'] as Color;
                    final isSel = _currentColor.toARGB32() == color.toARGB32();

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _onColorChanged(color),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  center: const Alignment(-0.35, -0.45),
                                  radius: 0.85,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.8),
                                    color,
                                    color.withValues(alpha: 0.85),
                                  ],
                                ),
                                border: Border.all(
                                  color: isSel ? Colors.white : Colors.white.withValues(alpha: 0.35),
                                  width: isSel ? 2.5 : 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: isSel ? 0.75 : 0.4),
                                    blurRadius: isSel ? 12 : 8,
                                    spreadRadius: isSel ? 1.5 : 0,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Text(
                                item['name'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                                  color: isSel ? AppTheme.accentCyan : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // Quick Curated Presets Bar (Always Accessible)
  Widget _buildQuickPaletteCard() {
    final quickColors = [
      {'name': 'Đỏ Ruby', 'color': const Color(0xFFFF2D55)},
      {'name': 'Cam Hổ Phách', 'color': const Color(0xFFFF8500)},
      {'name': 'Vàng Nắng', 'color': const Color(0xFFFFB703)},
      {'name': 'Emerald', 'color': const Color(0xFF10B981)},
      {'name': 'Cyan Neon', 'color': const Color(0xFF00F5D4)},
      {'name': 'Biển Sâu', 'color': const Color(0xFF0077B6)},
      {'name': 'Laser Tím', 'color': const Color(0xFFA855F7)},
      {'name': 'Trắng 5000K', 'color': Colors.white},
    ];

    final isWide = MediaQuery.sizeOf(context).width > 520;

    return LiquidGlassCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Màu Chọn Nhanh Phổ Biến',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Text(
                '1 Chạm',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentCyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isWide ? 4 : 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: isWide ? 2.1 : 2.9,
            ),
            itemCount: quickColors.length,
            itemBuilder: (context, index) {
              final item = quickColors[index];
              final color = item['color'] as Color;
              final isSel = _currentColor.toARGB32() == color.toARGB32();

              return GestureDetector(
                onTap: () => _onColorChanged(color),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSel ? Colors.white : color.withValues(alpha: 0.45),
                      width: isSel ? 1.8 : 1,
                    ),
                    boxShadow: isSel
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item['name'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                            color: isSel ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
