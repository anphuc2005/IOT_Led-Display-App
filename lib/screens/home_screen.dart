import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/led_provider.dart';
import '../services/mqtt_service.dart';
import '../theme/app_theme.dart';
import '../models/led_state.dart';
import '../widgets/liquid_glass.dart';
import 'color_picker_screen.dart';
import 'effects_screen.dart';
import 'ai_chat_screen.dart';
import 'sensor_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;

  void _onSelectTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _DashboardView(onSelectTab: _onSelectTab),
      const ColorPickerScreen(),
      const EffectsScreen(),
      const AiChatScreen(),
      const SensorScreen(),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: LiquidBackground(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: _LiquidFloatingNavBar(
        currentIndex: _currentIndex,
        onTap: _onSelectTab,
      ),
    );
  }
}

/// Floating Capsule Liquid Glass 3D Navigation Bar
class _LiquidFloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _LiquidFloatingNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 66,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0x38FFFFFF),
                    Color(0x10FFFFFF),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.28),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 28,
                    spreadRadius: -2,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navItem(0, Icons.dashboard_rounded, 'Trang chủ'),
                  _navItem(1, Icons.palette_rounded, 'Màu sắc'),
                  _navItem(2, Icons.auto_awesome_rounded, 'Hiệu ứng'),
                  _navItem(3, Icons.smart_toy_rounded, 'AI Voice'),
                  _navItem(4, Icons.sensors_rounded, 'Cảm biến'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 14 : 10,
          vertical: 8,
        ),
        decoration: isSelected
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentCyan.withValues(alpha: 0.35),
                    AppTheme.accentBlue.withValues(alpha: 0.18),
                  ],
                ),
                border: Border.all(
                  color: AppTheme.accentCyan.withValues(alpha: 0.65),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentCyan.withValues(alpha: 0.30),
                    blurRadius: 14,
                    offset: const Offset(0, 2),
                  ),
                ],
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 21,
              color: isSelected ? AppTheme.accentCyan : AppTheme.textSecondary,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DashboardView extends StatelessWidget {
  final ValueChanged<int> onSelectTab;

  const _DashboardView({required this.onSelectTab});

  @override
  Widget build(BuildContext context) {
    final mqtt = context.watch<MqttService>();
    final led = context.watch<LedProvider>();
    final state = led.ledState;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Smart LED Pro',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: mqtt.isConnected
                                      ? AppTheme.accentCyan
                                      : AppTheme.accentRed,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (mqtt.isConnected
                                              ? AppTheme.accentCyan
                                              : AppTheme.accentRed)
                                          .withValues(alpha: 0.6),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                mqtt.isConnected
                                    ? 'ESP32 Online • MQTT Sẵn sàng'
                                    : 'Chưa kết nối MQTT',
                                style: TextStyle(
                                  color: mqtt.isConnected
                                      ? AppTheme.accentCyan
                                      : AppTheme.textSecondary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Settings Liquid Glass Button
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.22),
                                ),
                              ),
                              child: const Icon(
                                Icons.settings_rounded,
                                color: AppTheme.textPrimary,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // 3D Liquid Glass Power Switch Card
                  LiquidGlassCard(
                    tintColor: state.isOn ? state.color : null,
                    borderRadius: 24,
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        // Dynamic 3D Glowing Bulb Disc
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: state.isOn
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      state.color,
                                      state.color.withValues(alpha: 0.6),
                                    ],
                                  )
                                : LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.12),
                                      Colors.white.withValues(alpha: 0.04),
                                    ],
                                  ),
                            boxShadow: state.isOn
                                ? [
                                    BoxShadow(
                                      color: state.color.withValues(alpha: 0.55),
                                      blurRadius: 22,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                            border: Border.all(
                              color: state.isOn
                                  ? Colors.white.withValues(alpha: 0.6)
                                  : Colors.white.withValues(alpha: 0.15),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            state.isOn
                                ? Icons.lightbulb_rounded
                                : Icons.lightbulb_outline_rounded,
                            color: state.isOn
                                ? Colors.white
                                : AppTheme.textSecondary,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.isOn ? 'Đèn đang BẬT' : 'Đèn đang TẮT',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Độ sáng ${state.brightness}% • ${state.effect.displayName}',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Transform.scale(
                          scale: 1.15,
                          child: Switch(
                            value: state.isOn,
                            onChanged: (v) => led.togglePower(v),
                            activeThumbColor: AppTheme.accentCyan,
                            activeTrackColor:
                                AppTheme.accentCyan.withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3D Liquid Glass Brightness Card
                  LiquidGlassCard(
                    borderRadius: 24,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.brightness_6_rounded,
                                  size: 20,
                                  color: AppTheme.accentCyan,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Độ Sáng Dải LED',
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
                                color: AppTheme.accentCyan.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppTheme.accentCyan.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                '${state.brightness}%',
                                style: const TextStyle(
                                  color: AppTheme.accentCyan,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: AppTheme.accentCyan,
                            inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                            thumbColor: Colors.white,
                            overlayColor: AppTheme.accentCyan.withValues(alpha: 0.2),
                            trackHeight: 7,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 10,
                              elevation: 4,
                            ),
                          ),
                          child: Slider(
                            value: state.brightness.toDouble(),
                            min: 0,
                            max: 100,
                            onChanged: (v) => led.setBrightness(v.toInt()),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [25, 50, 75, 100].map((b) {
                            final isSel = state.brightness == b;
                            return GestureDetector(
                              onTap: () => led.setBrightness(b),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? AppTheme.accentCyan.withValues(alpha: 0.25)
                                      : Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSel
                                        ? AppTheme.accentCyan
                                        : Colors.white.withValues(alpha: 0.12),
                                    width: isSel ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  '$b%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                    color: isSel ? AppTheme.accentCyan : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Smart Scenes Header
                  const Text(
                    'Ngữ Cảnh Chiếu Sáng',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Scene Modes Horizontal Carousel
                  SizedBox(
                    height: 104,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _SceneCard(
                          icon: Icons.menu_book_rounded,
                          label: 'Học bài & Làm việc',
                          subtitle: 'Trắng 80%',
                          color: const Color(0xFFE2E8F0),
                          onTap: () {
                            if (!state.isOn) led.togglePower(true);
                            led.setColor(const Color(0xFFFFFFFF));
                            led.setBrightness(80);
                            led.setEffect(LedEffect.none);
                          },
                        ),
                        _SceneCard(
                          icon: Icons.coffee_rounded,
                          label: 'Thư giãn & Chill',
                          subtitle: 'Vàng ấm 45%',
                          color: const Color(0xFFFFB703),
                          onTap: () {
                            if (!state.isOn) led.togglePower(true);
                            led.setColor(const Color(0xFFFFB464));
                            led.setBrightness(45);
                            led.setEffect(LedEffect.none);
                          },
                        ),
                        _SceneCard(
                          icon: Icons.movie_rounded,
                          label: 'Rạp phim tại gia',
                          subtitle: 'Tím dịu 25%',
                          color: const Color(0xFFA855F7),
                          onTap: () {
                            if (!state.isOn) led.togglePower(true);
                            led.setColor(const Color(0xFF8A2BE2));
                            led.setBrightness(25);
                            led.setEffect(LedEffect.none);
                          },
                        ),
                        _SceneCard(
                          icon: Icons.nightlight_round,
                          label: 'Đèn ngủ êm dịu',
                          subtitle: 'Hổ phách 10%',
                          color: const Color(0xFFFF8500),
                          onTap: () {
                            if (!state.isOn) led.togglePower(true);
                            led.setColor(const Color(0xFFFF8500));
                            led.setBrightness(10);
                            led.setEffect(LedEffect.none);
                          },
                        ),
                        _SceneCard(
                          icon: Icons.celebration_rounded,
                          label: 'Sôi động Party',
                          subtitle: 'Cầu vồng 100%',
                          color: const Color(0xFF00F2FE),
                          onTap: () {
                            if (!state.isOn) led.togglePower(true);
                            led.setBrightness(100);
                            led.setEffect(LedEffect.rainbow);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Quick actions label
                  const Text(
                    'Điều Khiển Nhanh',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3D Glass Quick Action Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.55,
                    children: [
                      _ActionCard3D(
                        icon: Icons.palette_rounded,
                        label: 'Chọn màu sắc',
                        glowColor: AppTheme.accentPurple,
                        onTap: () => onSelectTab(1),
                      ),
                      _ActionCard3D(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Hiệu ứng ánh sáng',
                        glowColor: AppTheme.accentCyan,
                        onTap: () => onSelectTab(2),
                      ),
                      _ActionCard3D(
                        icon: led.autoMode
                            ? Icons.autorenew_rounded
                            : Icons.autorenew_outlined,
                        label: led.autoMode ? 'Cảm biến: BẬT' : 'Cảm biến: TẮT',
                        glowColor: led.autoMode
                            ? AppTheme.accentGreen
                            : AppTheme.textSecondary,
                        onTap: () => led.setAutoMode(!led.autoMode),
                      ),
                      _ActionCard3D(
                        icon: Icons.sensors_rounded,
                        label:
                            '${led.sensorData.lightIntensity.toStringAsFixed(0)} lux',
                        glowColor: AppTheme.accentOrange,
                        onTap: () => onSelectTab(4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // Preset colors
                  const Text(
                    'Màu Sắc Nhanh',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 68,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _GemstoneColor3D(
                          color: const Color(0xFFFF2D55),
                          label: 'Đỏ',
                          onTap: () => led.setColor(const Color(0xFFFF2D55)),
                        ),
                        _GemstoneColor3D(
                          color: const Color(0xFF00F5D4),
                          label: 'Cyan',
                          onTap: () => led.setColor(const Color(0xFF00F5D4)),
                        ),
                        _GemstoneColor3D(
                          color: const Color(0xFF10B981),
                          label: 'Xanh lá',
                          onTap: () => led.setColor(const Color(0xFF10B981)),
                        ),
                        _GemstoneColor3D(
                          color: const Color(0xFF38BDF8),
                          label: 'Xanh lam',
                          onTap: () => led.setColor(const Color(0xFF38BDF8)),
                        ),
                        _GemstoneColor3D(
                          color: const Color(0xFFFFB703),
                          label: 'Vàng',
                          onTap: () => led.setColor(const Color(0xFFFFB703)),
                        ),
                        _GemstoneColor3D(
                          color: const Color(0xFFA855F7),
                          label: 'Tím',
                          onTap: () => led.setColor(const Color(0xFFA855F7)),
                        ),
                        _GemstoneColor3D(
                          color: const Color(0xFFFF8500),
                          label: 'Cam',
                          onTap: () => led.setColor(const Color(0xFFFF8500)),
                        ),
                        _GemstoneColor3D(
                          color: const Color(0xFFFF007A),
                          label: 'Hồng',
                          onTap: () => led.setColor(const Color(0xFFFF007A)),
                        ),
                        _GemstoneColor3D(
                          color: const Color(0xFFFFD166),
                          label: 'Ấm',
                          onTap: () => led.setColor(const Color(0xFFFFD166)),
                        ),
                        _GemstoneColor3D(
                          color: Colors.white,
                          label: 'Trắng',
                          onTap: () => led.setColor(Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 3D Liquid Glass Quick Action Card
class _ActionCard3D extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color glowColor;
  final VoidCallback onTap;

  const _ActionCard3D({
    required this.icon,
    required this.label,
    required this.glowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      tintColor: glowColor,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: glowColor.withValues(alpha: 0.2),
              border: Border.all(
                color: glowColor.withValues(alpha: 0.4),
              ),
            ),
            child: Icon(
              icon,
              color: glowColor,
              size: 22,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// 3D Gemstone Color Preset Sphere
class _GemstoneColor3D extends StatelessWidget {
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _GemstoneColor3D({
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.35, -0.45),
                  radius: 0.9,
                  colors: [
                    Colors.white.withValues(alpha: 0.8),
                    color,
                    color.withValues(alpha: 0.8),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 12,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 3D Liquid Glass Smart Scene Card
class _SceneCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SceneCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 154,
      margin: const EdgeInsets.only(right: 12),
      child: LiquidGlassCard(
        borderRadius: 18,
        padding: const EdgeInsets.all(12),
        tintColor: color,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.22),
                    border: Border.all(
                      color: color.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 11,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: color.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
