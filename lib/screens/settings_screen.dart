import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/app_bloc.dart';
import '../bloc/led_bloc.dart';
import '../bloc/settings_bloc.dart';
import '../services/mqtt_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => SettingsBloc(context.read<StorageService>())
          ..add(const SettingsRequested()),
        child: const _SettingsView(),
      );
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<SettingsBloc, SettingsState>(
        listenWhen: (previous, current) =>
            previous.status != current.status &&
            (current.status == SettingsStatus.success ||
                current.status == SettingsStatus.failure),
        listener: (context, state) {
          if (state.status == SettingsStatus.success) {
            final led = context.read<LedBloc>().state;
            context.read<AppBloc>().add(AppConfigurationApplied(
                  config: state.config,
                  apiKey: state.apiKey.trim(),
                  autoMode: led.autoMode,
                  numLeds: state.parsedNumLeds,
                ));
          }
          if (state.message != null) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.message!)));
          }
        },
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Cài đặt')),
          body: state.status == SettingsStatus.loading ||
                  state.status == SettingsStatus.initial
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: ResponsiveContent(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BlocBuilder<AppBloc, AppState>(
                              builder: (context, app) {
                            final connected = app.connectionStatus ==
                                MqttConnectionStatus.connected;
                            return StatusBanner(
                              icon: connected
                                  ? Icons.wifi_rounded
                                  : Icons.wifi_off_rounded,
                              title: connected
                                  ? 'MQTT đã kết nối'
                                  : 'MQTT chưa kết nối',
                              message: connected
                                  ? '${app.config.broker}:${app.config.port}'
                                  : app.message ??
                                      'Kiểm tra thông tin broker bên dưới.',
                              color: connected
                                  ? AppTheme.accent
                                  : Theme.of(context).colorScheme.error,
                            );
                          }),
                          const SizedBox(height: 24),
                          const _SettingsSectionTitle(
                              icon: Icons.router_rounded, title: 'MQTT Broker'),
                          const SizedBox(height: 12),
                          _Field(
                            field: SettingsField.broker,
                            initialValue: state.broker,
                            label: 'Địa chỉ broker',
                            hint: 'test.mosquitto.org',
                            icon: Icons.dns_rounded,
                            error: state.errors[SettingsField.broker],
                          ),
                          const SizedBox(height: 12),
                          _Field(
                            field: SettingsField.port,
                            initialValue: state.port,
                            label: 'Port',
                            hint: '1883',
                            icon: Icons.numbers_rounded,
                            keyboardType: TextInputType.number,
                            error: state.errors[SettingsField.port],
                          ),
                          const SizedBox(height: 12),
                          _Field(
                              field: SettingsField.username,
                              initialValue: state.username,
                              label: 'Tên đăng nhập',
                              hint: 'Không bắt buộc',
                              icon: Icons.person_outline_rounded),
                          const SizedBox(height: 12),
                          _Field(
                            field: SettingsField.password,
                            initialValue: state.password,
                            label: 'Mật khẩu',
                            hint: 'Không bắt buộc',
                            icon: Icons.lock_outline_rounded,
                            obscure: state.obscurePassword,
                            suffix: IconButton(
                              tooltip: state.obscurePassword
                                  ? 'Hiện mật khẩu'
                                  : 'Ẩn mật khẩu',
                              onPressed: () => context.read<SettingsBloc>().add(
                                  const SettingsPasswordVisibilityToggled()),
                              icon: Icon(state.obscurePassword
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _Field(
                            field: SettingsField.topicPrefix,
                            initialValue: state.topicPrefix,
                            label: 'Topic prefix',
                            hint: 'smart_led',
                            icon: Icons.tag_rounded,
                            error: state.errors[SettingsField.topicPrefix],
                          ),
                          const SizedBox(height: 28),
                          const _SettingsSectionTitle(
                              icon: Icons.smart_toy_outlined,
                              title: 'Gemini AI'),
                          const SizedBox(height: 12),
                          _Field(
                            field: SettingsField.apiKey,
                            initialValue: state.apiKey,
                            label: 'Gemini API Key',
                            hint: 'AIzaSy…',
                            icon: Icons.key_rounded,
                            obscure: state.obscureApiKey,
                            suffix: IconButton(
                              tooltip: state.obscureApiKey
                                  ? 'Hiện API key'
                                  : 'Ẩn API key',
                              onPressed: () => context
                                  .read<SettingsBloc>()
                                  .add(const SettingsApiKeyVisibilityToggled()),
                              icon: Icon(state.obscureApiKey
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                              'Tạo API key tại Google AI Studio. Khóa được lưu bằng secure storage trên thiết bị.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                          const SizedBox(height: 28),
                          const _SettingsSectionTitle(
                              icon: Icons.lightbulb_outline_rounded,
                              title: 'Phần cứng LED'),
                          const SizedBox(height: 12),
                          _Field(
                            field: SettingsField.numLeds,
                            initialValue: state.numLeds,
                            label: 'Số LED trên dải',
                            hint: '30',
                            icon: Icons.linear_scale_rounded,
                            keyboardType: TextInputType.number,
                            error: state.errors[SettingsField.numLeds],
                          ),
                          const SizedBox(height: 28),
                          if (state.errors.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: StatusBanner(
                                icon: Icons.error_outline_rounded,
                                title: 'Cài đặt chưa hợp lệ',
                                message:
                                    'Hãy sửa các trường được đánh dấu trước khi lưu.',
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: state.status == SettingsStatus.saving
                                  ? null
                                  : () => context
                                      .read<SettingsBloc>()
                                      .add(const SettingsSubmitted()),
                              icon: state.status == SettingsStatus.saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.save_rounded),
                              label: Text(state.status == SettingsStatus.saving
                                  ? 'Đang lưu…'
                                  : 'Lưu và kết nối lại'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: context.select<AppBloc, bool>(
                                      (bloc) => bloc.state.isConnected)
                                  ? () => context
                                      .read<AppBloc>()
                                      .add(const AppDisconnectRequested())
                                  : null,
                              icon: const Icon(Icons.link_off_rounded),
                              label: const Text('Ngắt kết nối'),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const SmartCard(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Smart LED Control v1.0',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  SizedBox(height: 6),
                                  Text(
                                      'Điều khiển ESP32 và dải LED WS2812 qua MQTT, theo dõi cảm biến và hỗ trợ lệnh Gemini AI.'),
                                ]),
                          ),
                        ]),
                  ),
                ),
        ),
      );
}

class _Field extends StatelessWidget {
  final SettingsField field;
  final String initialValue;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;
  final String? error;
  const _Field({
    required this.field,
    required this.initialValue,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.suffix,
    this.error,
  });
  @override
  Widget build(BuildContext context) => TextFormField(
        key: ValueKey(field.name),
        initialValue: initialValue,
        keyboardType: keyboardType,
        obscureText: obscure,
        enableSuggestions: !obscure,
        autocorrect: !obscure,
        onChanged: (value) => context
            .read<SettingsBloc>()
            .add(SettingsValueChanged(field, value)),
        decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon),
            suffixIcon: suffix,
            errorText: error),
      );
}

class _SettingsSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SettingsSectionTitle({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ]);
}
