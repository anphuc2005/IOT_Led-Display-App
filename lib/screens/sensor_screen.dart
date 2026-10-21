import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/app_bloc.dart';
import '../bloc/led_bloc.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class SensorScreen extends StatelessWidget {
  const SensorScreen({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: BlocBuilder<LedBloc, LedBlocState>(
          builder: (context, state) {
            final connected =
                context.select<AppBloc, bool>((bloc) => bloc.state.isConnected);
            final hasData = state.lightHistory.isNotEmpty;
            final stale = hasData &&
                DateTime.now().difference(state.sensor.timestamp) >
                    const Duration(seconds: 10);
            return SingleChildScrollView(
              child: ResponsiveContent(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ScreenHeader(
                        title: 'Cảm biến',
                        subtitle:
                            'Theo dõi ánh sáng và chuyển động theo thời gian thực',
                        trailing: IconButton.filledTonal(
                          tooltip: state.sensorPaused
                              ? 'Tiếp tục cập nhật'
                              : 'Tạm dừng cập nhật',
                          onPressed: () => context
                              .read<LedBloc>()
                              .add(LedSensorPausedChanged(!state.sensorPaused)),
                          icon: Icon(state.sensorPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (state.sensorPaused || stale)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: StatusBanner(
                            icon: state.sensorPaused
                                ? Icons.pause_circle_outline_rounded
                                : Icons.schedule_rounded,
                            title: state.sensorPaused
                                ? 'Đã tạm dừng dữ liệu'
                                : 'Dữ liệu có thể đã cũ',
                            message: state.sensorPaused
                                ? 'Nhấn nút phát để tiếp tục nhận dữ liệu.'
                                : 'Không có bản cập nhật mới trong hơn 10 giây.',
                            color: AppTheme.warning,
                          ),
                        ),
                      LayoutBuilder(builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 640;
                        final cards = [
                          _MetricCard(
                            icon: Icons.light_mode_rounded,
                            label: 'Cường độ sáng',
                            value:
                                '${state.sensor.lightIntensity.toStringAsFixed(0)} lux',
                            description: state.sensor.lightLevel,
                            color: AppTheme.warning,
                          ),
                          _MetricCard(
                            icon: state.sensor.motionDetected
                                ? Icons.directions_run_rounded
                                : Icons.person_outline_rounded,
                            label: 'Chuyển động',
                            value: state.sensor.motionDetected
                                ? 'Đã phát hiện'
                                : 'Không phát hiện',
                            description: state.sensor.motionDetected
                                ? 'Có người trong khu vực'
                                : 'Không gian đang yên tĩnh',
                            color: state.sensor.motionDetected
                                ? AppTheme.accent
                                : Theme.of(context).colorScheme.secondary,
                          ),
                        ];
                        return wide
                            ? Row(children: [
                                Expanded(child: cards[0]),
                                const SizedBox(width: 12),
                                Expanded(child: cards[1])
                              ])
                            : Column(children: [
                                cards[0],
                                const SizedBox(height: 12),
                                cards[1]
                              ]);
                      }),
                      const SizedBox(height: 16),
                      SmartCard(
                        child: Row(children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.auto_mode_rounded,
                                color: Theme.of(context).colorScheme.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('Tự động điều chỉnh',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 2),
                                Text('Độ sáng LED thay đổi theo mức lux',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant)),
                              ])),
                          Switch(
                            value: state.autoMode,
                            onChanged: connected
                                ? (value) => context
                                    .read<LedBloc>()
                                    .add(LedAutoModeChanged(value))
                                : null,
                          ),
                        ]),
                      ),
                      const SizedBox(height: 24),
                      const SectionTitle('Lịch sử ánh sáng'),
                      const SizedBox(height: 12),
                      SmartCard(
                        child: hasData
                            ? SizedBox(
                                height: 240,
                                child: _LightChart(
                                    values: state.lightHistory
                                        .map((item) => item.lightIntensity)
                                        .toList()))
                            : const EmptyPanel(
                                icon: Icons.show_chart_rounded,
                                title: 'Chưa có dữ liệu',
                                message:
                                    'Biểu đồ sẽ xuất hiện sau khi ESP32 gửi dữ liệu cảm biến.',
                              ),
                      ),
                      if (hasData) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Hiện tại ${state.sensor.lightIntensity.toStringAsFixed(0)} lux, mức ${state.sensor.lightLevel.toLowerCase()}. Biểu đồ lưu tối đa 120 mẫu gần nhất.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                        ),
                      ],
                    ]),
              ),
            );
          },
        ),
      );
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String description;
  final Color color;
  const _MetricCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.description,
      required this.color});
  @override
  Widget build(BuildContext context) => SmartCard(
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
                color: color.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(value, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ])),
        ]),
      );
}

class _LightChart extends StatelessWidget {
  final List<double> values;
  const _LightChart({required this.values});
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    final maxValue =
        values.fold<double>(100, (max, value) => value > max ? value : max);
    return Semantics(
      label:
          'Biểu đồ ánh sáng gồm ${values.length} mẫu. Giá trị hiện tại ${values.last.toStringAsFixed(0)} lux.',
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxValue * 1.15,
          gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxValue / 4),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 42)),
          ),
          lineTouchData: const LineTouchData(enabled: true),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var index = 0; index < values.length; index++)
                  FlSpot(index.toDouble(), values[index])
              ],
              isCurved: true,
              color: color,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData:
                  BarAreaData(show: true, color: color.withValues(alpha: .14)),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 200),
      ),
    );
  }
}
