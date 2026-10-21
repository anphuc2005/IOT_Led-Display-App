import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/led_provider.dart';
import '../theme/app_theme.dart';

class SensorScreen extends StatelessWidget {
  const SensorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final led = context.watch<LedProvider>();
    final sensor = led.sensorData;
    final history = led.lightHistory;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cảm Biến',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Dữ liệu realtime từ ESP32',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),

            // Sensor cards row
            Row(
              children: [
                Expanded(
                  child: _SensorInfoCard(
                    icon: Icons.wb_sunny_rounded,
                    label: 'Ánh sáng',
                    value: '${sensor.lightIntensity.toStringAsFixed(0)} lux',
                    status: sensor.lightLevel,
                    color: AppTheme.accentOrange,
                    gradient: AppTheme.warmGradient,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SensorInfoCard(
                    icon: Icons.directions_walk_rounded,
                    label: 'Chuyển động',
                    value: sensor.motionDetected ? 'Phát hiện' : 'Không',
                    status: sensor.motionDetected ? 'Có người' : 'Không có',
                    color: sensor.motionDetected
                        ? AppTheme.accentGreen
                        : AppTheme.textSecondary,
                    gradient: sensor.motionDetected
                        ? AppTheme.cyanGradient
                        : const LinearGradient(
                            colors: [
                              AppTheme.textTertiary,
                              AppTheme.textSecondary,
                            ],
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Auto mode toggle
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: led.autoMode
                    ? LinearGradient(
                        colors: [
                          AppTheme.accentGreen.withOpacity(0.1),
                          AppTheme.accentCyan.withOpacity(0.1),
                        ],
                      )
                    : null,
                color: led.autoMode ? null : AppTheme.cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: led.autoMode
                      ? AppTheme.accentGreen.withOpacity(0.3)
                      : AppTheme.borderDark,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: led.autoMode
                          ? AppTheme.accentGreen.withOpacity(0.15)
                          : AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.auto_mode_rounded,
                      color: led.autoMode
                          ? AppTheme.accentGreen
                          : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Chế độ tự động',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          led.autoMode
                              ? 'Tự chỉnh sáng theo ánh sáng & chuyển động'
                              : 'Bật để tự động điều chỉnh',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: led.autoMode,
                    onChanged: (v) => led.setAutoMode(v),
                    activeColor: AppTheme.accentGreen,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Light intensity chart
            Text(
              'Biểu đồ cường độ ánh sáng',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderDark),
              ),
              child: history.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.show_chart_rounded,
                            color: AppTheme.textTertiary,
                            size: 40,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Chưa có dữ liệu\nKết nối ESP32 để nhận dữ liệu',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 200,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: AppTheme.borderDark,
                            strokeWidth: 0.5,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '${value.toInt()}',
                                  style: const TextStyle(
                                    color: AppTheme.textTertiary,
                                    fontSize: 10,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: history
                                .asMap()
                                .entries
                                .map((e) => FlSpot(
                                      e.key.toDouble(),
                                      e.value.lightIntensity,
                                    ))
                                .toList(),
                            isCurved: true,
                            gradient: AppTheme.warmGradient,
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.accentOrange.withOpacity(0.2),
                                  AppTheme.accentOrange.withOpacity(0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 24),

            // How it works
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.accentBlue),
                      SizedBox(width: 8),
                      Text(
                        'Cách hoạt động',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.wb_sunny_outlined,
                    text: 'Cảm biến ánh sáng đo cường độ ánh sáng (lux)',
                  ),
                  _InfoRow(
                    icon: Icons.directions_walk_outlined,
                    text: 'Cảm biến PIR phát hiện chuyển động',
                  ),
                  _InfoRow(
                    icon: Icons.auto_mode_outlined,
                    text: 'Chế độ tự động: Điều chỉnh sáng theo môi trường',
                  ),
                  _InfoRow(
                    icon: Icons.lightbulb_outline,
                    text: 'Tự bật đèn khi phát hiện chuyển động (tự động)',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SensorInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String status;
  final Color color;
  final LinearGradient gradient;

  const _SensorInfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.status,
    required this.color,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient.colors
              .map((c) => c.withOpacity(0.1))
              .toList(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            status,
            style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
