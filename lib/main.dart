import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/app_bloc.dart';
import 'bloc/chat_bloc.dart';
import 'bloc/led_bloc.dart';
import 'bloc/navigation_bloc.dart';
import 'screens/home_screen.dart';
import 'services/ai_service.dart';
import 'services/mqtt_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartLedApp());
}

class SmartLedApp extends StatelessWidget {
  const SmartLedApp({super.key});

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
        providers: [
          RepositoryProvider(create: (_) => MqttService()),
          RepositoryProvider(create: (_) => AiService()),
          RepositoryProvider(create: (_) => StorageService()),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (context) => AppBloc(
                mqttService: context.read<MqttService>(),
                aiService: context.read<AiService>(),
                storageService: context.read<StorageService>(),
              )..add(const AppStarted()),
            ),
            BlocProvider(
              create: (context) => LedBloc(
                mqttService: context.read<MqttService>(),
                storageService: context.read<StorageService>(),
              ),
            ),
            BlocProvider(create: (_) => NavigationBloc()),
            BlocProvider(
              create: (context) => ChatBloc(
                aiService: context.read<AiService>(),
                ledBloc: context.read<LedBloc>(),
              ),
            ),
          ],
          child: MaterialApp(
            title: 'Smart LED Control',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            home: const _AppGate(),
          ),
        ),
      );
}

class _AppGate extends StatelessWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context) => BlocConsumer<AppBloc, AppState>(
        listenWhen: (previous, current) =>
            current.loadStatus == AppLoadStatus.ready &&
            (previous.loadStatus != AppLoadStatus.ready ||
                previous.config != current.config ||
                previous.autoMode != current.autoMode ||
                previous.numLeds != current.numLeds ||
                (previous.connectionStatus != MqttConnectionStatus.connected &&
                    current.connectionStatus ==
                        MqttConnectionStatus.connected)),
        listener: (context, state) {
          final ledBloc = context.read<LedBloc>();
          ledBloc.add(LedConfigured(state.config,
              autoMode: state.autoMode, numLeds: state.numLeds));
          if (state.connectionStatus == MqttConnectionStatus.connected) {
            ledBloc.add(const LedSyncRequested());
          }
        },
        builder: (context, state) {
          if (state.loadStatus == AppLoadStatus.ready) {
            return const HomeScreen();
          }
          return _StartupScreen(state: state);
        },
      );
}

class _StartupScreen extends StatelessWidget {
  final AppState state;
  const _StartupScreen({required this.state});

  @override
  Widget build(BuildContext context) {
    final failed = state.loadStatus == AppLoadStatus.failure;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(Icons.lightbulb_rounded,
                        size: 44, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 24),
                  Text('Smart LED',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    failed
                        ? state.message ?? 'Không thể khởi tạo ứng dụng.'
                        : 'Đang tải cấu hình và chuẩn bị kết nối…',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 28),
                  if (failed)
                    ElevatedButton.icon(
                      onPressed: () =>
                          context.read<AppBloc>().add(const AppStarted()),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Thử lại'),
                    )
                  else
                    const CircularProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
