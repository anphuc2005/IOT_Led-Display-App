import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/app_bloc.dart';
import '../bloc/led_bloc.dart';
import '../bloc/navigation_bloc.dart';
import '../models/led_state.dart';
import '../services/mqtt_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'ai_chat_screen.dart';
import 'color_picker_screen.dart';
import 'effects_screen.dart';
import 'sensor_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _screens = [
    DashboardScreen(),
    ColorPickerScreen(),
    EffectsScreen(),
    AiChatScreen(),
    SensorScreen(),
  ];

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<NavigationBloc, NavigationState>(
        builder: (context, navigation) => Scaffold(
          body: IndexedStack(index: navigation.index, children: _screens),
          bottomNavigationBar: NavigationBar(
            selectedIndex: navigation.index,
            onDestinationSelected: (index) => context
                .read<NavigationBloc>()
                .add(NavigationTabSelected(index)),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded),
                  label: 'Tổng quan'),
              NavigationDestination(
                  icon: Icon(Icons.palette_outlined),
                  selectedIcon: Icon(Icons.palette_rounded),
                  label: 'Màu sắc'),
              NavigationDestination(
                  icon: Icon(Icons.auto_awesome_outlined),
                  selectedIcon: Icon(Icons.auto_awesome_rounded),
                  label: 'Hiệu ứng'),
              NavigationDestination(
                  icon: Icon(Icons.smart_toy_outlined),
                  selectedIcon: Icon(Icons.smart_toy_rounded),
                  label: 'Trợ lý'),
              NavigationDestination(
                  icon: Icon(Icons.sensors_outlined),
                  selectedIcon: Icon(Icons.sensors_rounded),
                  label: 'Cảm biến'),
            ],
          ),
        ),
      );
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocListener<LedBloc, LedBlocState>(
        listenWhen: (previous, current) =>
            previous.errorMessage != current.errorMessage &&
            current.errorMessage != null,
        listener: (context, state) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          context.read<LedBloc>().add(const LedErrorCleared());
        },
        child: SafeArea(
          child: BlocBuilder<AppBloc, AppState>(
            builder: (context, app) => BlocBuilder<LedBloc, LedBlocState>(
              builder: (context, led) => SingleChildScrollView(
                child: ResponsiveContent(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ScreenHeader(
                          title: 'Smart LED',
                          subtitle:
                              'Điều khiển ánh sáng và theo dõi không gian',
                          trailing: IconButton.filledTonal(
                            tooltip: 'Mở cài đặt',
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const SettingsScreen())),
                            icon: const Icon(Icons.settings_rounded),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _ConnectionBanner(app: app),
                        const SizedBox(height: 16),
                        _PowerCard(state: led, enabled: app.isConnected),
                        const SizedBox(height: 16),
                        _BrightnessCard(state: led, enabled: app.isConnected),
                        const SizedBox(height: 24),
                        const SectionTitle('Điều khiển nhanh'),
                        const SizedBox(height: 12),
                        LayoutBuilder(builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 720 ? 4 : 2;
                          return GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: columns,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: columns == 4 ? 1.35 : 1.5,
                            children: [
                              _QuickAction(
                                  icon: Icons.palette_rounded,
                                  label: 'Chọn màu',
                                  value: _colorName(led.led.color),
                                  onTap: () => _openTab(context, 1)),
                              _QuickAction(
                                  icon: Icons.auto_awesome_rounded,
                                  label: 'Hiệu ứng',
                                  value: led.led.effect.displayName,
                                  onTap: () => _openTab(context, 2)),
                              _QuickAction(
                                icon: Icons.auto_mode_rounded,
                                label: 'Tự động',
                                value: led.autoMode ? 'Đang bật' : 'Đang tắt',
                                onTap: app.isConnected
                                    ? () => context
                                        .read<LedBloc>()
                                        .add(LedAutoModeChanged(!led.autoMode))
                                    : null,
                              ),
                              _QuickAction(
                                icon: Icons.light_mode_rounded,
                                label: 'Ánh sáng',
                                value:
                                    '${led.sensor.lightIntensity.toStringAsFixed(0)} lux',
                                onTap: () => _openTab(context, 4),
                              ),
                            ],
                          );
                        }),
                        const SizedBox(height: 24),
                        const SectionTitle('Màu nhanh'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: const [
                            _PresetColor(label: 'Đỏ', color: Color(0xFFEF4444)),
                            _PresetColor(
                                label: 'Xanh lá', color: Color(0xFF22C55E)),
                            _PresetColor(
                                label: 'Xanh dương', color: Color(0xFF3B82F6)),
                            _PresetColor(
                                label: 'Vàng', color: Color(0xFFFACC15)),
                            _PresetColor(
                                label: 'Tím', color: Color(0xFFA855F7)),
                            _PresetColor(label: 'Ấm', color: Color(0xFFFFB464)),
                          ],
                        ),
                      ]),
                ),
              ),
            ),
          ),
        ),
      );

  static void _openTab(BuildContext context, int index) =>
      context.read<NavigationBloc>().add(NavigationTabSelected(index));
  static String _colorName(Color color) =>
      '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
}

class _ConnectionBanner extends StatelessWidget {
  final AppState app;
  const _ConnectionBanner({required this.app});
  @override
  Widget build(BuildContext context) {
    final connected = app.connectionStatus == MqttConnectionStatus.connected;
    final busy = app.connectionStatus == MqttConnectionStatus.connecting ||
        app.connectionStatus == MqttConnectionStatus.reconnecting;
    return StatusBanner(
      icon: connected
          ? Icons.wifi_rounded
          : busy
              ? Icons.sync_rounded
              : Icons.wifi_off_rounded,
      title: connected
          ? 'Đã kết nối MQTT'
          : busy
              ? 'Đang kết nối'
              : 'Thiết bị ngoại tuyến',
      message: connected
          ? '${app.config.broker}:${app.config.port}'
          : app.message ?? 'Các điều khiển tạm khóa cho đến khi kết nối lại.',
      color: connected
          ? AppTheme.accent
          : busy
              ? AppTheme.warning
              : Theme.of(context).colorScheme.error,
      action: connected || busy
          ? null
          : IconButton(
              tooltip: 'Kết nối lại',
              onPressed: () =>
                  context.read<AppBloc>().add(const AppReconnectRequested()),
              icon: const Icon(Icons.refresh_rounded),
            ),
    );
  }
}

class _PowerCard extends StatelessWidget {
  final LedBlocState state;
  final bool enabled;
  const _PowerCard({required this.state, required this.enabled});
  @override
  Widget build(BuildContext context) => SmartCard(
        borderColor:
            state.led.isOn ? state.led.color.withValues(alpha: .7) : null,
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: state.led.isOn
                  ? state.led.color.withValues(alpha: .2)
                  : Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
                state.led.isOn
                    ? Icons.lightbulb_rounded
                    : Icons.lightbulb_outline_rounded,
                color: state.led.isOn ? state.led.color : null,
                size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(state.led.isOn ? 'Đèn đang bật' : 'Đèn đang tắt',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                    '${state.led.brightness}% • ${state.led.effect.displayName}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ])),
          Semantics(
            label: 'Bật hoặc tắt đèn',
            toggled: state.led.isOn,
            child: Switch(
              value: state.led.isOn,
              onChanged: enabled
                  ? (value) =>
                      context.read<LedBloc>().add(LedPowerChanged(value))
                  : null,
            ),
          ),
        ]),
      );
}

class _BrightnessCard extends StatelessWidget {
  final LedBlocState state;
  final bool enabled;
  const _BrightnessCard({required this.state, required this.enabled});
  @override
  Widget build(BuildContext context) => SmartCard(
        child: Column(children: [
          Row(children: [
            Icon(Icons.brightness_6_rounded,
                color: Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Độ sáng',
                    style: Theme.of(context).textTheme.titleMedium)),
            Text('${state.led.brightness}%',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.secondary)),
          ]),
          Slider(
            value: state.led.brightness.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            label: '${state.led.brightness}%',
            onChanged: enabled
                ? (value) => context
                    .read<LedBloc>()
                    .add(LedBrightnessPreviewed(value.round()))
                : null,
            onChangeEnd: enabled
                ? (value) => context
                    .read<LedBloc>()
                    .add(LedBrightnessCommitted(value.round()))
                : null,
          ),
        ]),
      );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  const _QuickAction(
      {required this.icon,
      required this.label,
      required this.value,
      this.onTap});
  @override
  Widget build(BuildContext context) => SmartCard(
        onTap: onTap,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: onTap == null
                      ? Theme.of(context).disabledColor
                      : Theme.of(context).colorScheme.secondary),
              const Spacer(),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 2),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
      );
}

class _PresetColor extends StatelessWidget {
  final String label;
  final Color color;
  const _PresetColor({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Chọn màu $label',
        child: ActionChip(
          avatar: CircleAvatar(backgroundColor: color, radius: 10),
          label: Text(label),
          onPressed:
              context.select<AppBloc, bool>((bloc) => bloc.state.isConnected)
                  ? () => context.read<LedBloc>().add(LedColorApplied(color))
                  : null,
        ),
      );
}
