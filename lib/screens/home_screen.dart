import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/led_provider.dart';
import '../services/mqtt_service.dart';
import '../theme/app_theme.dart';
import '../models/led_state.dart';
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
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<Widget> _screens = const [
    _DashboardView(),
    ColorPickerScreen(),
    EffectsScreen(),
    AiChatScreen(),
    SensorScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          border: Border(
            top: BorderSide(color: AppTheme.borderDark.withOpacity(0.5)),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Trang chủ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.palette_rounded),
              label: 'Màu sắc',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome_rounded),
              label: 'Hiệu ứng',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.smart_toy_rounded),
              label: 'AI',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.sensors_rounded),
              label: 'Cảm biến',
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final mqtt = context.watch<MqttService>();
    final led = context.watch<LedProvider>();
    final state = led.ledState;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Smart LED',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
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
                                      ? AppTheme.accentGreen
                                      : AppTheme.accentRed,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                mqtt.isConnected
                                    ? 'Đã kết nối'
                                    : 'Chưa kết nối',
                                style: TextStyle(
                                  color: mqtt.isConnected
                                      ? AppTheme.accentGreen
                                      : AppTheme.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.settings_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.cardDark,
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Power switch card
                  _GlassCard(
                    gradient: state.isOn
                        ? LinearGradient(
                            colors: [
                              Color.fromRGBO(
                                state.color.red,
                                state.color.green,
                                state.color.blue,
                                0.3,
                              ),
                              Color.fromRGBO(
                                state.color.red,
                                state.color.green,
                                state.color.blue,
                                0.1,
                              ),
                            ],
                          )
                        : null,
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: state.isOn
                                ? LinearGradient(
                                    colors: [
                                      state.color.withOpacity(0.8),
                                      state.color.withOpacity(0.4),
                                    ],
                                  )
                                : null,
                            color: state.isOn ? null : AppTheme.cardDark,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            state.isOn
                                ? Icons.lightbulb_rounded
                                : Icons.lightbulb_outline_rounded,
                            color: state.isOn
                                ? Colors.white
                                : AppTheme.textSecondary,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.isOn ? 'Đèn đang bật' : 'Đèn đang tắt',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Độ sáng: ${state.brightness}% • ${state.effect.displayName}',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Transform.scale(
                          scale: 1.2,
                          child: Switch(
                            value: state.isOn,
                            onChanged: (v) => led.togglePower(v),
                            activeColor: AppTheme.accentBlue,
                            activeTrackColor:
                                AppTheme.accentBlue.withOpacity(0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Brightness slider
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.brightness_6_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Độ sáng',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
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
                                color: AppTheme.accentBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${state.brightness}%',
                                style: const TextStyle(
                                  color: AppTheme.accentBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: AppTheme.accentBlue,
                            inactiveTrackColor:
                                AppTheme.accentBlue.withOpacity(0.15),
                            thumbColor: Colors.white,
                            overlayColor:
                                AppTheme.accentBlue.withOpacity(0.15),
                            trackHeight: 6,
                          ),
                          child: Slider(
                            value: state.brightness.toDouble(),
                            min: 0,
                            max: 100,
                            onChanged: (v) => led.setBrightness(v.toInt()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick actions grid
                  Text(
                    'Thao tác nhanh',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.6,
                    children: [
                      _QuickActionCard(
                        icon: Icons.palette_rounded,
                        label: 'Chọn màu',
                        gradient: AppTheme.primaryGradient,
                        onTap: () {
                          // Navigate handled by bottom nav
                        },
                      ),
                      _QuickActionCard(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Hiệu ứng',
                        gradient: AppTheme.cyanGradient,
                        onTap: () {},
                      ),
                      _QuickActionCard(
                        icon: led.autoMode
                            ? Icons.autorenew_rounded
                            : Icons.autorenew_outlined,
                        label: led.autoMode ? 'Tự động: BẬT' : 'Tự động: TẮT',
                        gradient: led.autoMode
                            ? const LinearGradient(
                                colors: [
                                  AppTheme.accentGreen,
                                  Color(0xFF00B4D8)
                                ],
                              )
                            : const LinearGradient(
                                colors: [
                                  AppTheme.textTertiary,
                                  AppTheme.textSecondary
                                ],
                              ),
                        onTap: () => led.setAutoMode(!led.autoMode),
                      ),
                      _QuickActionCard(
                        icon: Icons.sensors_rounded,
                        label:
                            '${led.sensorData.lightIntensity.toStringAsFixed(0)} lux',
                        gradient: AppTheme.warmGradient,
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Preset colors
                  Text(
                    'Màu nhanh',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 64,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _PresetColorButton(
                          color: Colors.red,
                          label: 'Đỏ',
                          onTap: () => led.setColor(Colors.red),
                        ),
                        _PresetColorButton(
                          color: Colors.green,
                          label: 'Xanh lá',
                          onTap: () => led.setColor(Colors.green),
                        ),
                        _PresetColorButton(
                          color: Colors.blue,
                          label: 'Xanh dương',
                          onTap: () => led.setColor(Colors.blue),
                        ),
                        _PresetColorButton(
                          color: Colors.yellow,
                          label: 'Vàng',
                          onTap: () => led.setColor(Colors.yellow),
                        ),
                        _PresetColorButton(
                          color: Colors.purple,
                          label: 'Tím',
                          onTap: () => led.setColor(Colors.purple),
                        ),
                        _PresetColorButton(
                          color: Colors.orange,
                          label: 'Cam',
                          onTap: () => led.setColor(Colors.orange),
                        ),
                        _PresetColorButton(
                          color: Colors.pink,
                          label: 'Hồng',
                          onTap: () => led.setColor(Colors.pink),
                        ),
                        _PresetColorButton(
                          color: Colors.cyan,
                          label: 'Cyan',
                          onTap: () => led.setColor(Colors.cyan),
                        ),
                        _PresetColorButton(
                          color: const Color(0xFFFFB464),
                          label: 'Ấm',
                          onTap: () =>
                              led.setColor(const Color(0xFFFFB464)),
                        ),
                        _PresetColorButton(
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

class _GlassCard extends StatelessWidget {
  final Widget child;
  final LinearGradient? gradient;

  const _GlassCard({required this.child, this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? AppTheme.cardDark : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.borderDark.withOpacity(0.5),
        ),
      ),
      child: child,
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient.colors
                .map((c) => c.withOpacity(0.15))
                .toList(),
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: gradient.colors.first.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              icon,
              color: gradient.colors.first,
              size: 28,
            ),
            Text(
              label,
              style: TextStyle(
                color: gradient.colors.first,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetColorButton extends StatelessWidget {
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _PresetColorButton({
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
