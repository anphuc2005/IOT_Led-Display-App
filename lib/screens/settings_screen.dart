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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

    return LiquidBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Cài Đặt Hệ Thống',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
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
              // 3D Liquid Glass Connection status banner
              LiquidGlassCard(
                borderRadius: 18,
                tintColor: mqtt.isConnected ? AppTheme.accentGreen : AppTheme.accentRed,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (mqtt.isConnected ? AppTheme.accentGreen : AppTheme.accentRed)
                            .withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (mqtt.isConnected ? AppTheme.accentGreen : AppTheme.accentRed)
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      child: Icon(
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
                                ? 'Đã kết nối MQTT Broker'
                                : 'Chưa kết nối MQTT',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: mqtt.isConnected
                                  ? AppTheme.accentGreen
                                  : AppTheme.accentRed,
                            ),
                          ),
                          if (mqtt.errorMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                mqtt.errorMessage,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
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
                      title: 'MQTT Broker',
                      color: AppTheme.accentBlue,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _brokerController,
                      label: 'Địa chỉ broker',
                      hint: 'test.mosquitto.org',
                      icon: Icons.dns_rounded,
                      iconColor: AppTheme.accentBlue,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _portController,
                      label: 'Port',
                      hint: '1883',
                      icon: Icons.numbers_rounded,
                      iconColor: AppTheme.accentBlue,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _usernameController,
                      label: 'Username (tùy chọn)',
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
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _topicPrefixController,
                      label: 'Topic prefix',
                      hint: 'smart_led',
                      icon: Icons.topic_rounded,
                      iconColor: AppTheme.accentBlue,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Wyoming Vietnamese Speech-to-Text Card
              LiquidGlassCard(
                borderRadius: 22,
                tintColor: AppTheme.accentCyan,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: _SectionHeader(
                            icon: Icons.mic_external_on_rounded,
                            title: 'Wyoming STT (luuquangvu)',
                            color: AppTheme.accentCyan,
                          ),
                        ),
                        Switch(
                          value: _wyomingEnabled,
                          activeThumbColor: AppTheme.accentCyan,
                          onChanged: (v) => setState(() => _wyomingEnabled = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Model Zipformer tiếng Việt chuyên dụng, kháng ồn tốt, nhận diện giọng 3 miền Bắc/Trung/Nam.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    if (_wyomingEnabled) ...[
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _wyomingHostController,
                        label: 'Địa chỉ Host / IP máy chủ Wyoming',
                        hint: '192.168.1.100 hoặc localhost',
                        icon: Icons.lan_rounded,
                        iconColor: AppTheme.accentCyan,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _wyomingPortController,
                        label: 'Port Wyoming (mặc định 10300)',
                        hint: '10300',
                        icon: Icons.numbers_rounded,
                        iconColor: AppTheme.accentCyan,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
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
                                ? 'Đang kiểm tra kết nối...'
                                : 'Kiểm tra kết nối Wyoming',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.accentCyan,
                            side: BorderSide(
                              color: AppTheme.accentCyan.withValues(alpha: 0.6),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '💡 Docker: docker run -d -p 10300:10300 ghcr.io/luuquangvu/wyoming-vietnamese',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.accentCyan.withValues(alpha: 0.8),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // VieNeu-TTS Vietnamese Neural Card
              LiquidGlassCard(
                borderRadius: 22,
                tintColor: AppTheme.accentPurple,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: _SectionHeader(
                            icon: Icons.record_voice_over_rounded,
                            title: 'VieNeu-TTS (48kHz)',
                            color: AppTheme.accentPurple,
                          ),
                        ),
                        Switch(
                          value: _vieneuEnabled,
                          activeThumbColor: AppTheme.accentPurple,
                          onChanged: (v) => setState(() => _vieneuEnabled = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sửa phát âm chuẩn các thuật ngữ LED, WS2812, RGB, lux, cảm biến với âm sắc tiếng Việt 48kHz tự nhiên.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    if (_vieneuEnabled) ...[
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _vieneuUrlController,
                        label: 'Địa chỉ máy chủ VieNeu-TTS',
                        hint: 'http://192.168.1.100:23333/v1',
                        icon: Icons.link_rounded,
                        iconColor: AppTheme.accentPurple,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: VieNeuTtsService.availableVoices.contains(_vieneuVoice)
                            ? _vieneuVoice
                            : VieNeuTtsService.availableVoices.first,
                        dropdownColor: const Color(0xFF131A2B),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Giọng đọc tiếng Việt (3 miền)',
                          labelStyle: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.person_pin_rounded,
                            color: AppTheme.accentPurple,
                          ),
                          filled: true,
                          fillColor: Colors.black.withValues(alpha: 0.25),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppTheme.accentPurple,
                              width: 1.5,
                            ),
                          ),
                        ),
                        items: VieNeuTtsService.availableVoices.map((voice) {
                          return DropdownMenuItem<String>(
                            value: voice,
                            child: Text(voice),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _vieneuVoice = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _vieneuApiKeyController,
                        label: 'API Key (Tùy chọn)',
                        hint: 'Để trống nếu host nội bộ',
                        icon: Icons.key_rounded,
                        iconColor: AppTheme.accentPurple,
                        obscureText: true,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
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
                                : 'Kiểm tra & Thử giọng đọc',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.accentPurple,
                            side: BorderSide(
                              color: AppTheme.accentPurple.withValues(alpha: 0.6),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '⚡ Tự sửa: "LED" -> "đèn lét", "WS2812" -> "đúp-liu...", "lux" -> "lắc". Tự fallback nếu offline.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.accentPurple.withValues(alpha: 0.8),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Gemini AI Settings Card
              LiquidGlassCard(
                borderRadius: 22,
                tintColor: AppTheme.accentBlue,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(
                      icon: Icons.smart_toy_rounded,
                      title: 'Gemini AI API',
                      color: AppTheme.accentBlue,
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _apiKeyController,
                      label: 'API Key',
                      hint: 'AIzaSy...',
                      icon: Icons.key_rounded,
                      iconColor: AppTheme.accentBlue,
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
                          Icons.autorenew_rounded,
                          size: 15,
                          color: AppTheme.accentCyan,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Tự động xoay vòng 9 model Gemini với phản hồi cực nhanh.',
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
              const SizedBox(height: 20),

              // LED Hardware Settings Card
              LiquidGlassCard(
                borderRadius: 22,
                tintColor: AppTheme.accentOrange,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(
                      icon: Icons.lightbulb_rounded,
                      title: 'Cài Đặt Phần Cứng LED',
                      color: AppTheme.accentOrange,
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _numLedsController,
                      label: 'Số LED trong dải (WS2812)',
                      hint: '30',
                      icon: Icons.linear_scale_rounded,
                      iconColor: AppTheme.accentOrange,
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

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
                    Text(
                      'Lưu Cấu Hình & Kết Nối',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.2,
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
                      Text(
                        'Ngắt Kết Nối MQTT',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),

              // About card
              LiquidGlassCard(
                borderRadius: 18,
                padding: const EdgeInsets.all(16),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart LED 3D Liquid Glass • Tammi Edition',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Hệ thống điều khiển dải đèn thông minh ESP32 & WS2812.\n'
                      'Tích hợp 9 Model Gemini Instant AI + Wyoming STT Tiếng Việt + VieNeu-TTS Neural 48kHz.',
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
        Text(
          title,
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}
