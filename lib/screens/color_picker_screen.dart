import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../bloc/app_bloc.dart';
import '../bloc/led_bloc.dart';
import '../widgets/app_widgets.dart';

class ColorPickerScreen extends StatelessWidget {
  const ColorPickerScreen({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: BlocBuilder<LedBloc, LedBlocState>(
          builder: (context, state) {
            final connected =
                context.select<AppBloc, bool>((bloc) => bloc.state.isConnected);
            final rgb = _rgb(state.draftColor);
            return SingleChildScrollView(
              child: ResponsiveContent(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ScreenHeader(
                          title: 'Màu sắc',
                          subtitle:
                              'Chọn sắc độ phù hợp với không gian của bạn'),
                      const SizedBox(height: 20),
                      SmartCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 96,
                            decoration: BoxDecoration(
                              color: state.draftColor,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                    color:
                                        state.draftColor.withValues(alpha: .3),
                                    blurRadius: 20)
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '#${state.draftColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  shadows: [
                                    Shadow(blurRadius: 8, color: Colors.black54)
                                  ]),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ColorPicker(
                            pickerColor: state.draftColor,
                            onColorChanged: (color) => context
                                .read<LedBloc>()
                                .add(LedColorDraftChanged(color)),
                            enableAlpha: false,
                            displayThumbColor: true,
                            portraitOnly: true,
                            pickerAreaHeightPercent: .7,
                            labelTypes: const [],
                          ),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(
                                child: _RgbValue(
                                    label: 'R',
                                    value: rgb.$1,
                                    color: const Color(0xFFEF4444))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _RgbValue(
                                    label: 'G',
                                    value: rgb.$2,
                                    color: const Color(0xFF22C55E))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _RgbValue(
                                    label: 'B',
                                    value: rgb.$3,
                                    color: const Color(0xFF3B82F6))),
                          ]),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: connected
                                  ? () => context
                                      .read<LedBloc>()
                                      .add(const LedColorApplied())
                                  : null,
                              icon: const Icon(Icons.check_rounded),
                              label: Text(connected
                                  ? 'Áp dụng màu'
                                  : 'Cần kết nối MQTT'),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 24),
                      const SectionTitle('Bảng màu gợi ý'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _presets
                            .map((preset) => _ColorPreset(
                                  preset: preset,
                                  selected: state.led.color == preset.color,
                                  enabled: connected,
                                ))
                            .toList(),
                      ),
                    ]),
              ),
            );
          },
        ),
      );

  static (int, int, int) _rgb(Color color) {
    final value = color.toARGB32();
    return ((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF);
  }
}

class _RgbValue extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _RgbValue(
      {required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Text('$value', style: Theme.of(context).textTheme.labelLarge),
        ]),
      );
}

class _Preset {
  final String name;
  final Color color;
  const _Preset(this.name, this.color);
}

const _presets = [
  _Preset('Hoàng hôn', Color(0xFFFF7043)),
  _Preset('Lavender', Color(0xFF9C7CF4)),
  _Preset('Biển đêm', Color(0xFF2563EB)),
  _Preset('Rừng xanh', Color(0xFF16A34A)),
  _Preset('Ánh nến', Color(0xFFFFB464)),
  _Preset('Hồng dịu', Color(0xFFEC4899)),
  _Preset('Băng giá', Color(0xFF67E8F9)),
  _Preset('Trắng', Color(0xFFFFFFFF)),
];

class _ColorPreset extends StatelessWidget {
  final _Preset preset;
  final bool selected;
  final bool enabled;
  const _ColorPreset(
      {required this.preset, required this.selected, required this.enabled});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: 'Màu ${preset.name}',
        child: InkWell(
          onTap: enabled
              ? () => context.read<LedBloc>().add(LedColorApplied(preset.color))
              : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 112,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline),
            ),
            child: Column(children: [
              Container(
                height: 48,
                decoration: BoxDecoration(
                    color: preset.color,
                    borderRadius: BorderRadius.circular(10)),
                child: selected
                    ? const Center(
                        child: Icon(Icons.check_rounded, color: Colors.white))
                    : null,
              ),
              const SizedBox(height: 8),
              Text(preset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium),
            ]),
          ),
        ),
      );
}
