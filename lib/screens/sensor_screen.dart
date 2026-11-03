import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/led_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_glass.dart';

class SensorScreen extends StatelessWidget {
  const SensorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final led = context.watch<LedProvider>();
    final sensor = led.sensorData;
    final history = led.lightHistory;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cảm Biến Realtime',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Theo dõi dữ liệu cảm biến ánh sáng BH1750 & chuyển động PIR từ ESP32',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 22),

            // 3D Liquid Glass Sensor cards row (Light & PIR Motion)
            Row(
              children: [
                Expanded(
                  child: _SensorCard3D(
                    icon: Icons.wb_sunny_rounded,
                    label: 'Ánh sáng phòng',
                    value: '${sensor.lightIntensity.toStringAsFixed(0)} lux',
                    status: sensor.lightLevel,
                    accentColor: AppTheme.accentOrange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SensorCard3D(
                    icon: Icons.directions_walk_rounded,
                    label: 'Chuyển động PIR',
                    value: sensor.motionDetected ? 'Phát hiện' : 'Không có',
                    status: sensor.motionDetected ? 'Có người di chuyển' : 'Không gian tĩnh',
                    accentColor: sensor.motionDetected
                        ? AppTheme.accentGreen
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3D Liquid Glass Climate Sensor cards row (DHT11 Temperature & Humidity)
            Row(
              children: [
                Expanded(
                  child: _SensorCard3D(
                    icon: Icons.thermostat_rounded,
                    label: 'Nhiệt độ DHT11',
                    value: '${sensor.temperature.toStringAsFixed(1)} °C',
                    status: sensor.hasClimate ? 'Cảm biến DHT11 (GPIO 26)' : 'Giá trị mặc định',
                    accentColor: AppTheme.accentRed,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SensorCard3D(
                    icon: Icons.water_drop_rounded,
                    label: 'Độ ẩm không khí',
                    value: '${sensor.humidity.toStringAsFixed(0)} %',
                    status: sensor.hasClimate ? 'Đo trực tiếp từ ESP32' : 'Giá trị mặc định',
                    accentColor: AppTheme.accentBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Auto mode toggle (3D Liquid Glass)
            LiquidGlassCard(
              borderRadius: 24,
              tintColor: led.autoMode ? AppTheme.accentGreen : null,
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: led.autoMode
                          ? AppTheme.accentGreen.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: led.autoMode
                            ? AppTheme.accentGreen.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Icon(
                      Icons.auto_mode_rounded,
                      color: led.autoMode
                          ? AppTheme.accentGreen
                          : AppTheme.textSecondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Chế độ cảm biến thông minh',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          led.autoMode
                              ? 'Tự động chỉnh độ sáng & bật khi có người'
                              : 'Đang tắt tự động (chế độ điều khiển thủ công)',
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
                  Transform.scale(
                    scale: 1.08,
                    child: Switch(
                      value: led.autoMode,
                      onChanged: (v) => led.setAutoMode(v),
                      activeThumbColor: AppTheme.accentGreen,
                      activeTrackColor:
                          AppTheme.accentGreen.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Light intensity chart header
            const Text(
              'Biểu Đồ Cường Độ Ánh Sáng (Lux)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // 3D Liquid Glass Chart Container
            LiquidGlassCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                height: 210,
                child: history.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.show_chart_rounded,
                              color: AppTheme.textTertiary,
                              size: 40,
                            ),
                            SizedBox(height: 10),
                            Flexible(
                              child: Text(
                                'Đang chờ dữ liệu cảm biến từ ESP32...\nHãy kiểm tra kết nối MQTT trong phần Cài đặt',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppTheme.textTertiary,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : LineChart(
                        LineChartData(
                          minY: 0,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 200,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: Colors.white.withValues(alpha: 0.08),
                              strokeWidth: 1,
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
                                reservedSize: 42,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    '${value.toInt()}',
                                    style: const TextStyle(
                                      color: AppTheme.textTertiary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
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
                              preventCurveOverShooting: true,
                              curveSmoothness: 0.35,
                              gradient: AppTheme.sunsetGradient,
                              barWidth: 3,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.accentOrange.withValues(alpha: 0.3),
                                    AppTheme.accentPink.withValues(alpha: 0.0),
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
            ),
            const SizedBox(height: 22),

            // How it works info card (3D Liquid Glass)
            LiquidGlassCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(20),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: AppTheme.accentCyan,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cơ Chế Hoạt Động Cảm Biến',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppTheme.accentCyan,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14),
                  _InfoRow(
                    icon: Icons.wb_sunny_outlined,
                    text: 'Cảm biến BH1750 đo liên tục ánh sáng môi trường thực tế.',
                  ),
                  _InfoRow(
                    icon: Icons.directions_walk_outlined,
                    text: 'Cảm biến hồng ngoại PIR phát hiện chuyển động trong phạm vi 5 mét.',
                  ),
                  _InfoRow(
                    icon: Icons.auto_mode_outlined,
                    text: 'Chế độ Auto tự điều chỉnh độ sáng WS2812 chống mỏi mắt.',
                  ),
                  _InfoRow(
                    icon: Icons.lightbulb_outline,
                    text: 'Tự động thắp sáng khi bước vào phòng và tắt khi không có người.',
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

class _SensorCard3D extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String status;
  final Color accentColor;

  const _SensorCard3D({
    required this.icon,
    required this.label,
    required this.value,
    required this.status,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(16),
      tintColor: accentColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: accentColor.withValues(alpha: 0.18),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.45),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(icon, color: accentColor, size: 19),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor,
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.8),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Live',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: accentColor,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.accentCyan),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
