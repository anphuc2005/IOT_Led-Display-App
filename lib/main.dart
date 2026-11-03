import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/mqtt_service.dart';
import 'services/ai_service.dart';
import 'services/storage_service.dart';
import 'services/vieneu_tts_service.dart';
import 'providers/led_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.surfaceDark,
    ),
  );
  runApp(const SmartLedApp());
}

class SmartLedApp extends StatelessWidget {
  const SmartLedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MqttService()),
        ChangeNotifierProvider(create: (_) => AiService()),
        Provider(create: (_) => StorageService()),
        Provider(
          create: (_) => VieNeuTtsService(),
          dispose: (_, service) => service.dispose(),
        ),
        ChangeNotifierProxyProvider<MqttService, LedProvider>(
          create: (context) => LedProvider(context.read<MqttService>()),
          update: (_, mqtt, led) => led!,
        ),
      ],
      child: MaterialApp(
        title: 'Smart LED Control',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const _AppInitializer(),
      ),
    );
  }
}

class _AppInitializer extends StatefulWidget {
  const _AppInitializer();

  @override
  State<_AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<_AppInitializer>
    with SingleTickerProviderStateMixin {
  bool _initialized = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _initApp();
  }

  Future<void> _initApp() async {
    final storage = context.read<StorageService>();
    final mqtt = context.read<MqttService>();
    final ai = context.read<AiService>();

    // Load saved settings quickly from local storage
    final config = await storage.loadMqttConfig();
    final apiKey = await storage.loadGeminiApiKey();

    mqtt.updateConfig(config);
    ai.setApiKey(apiKey);

    // Enter HomeScreen immediately without waiting for MQTT network timeout
    if (mounted) {
      setState(() => _initialized = true);
      _fadeController.forward();
    }

    // Connect to MQTT in the background
    unawaited(mqtt.connect());
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Scaffold(
        backgroundColor: AppTheme.primaryDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentBlue.withValues(alpha: 0.3),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lightbulb_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Smart LED',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: const HomeScreen(),
    );
  }
}
