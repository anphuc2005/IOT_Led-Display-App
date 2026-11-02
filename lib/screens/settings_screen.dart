import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/mqtt_config.dart';
import '../services/mqtt_service.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../services/wyoming_stt_service.dart';
import '../services/vieneu_tts_service.dart';
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

  // Wyoming Vietnamese STT settings
  final _wyomingHostController = TextEditingController();
  final _wyomingPortController = TextEditingController();
  bool _wyomingEnabled = false;
  bool _isTestingWyoming = false;

  // VieNeu-TTS settings
  final _vieneuUrlController = TextEditingController();
  final _vieneuApiKeyController = TextEditingController();
  String _vieneuVoice = 'Minh Quân';
  bool _vieneuEnabled = false;
  bool _isTestingVieNeu = false;

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

    final wyomingHost = await storage.loadWyomingHost();
    final wyomingPort = await storage.loadWyomingPort();
    final wyomingEnabled = await storage.loadWyomingEnabled();

    final vieneuEnabled = await storage.loadVieNeuTtsEnabled();
    final vieneuUrl = await storage.loadVieNeuTtsUrl();
    final vieneuVoice = await storage.loadVieNeuTtsVoice();
    final vieneuApiKey = await storage.loadVieNeuTtsApiKey();

    setState(() {
      _brokerController.text = config.broker;
      _portController.text = config.port.toString();
      _usernameController.text = config.username;
      _passwordController.text = config.password;
      _topicPrefixController.text = config.topicPrefix;
      _apiKeyController.text = apiKey;
      _numLedsController.text = numLeds.toString();

      _wyomingHostController.text = wyomingHost;
      _wyomingPortController.text = wyomingPort.toString();
      _wyomingEnabled = wyomingEnabled;

      _vieneuEnabled = vieneuEnabled;
      _vieneuUrlController.text = vieneuUrl;
      _vieneuVoice = vieneuVoice;
      _vieneuApiKeyController.text = vieneuApiKey;
    });
  }

  Future<void> _testWyomingConnection() async {
    final host = _wyomingHostController.text.trim();
    final port = int.tryParse(_wyomingPortController.text.trim()) ?? 10300;

    if (host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vui lòng nhập địa chỉ IP/Host máy chủ Wyoming.'),
          backgroundColor: AppTheme.accentOrange,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isTestingWyoming = true);
    final wyomingService = WyomingSttService();
    final ok = await wyomingService.testConnection(host, port);
    await wyomingService.dispose();

    if (!mounted) return;
    setState(() => _isTestingWyoming = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '✅ Kết nối máy chủ Wyoming Vietnamese ($host:$port) thành công!'
              : '❌ Không thể kết nối tới Wyoming ($host:$port). Hãy kiểm tra IP và cổng.',
        ),
        backgroundColor: ok ? AppTheme.accentGreen : AppTheme.accentRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _testVieNeuConnection() async {
    final url = _vieneuUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vui lòng nhập địa chỉ máy chủ VieNeu-TTS.'),
          backgroundColor: AppTheme.accentOrange,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isTestingVieNeu = true);
    final vieneuService = context.read<VieNeuTtsService>();
    final result = await vieneuService.testConnection(
      baseUrl: url,
      voice: _vieneuVoice,
      apiKey: _vieneuApiKeyController.text.trim().isNotEmpty
          ? _vieneuApiKeyController.text.trim()
          : null,
    );

    if (!mounted) return;
    setState(() => _isTestingVieNeu = false);

    final ok = result['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message'] as String),
        backgroundColor: ok ? AppTheme.accentGreen : AppTheme.accentRed,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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

    // Save Wyoming Vietnamese STT config
    final wyomingPort =
        int.tryParse(_wyomingPortController.text.trim()) ?? 10300;
    await storage.saveWyomingConfig(
      host: _wyomingHostController.text.trim(),
      port: wyomingPort,
      enabled: _wyomingEnabled,
    );

    // Save VieNeu-TTS config
    await storage.saveVieNeuTtsConfig(
      enabled: _vieneuEnabled,
      url: _vieneuUrlController.text.trim(),
      voice: _vieneuVoice,
      apiKey: _vieneuApiKeyController.text.trim(),
    );

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
              ? 'Đã lưu cấu hình & kết nối MQTT thành công!'
              : 'Đã lưu cài đặt. Lỗi MQTT: ${mqtt.errorMessage}',
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
    _wyomingHostController.dispose();
    _wyomingPortController.dispose();
    _vieneuUrlController.dispose();
    _vieneuApiKeyController.dispose();
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
                              : 'Chưa kết nối MQTT',
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

            // Wyoming Vietnamese Speech-to-Text Section
            _SectionHeader(
              icon: Icons.mic_external_on_rounded,
              title: 'Wyoming Vietnamese STT (luuquangvu)',
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nhận diện giọng nói qua Wyoming',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Dùng model Zipformer tiếng Việt chuyên dụng, kháng ồn tốt, nhận diện giọng 3 miền Bắc/Trung/Nam.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _wyomingEnabled,
                        activeColor: AppTheme.accentCyan,
                        onChanged: (v) => setState(() => _wyomingEnabled = v),
                      ),
                    ],
                  ),
                  if (_wyomingEnabled) ...[
                    const Divider(color: AppTheme.borderDark, height: 20),
                    _buildTextField(
                      controller: _wyomingHostController,
                      label: 'Địa chỉ Host / IP máy chủ Wyoming',
                      hint: '192.168.1.100 hoặc localhost',
                      icon: Icons.lan_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _wyomingPortController,
                      label: 'Port Wyoming (mặc định 10300)',
                      hint: '10300',
                      icon: Icons.numbers_rounded,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isTestingWyoming
                            ? null
                            : _testWyomingConnection,
                        icon: _isTestingWyoming
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.accentCyan,
                                ),
                              )
                            : const Icon(Icons.network_check_rounded, size: 18),
                        label: Text(
                          _isTestingWyoming
                              ? 'Đang kiểm tra...'
                              : 'Kiểm tra kết nối Wyoming',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentCyan,
                          side: const BorderSide(color: AppTheme.accentCyan),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '💡 Chạy máy chủ bằng Docker: docker run -d -p 10300:10300 ghcr.io/luuquangvu/wyoming-vietnamese',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // VieNeu-TTS Vietnamese Neural TTS Section
            _SectionHeader(
              icon: Icons.record_voice_over_rounded,
              title: 'VieNeu-TTS (Sửa phát âm tiếng Việt 48kHz)',
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Giọng đọc nơ-ron VieNeu-TTS',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Sửa phát âm chuẩn các thuật ngữ LED, WS2812, RGB, lux, cảm biến với âm sắc tiếng Việt 48kHz tự nhiên.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _vieneuEnabled,
                        activeColor: AppTheme.accentPurple,
                        onChanged: (v) => setState(() => _vieneuEnabled = v),
                      ),
                    ],
                  ),
                  if (_vieneuEnabled) ...[
                    const Divider(color: AppTheme.borderDark, height: 20),
                    _buildTextField(
                      controller: _vieneuUrlController,
                      label: 'Địa chỉ máy chủ VieNeu-TTS',
                      hint: 'http://192.168.1.100:23333/v1',
                      icon: Icons.link_rounded,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: VieNeuTtsService.availableVoices.contains(_vieneuVoice)
                          ? _vieneuVoice
                          : VieNeuTtsService.availableVoices.first,
                      dropdownColor: AppTheme.surfaceDark,
                      decoration: InputDecoration(
                        labelText: 'Giọng đọc tiếng Việt (3 miền)',
                        prefixIcon: const Icon(
                          Icons.person_pin_rounded,
                          color: AppTheme.accentPurple,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppTheme.borderDark),
                        ),
                      ),
                      items: VieNeuTtsService.availableVoices.map((voice) {
                        return DropdownMenuItem<String>(
                          value: voice,
                          child:
                              Text(voice, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _vieneuVoice = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _vieneuApiKeyController,
                      label: 'API Key (Tùy chọn nếu dùng cloud)',
                      hint: 'Để trống nếu host local',
                      icon: Icons.key_rounded,
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            _isTestingVieNeu ? null : _testVieNeuConnection,
                        icon: _isTestingVieNeu
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.accentPurple,
                                ),
                              )
                            : const Icon(Icons.volume_up_rounded, size: 18),
                        label: Text(
                          _isTestingVieNeu
                              ? 'Đang kiểm tra & đọc thử...'
                              : 'Kiểm tra kết nối & Thử giọng đọc',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentPurple,
                          side: const BorderSide(color: AppTheme.accentPurple),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '💡 Khởi chạy server: docker run --gpus all -p 23333:23333 pnnbao/vieneu-tts:latest\n'
                      '⚡ Tự động sửa phát âm: "LED" -> "đèn lét", "WS2812" -> "đúp-liu...", "lux" -> "lắc". (Nếu server offline sẽ tự lùi về giọng máy nội bộ).',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
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
            const Text(
              'Hỗ trợ tự động xoay vòng 9 model Gemini khi hết quota.',
              style: TextStyle(
                color: AppTheme.accentBlue,
                fontSize: 12,
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
                    'Tích hợp AI Gemini đa model + Wyoming STT + VieNeu-TTS (48kHz).',
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
