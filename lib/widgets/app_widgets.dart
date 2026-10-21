import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const ResponsiveContent(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(AppTheme.pagePadding)});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Padding(
              padding: constraints.maxWidth >= 720
                  ? const EdgeInsets.symmetric(horizontal: 32, vertical: 24)
                  : padding,
              child: child,
            ),
          ),
        ),
      );
}

class SmartCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final VoidCallback? onTap;
  const SmartCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.borderColor,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Ink(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
            color: borderColor ?? scheme.outline.withValues(alpha: .6)),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: content),
    );
  }
}

class ScreenHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  const ScreenHeader(
      {super.key, required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      );
}

class StatusBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final Widget? action;
  const StatusBanner(
      {super.key,
      required this.icon,
      required this.title,
      required this.message,
      required this.color,
      this.action});

  @override
  Widget build(BuildContext context) => SmartCard(
        borderColor: color.withValues(alpha: .45),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: color.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ),
          if (action != null) action!,
        ]),
      );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionTitle(this.title, {super.key, this.actionLabel, this.onAction});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ]);
}

class EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const EmptyPanel(
      {super.key,
      required this.icon,
      required this.title,
      required this.message});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(children: [
          Icon(icon,
              size: 42, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      );
}
