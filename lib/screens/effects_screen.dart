import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/app_bloc.dart';
import '../bloc/led_bloc.dart';
import '../models/led_state.dart';
import '../widgets/app_widgets.dart';

class EffectsScreen extends StatelessWidget {
  const EffectsScreen({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: BlocBuilder<LedBloc, LedBlocState>(
          builder: (context, state) {
            final connected =
                context.select<AppBloc, bool>((bloc) => bloc.state.isConnected);
            return SingleChildScrollView(
              child: ResponsiveContent(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ScreenHeader(
                          title: 'Hiệu ứng',
                          subtitle:
                              'Tạo chuyển động ánh sáng phù hợp với từng khoảnh khắc'),
                      const SizedBox(height: 20),
                      StatusBanner(
                        icon: state.led.effect.icon,
                        title: state.led.effect.displayName,
                        message: state.led.effect.description,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(height: 20),
                      SmartCard(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.speed_rounded),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text('Tốc độ hiệu ứng',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium)),
                                Text('${state.led.effectSpeed} ms',
                                    style:
                                        Theme.of(context).textTheme.labelLarge),
                              ]),
                              const SizedBox(height: 8),
                              Slider(
                                value: state.led.effectSpeed.toDouble(),
                                min: 50,
                                max: 3000,
                                divisions: 59,
                                label: '${state.led.effectSpeed} ms',
                                onChanged: connected
                                    ? (value) => context.read<LedBloc>().add(
                                        LedEffectSpeedPreviewed(value.round()))
                                    : null,
                                onChangeEnd: connected
                                    ? (value) => context.read<LedBloc>().add(
                                        LedEffectSpeedChanged(value.round()))
                                    : null,
                              ),
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Nhanh',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                    Text('Chậm',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                  ]),
                            ]),
                      ),
                      const SizedBox(height: 24),
                      const SectionTitle('Danh sách hiệu ứng'),
                      const SizedBox(height: 12),
                      LayoutBuilder(builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 720 ? 3 : 2;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: LedEffect.values.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: columns == 3 ? 1.6 : 1.25,
                          ),
                          itemBuilder: (context, index) {
                            final effect = LedEffect.values[index];
                            return _EffectCard(
                              effect: effect,
                              selected: state.led.effect == effect,
                              enabled: connected,
                            );
                          },
                        );
                      }),
                    ]),
              ),
            );
          },
        ),
      );
}

class _EffectCard extends StatelessWidget {
  final LedEffect effect;
  final bool selected;
  final bool enabled;
  const _EffectCard(
      {required this.effect, required this.selected, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return Semantics(
      button: true,
      selected: selected,
      label: '${effect.displayName}. ${effect.description}',
      child: SmartCard(
        onTap: enabled
            ? () => context.read<LedBloc>().add(LedEffectChanged(effect))
            : null,
        borderColor: selected ? color : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(effect.icon, color: color),
            ),
            const Spacer(),
            if (selected) Icon(Icons.check_circle_rounded, color: color),
          ]),
          const Spacer(),
          Text(effect.displayName,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(effect.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}
