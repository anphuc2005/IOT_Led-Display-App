import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/mqtt_config.dart';
import '../services/mqtt_service.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../providers/led_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_glass.dart';

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

  static const List<Map<String, dynamic>> _brokerPresets = [
    {
      'name': '⚡ Chuẩn ESP32 (HiveMQ)',
      'broker': 'broker.hivemq.com',
      'port': 1883,
      'topic': 'smart_led',
      'leds': 8,
    },
    {
      'name': '🌐 EMQX Public',
      'broker': 'broker.emqx.io',
      'port': 1883,
      'topic': 'smart_led',
      'leds': 8,
    },
    {
      'name': '🦟 Mosquitto',
      'broker': 'test.mosquitto.org',
      'port': 1883,
      'topic': 'smart_led',
      'leds': 8,
    },
    {
      'name': '🏠 Mạng LAN nội bộ',
      'broker': '192.168.1.100',
      'port': 1883,
      'topic': 'smart_led',
      'leds': 8,
    },
  ];

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

    if (!mounted) return;
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

  Future<void> _applyPresetAndConnect(Map<String, dynamic> preset) async {
    setState(() {
      _brokerController.text = preset['broker'] as String;
      _portController.text = (preset['port'] as int).toString();
      _topicPrefixController.text = preset['topic'] as String;
      _numLedsController.text = (preset['leds'] as int).toString();
    });
    await _saveAndConnect();
  }

  Future<void> _saveAndConnect() async {
    final storage = StorageService();
    final config = MqttConfig(
      broker: _brokerController.text.trim().isEmpty
          ? 'broker.hivemq.com'
          : _brokerController.text.trim(),
      port: int.tryParse(_portController.text) ?? 1883,
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
      topicPrefix: _topicPrefixController.text.trim().isEmpty
          ? 'smart_led'
          : _topicPrefixController.text.trim(),
    );

    await storage.saveMqttConfig(config);
    await storage.saveGeminiApiKey(_apiKeyController.text.trim());

    final numLeds = int.tryParse(_numLedsController.text) ?? 8;
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
              ? '✅ Đã kết nối thành công tới ${config.broker} (Topic: ${config.topicPrefix})!'
              : '⚠️ Đã lưu cài đặt. Chưa kết nối được MQTT: ${mqtt.errorMessage}',
        ),
        backgroundColor:
            mqtt.isConnected ? AppTheme.accentGreen : AppTheme.accentOrange,
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
    final led = context.watch<LedProvider>();
    final isConnecting = mqtt.connectionState == AppConnectionState.connecting;

    return LiquidBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Kết Nối Phần Cứng & Cài Đặt',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 19,
              letterSpacing: -0.3,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 3D Liquid Glass Connection status banner + Quick Test Button
              LiquidGlassCard(
                borderRadius: 18,
                tintColor: mqtt.isConnected
                    ? AppTheme.accentGreen
                    : (isConnecting
                        ? AppTheme.accentOrange
                        : AppTheme.accentRed),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: (mqtt.isConnected
                                    ? AppTheme.accentGreen
                                    : AppTheme.accentRed)
                                .withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (mqtt.isConnected
                                      ? AppTheme.accentGreen
                                      : AppTheme.accentRed)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: isConnecting
                              ? const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.accentOrange,
                                  ),
                                )
                              : Icon(
                                  mqtt.isConnected
                                      ? Icons.wifi_rounded
                                      : Icons.wifi_off_rounded,
                                  color: mqtt.isConnected
                                      ? AppTheme.accentGreen
                                      : AppTheme.accentRed,
                                  size: 20,
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mqtt.isConnected
                                    ? 'Đã kết nối MQTT (${mqtt.config.broker})'
                                    : (isConnecting
                                        ? 'Đang kết nối MQTT...'
                                        : 'Chưa kết nối MQTT'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: mqtt.isConnected
                                      ? AppTheme.accentGreen
                                      : AppTheme.accentRed,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                mqtt.isConnected
                                    ? 'Topic: ${mqtt.config.topicPrefix}/# • Sẵn sàng điều khiển ESP32'
                                    : (mqtt.errorMessage.isNotEmpty
                                        ? mqtt.errorMessage
                                        : 'Bấm chọn cấu hình chuẩn ESP32 bên dưới để kết nối ngay'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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
                    if (mqtt.isConnected) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            led.sendHardwareTestPing();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  '⚡ Đã gửi tín hiệu bật sáng màu Cyan 100% tới mạch ESP32!',
                                ),
                                backgroundColor: AppTheme.accentGreen,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.flash_on_rounded, size: 18),
                          label: const Text(
                            'Bật thử đèn trên mạch ESP32 ngay',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.accentCyan,
                            side: BorderSide(
                              color: AppTheme.accentCyan.withValues(alpha: 0.6),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 1-Tap Quick Connect Hardware Card
              LiquidGlassCard(
                borderRadius: 22,
                tintColor: AppTheme.accentCyan,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(
                      icon: Icons.bolt_rounded,
                      title: 'Kết Nối Nhanh 1 Chạm (ESP32)',
                      color: AppTheme.accentCyan,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Chọn đúng máy chủ MQTT đang nạp trong code ESP32 để tự động điền và kết nối ngay lập tức:',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _brokerPresets.map((preset) {
                        final isSelected = _brokerController.text.trim() ==
                            (preset['broker'] as String);
                        return GestureDetector(
                          onTap: () => _applyPresetAndConnect(preset),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.accentCyan.withValues(alpha: 0.25)
                                  : Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.accentCyan
                                    : Colors.white.withValues(alpha: 0.18),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.check_circle_rounded
                                      : Icons.memory_rounded,
                                  size: 14,
                                  color: isSelected
                                      ? AppTheme.accentCyan
                                      : AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  preset['name'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.textPrimary,
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
              ),
              const SizedBox(height: 20),

              // MQTT Settings Card
              LiquidGlassCard(
                borderRadius: 22,
                tintColor: AppTheme.accentBlue,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(
                      icon: Icons.router_rounded,
                      title: 'Cấu Hình MQTT Broker & Dải LED',
                      color: AppTheme.accentBlue,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _brokerController,
                      label: 'Địa chỉ MQTT Broker',
                      hint: 'broker.hivemq.com',
                      icon: Icons.dns_rounded,
                      iconColor: AppTheme.accentBlue,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _portController,
                            label: 'Port',
                            hint: '1883',
                            icon: Icons.numbers_rounded,
                            iconColor: AppTheme.accentBlue,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _numLedsController,
                            label: 'Số bóng LED',
                            hint: '8',
                            icon: Icons.linear_scale_rounded,
                            iconColor: AppTheme.accentOrange,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _topicPrefixController,
                      label: 'Topic prefix (trùng với TOPIC_PREFIX trên ESP32)',
                      hint: 'smart_led',
                      icon: Icons.topic_rounded,
                      iconColor: AppTheme.accentBlue,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _usernameController,
                      label: 'Username (để trống nếu dùng HiveMQ/Mosquitto)',
                      hint: '',
                      icon: Icons.person_rounded,
                      iconColor: AppTheme.accentBlue,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _passwordController,
                      label: 'Password (tùy chọn)',
                      hint: '',
                      icon: Icons.lock_rounded,
                      iconColor: AppTheme.accentBlue,
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
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Gemini AI Settings Card
              LiquidGlassCard(
                borderRadius: 22,
                tintColor: AppTheme.accentPurple,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(
                      icon: Icons.smart_toy_rounded,
                      title: 'Trợ Lý AI Điều Khiển Đèn (Gemini)',
                      color: AppTheme.accentPurple,
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _apiKeyController,
                      label: 'Gemini API Key',
                      hint: 'AIzaSy...',
                      icon: Icons.key_rounded,
                      iconColor: AppTheme.accentPurple,
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
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.mic_rounded,
                          size: 15,
                          color: AppTheme.accentCyan,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Nhận diện giọng nói & đọc phản hồi tiếng Việt hoạt động trực tiếp trên điện thoại (không cần API giọng nói).',
                            style: TextStyle(
                              color: AppTheme.accentCyan.withValues(alpha: 0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 3D Liquid Glass Save & Connect Button
              LiquidGlassButton(
                isPrimary: true,
                glowColor: AppTheme.accentCyan,
                borderRadius: 18,
                padding: const EdgeInsets.symmetric(vertical: 16),
                onPressed: _saveAndConnect,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Lưu Cấu Hình & Kết Nối Ngay',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Disconnect button if connected
              if (mqtt.isConnected) ...[
                const SizedBox(height: 14),
                LiquidGlassButton(
                  isPrimary: false,
                  glowColor: AppTheme.accentRed,
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  onPressed: () => mqtt.disconnect(),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.link_off_rounded,
                          color: AppTheme.accentRed, size: 20),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Ngắt Kết Nối MQTT',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Hardware Pinout Reference Card
              LiquidGlassCard(
                borderRadius: 18,
                padding: const EdgeInsets.all(16),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.developer_board_rounded,
                          size: 18,
                          color: AppTheme.accentCyan,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sơ Đồ Chân Mạch Phần Cứng ESP32',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Dải LED WS2812 (8 bóng): Chân DATA -> GPIO 18\n'
                      '• Cảm biến ánh sáng BH1750: SDA -> GPIO 21, SCL -> GPIO 22\n'
                      '• Cảm biến chuyển động PIR: OUT -> GPIO 27\n'
                      '• Cảm biến nhiệt ẩm DHT11: DATA -> GPIO 26\n'
                      '• MQTT mặc định trên ESP32: broker.hivemq.com:1883 (topic: smart_led)',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    Color iconColor = AppTheme.accentCyan,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
        ),
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.25),
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, size: 20, color: iconColor),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.25),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: iconColor,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.color = AppTheme.accentCyan,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: color.withValues(alpha: 0.45),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.20),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(icon, size: 18, color: color),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }
}
