import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/mqtt_config.dart';
import '../services/mqtt_service.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../providers/led_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _brokerController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _topicPrefixController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _numLedsController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final storage = StorageService();
    final config = await storage.loadMqttConfig();
    final apiKey = await storage.loadGeminiApiKey();
    final numLeds = await storage.loadNumLeds();

    setState(() {
      _brokerController.text = config.broker;
      _portController.text = config.port.toString();
      _usernameController.text = config.username;
      _passwordController.text = config.password;
      _topicPrefixController.text = config.topicPrefix;
      _apiKeyController.text = apiKey;
      _numLedsController.text = numLeds.toString();
    });
  }

  Future<void> _saveAndConnect() async {
    final storage = StorageService();
    final config = MqttConfig(
      broker: _brokerController.text.trim(),
      port: int.tryParse(_portController.text) ?? 1883,
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
      topicPrefix: _topicPrefixController.text.trim().isEmpty
          ? 'smart_led'
          : _topicPrefixController.text.trim(),
    );

    await storage.saveMqttConfig(config);
    await storage.saveGeminiApiKey(_apiKeyController.text.trim());

    final numLeds = int.tryParse(_numLedsController.text) ?? 30;
    await storage.saveNumLeds(numLeds);

    if (!mounted) return;

    final mqtt = context.read<MqttService>();
    mqtt.updateConfig(config);

    final ai = context.read<AiService>();
    ai.setApiKey(_apiKeyController.text.trim());

    final led = context.read<LedProvider>();
    led.setNumLeds(numLeds);

    mqtt.disconnect();
    await mqtt.connect();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mqtt.isConnected
              ? 'Kết nối MQTT thành công!'
              : 'Lỗi kết nối: ${mqtt.errorMessage}',
        ),
        backgroundColor:
            mqtt.isConnected ? AppTheme.accentGreen : AppTheme.accentRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _brokerController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _topicPrefixController.dispose();
    _apiKeyController.dispose();
    _numLedsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mqtt = context.watch<MqttService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: mqtt.isConnected
                    ? AppTheme.accentGreen.withOpacity(0.1)
                    : AppTheme.accentRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: mqtt.isConnected
                      ? AppTheme.accentGreen.withOpacity(0.3)
                      : AppTheme.accentRed.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    mqtt.isConnected
                        ? Icons.wifi_rounded
                        : Icons.wifi_off_rounded,
                    color: mqtt.isConnected
                        ? AppTheme.accentGreen
                        : AppTheme.accentRed,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mqtt.isConnected
                              ? 'Đã kết nối MQTT'
                              : 'Chưa kết nối',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: mqtt.isConnected
                                ? AppTheme.accentGreen
                                : AppTheme.accentRed,
                          ),
                        ),
                        if (mqtt.errorMessage.isNotEmpty)
                          Text(
                            mqtt.errorMessage,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // MQTT Settings
            _SectionHeader(
              icon: Icons.router_rounded,
              title: 'MQTT Broker',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _brokerController,
              label: 'Địa chỉ broker',
              hint: 'test.mosquitto.org',
              icon: Icons.dns_rounded,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _portController,
              label: 'Port',
              hint: '1883',
              icon: Icons.numbers_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _usernameController,
              label: 'Username (tùy chọn)',
              hint: '',
              icon: Icons.person_rounded,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _passwordController,
              label: 'Password (tùy chọn)',
              hint: '',
              icon: Icons.lock_rounded,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: AppTheme.textSecondary,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _topicPrefixController,
              label: 'Topic prefix',
              hint: 'smart_led',
              icon: Icons.topic_rounded,
            ),
            const SizedBox(height: 24),

            // AI Settings
            _SectionHeader(
              icon: Icons.smart_toy_rounded,
              title: 'Gemini AI API',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _apiKeyController,
              label: 'API Key',
              hint: 'AIzaSy...',
              icon: Icons.key_rounded,
              obscureText: _obscureApiKey,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureApiKey
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: AppTheme.textSecondary,
                ),
                onPressed: () =>
                    setState(() => _obscureApiKey = !_obscureApiKey),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                // Can open browser link later
              },
              child: const Text(
                'Lấy API Key miễn phí tại: aistudio.google.com',
                style: TextStyle(
                  color: AppTheme.accentBlue,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // LED Settings
            _SectionHeader(
              icon: Icons.light,
              title: 'Cài đặt LED',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _numLedsController,
              label: 'Số LED trong dải (WS2812)',
              hint: '30',
              icon: Icons.linear_scale_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saveAndConnect,
                icon: const Icon(Icons.save_rounded),
                label: const Text(
                  'Lưu & Kết nối',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Disconnect button
            if (mqtt.isConnected)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => mqtt.disconnect(),
                  icon: const Icon(Icons.link_off_rounded),
                  label: const Text('Ngắt kết nối'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentRed,
                    side: const BorderSide(color: AppTheme.accentRed),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 32),

            // About section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderDark),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart LED Control v1.0',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'App điều khiển đèn LED thông minh qua MQTT.\n'
                    'Hỗ trợ ESP32 + WS2812 LED Strip.\n'
                    'Tích hợp AI Gemini cho điều khiển bằng giọng nói.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffixIcon,
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.accentBlue),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}
