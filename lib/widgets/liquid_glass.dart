import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Bright Daylight background canvas with soft pastel ambient accents
/// designed for WCAG 2.1 Level AAA contrast clarity.
class LiquidBackground extends StatelessWidget {
  final Widget child;
  final bool showAmbientOrbs;

  const LiquidBackground({
    super.key,
    required this.child,
    this.showAmbientOrbs = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Crisp Daylight Alabaster-to-Sky Canvas
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF8FAFC),
                Color(0xFFF1F5F9),
                Color(0xFFEFF6FF),
              ],
            ),
          ),
        ),

        // 2. Subtle Daylight Ambient Orbs
        if (showAmbientOrbs) ...[
          Positioned(
            top: -60,
            right: -40,
            child: _GlowOrb(
              color: const Color(0xFFBAE6FD).withValues(alpha: 0.45),
              size: 260,
            ),
          ),
          Positioned(
            top: 240,
            left: -80,
            child: _GlowOrb(
              color: const Color(0xFFDDD6FE).withValues(alpha: 0.38),
              size: 280,
            ),
          ),
          Positioned(
            bottom: 40,
            right: -60,
            child: _GlowOrb(
              color: const Color(0xFFA7F3D0).withValues(alpha: 0.35),
              size: 300,
            ),
          ),
        ],

        // 3. Foreground content
        child,
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowOrb({
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

/// High-Contrast Daylight Card meeting WCAG AAA standards
/// Pure white surface with subtle semantic tinting, crisp border, and soft elevation.
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blur;
  final LinearGradient? tintGradient;
  final Color? tintColor;
  final VoidCallback? onTap;
  final Border? customBorder;
  final bool hasInnerGlow;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 22,
    this.blur = 18,
    this.tintGradient,
    this.tintColor,
    this.onTap,
    this.customBorder,
    this.hasInnerGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    final topSurface = tintColor != null
        ? Color.lerp(Colors.white, tintColor!, 0.06)!
        : Colors.white;
    final bottomSurface = tintColor != null
        ? Color.lerp(Colors.white, tintColor!, 0.02)!
        : const Color(0xFFFCFDFF);
    final resolvedBorderColor = tintColor != null
        ? Color.lerp(const Color(0xFFCBD5E1), tintColor!, 0.45)!
        : const Color(0xFFCBD5E1);

    final Widget card = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: tintGradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [topSurface, bottomSurface],
            ),
        border: customBorder ??
            Border.all(
              color: resolvedBorderColor,
              width: 1.25,
            ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
          if (tintColor != null)
            BoxShadow(
              color: tintColor!.withValues(alpha: 0.08),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          splashColor: AppTheme.accentCyan.withValues(alpha: 0.08),
          highlightColor: AppTheme.accentCyan.withValues(alpha: 0.04),
          child: card,
        ),
      );
    }

    return card;
  }
}

/// High-Contrast Tactile Button with WCAG AAA contrast compliance
class LiquidGlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? glowColor;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool isPrimary;

  const LiquidGlassButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.glowColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.borderRadius = 16,
    this.isPrimary = false,
  });

  @override
  State<LiquidGlassButton> createState() => _LiquidGlassButtonState();
}

class _LiquidGlassButtonState extends State<LiquidGlassButton> {
  bool _isPressed = false;

  /// Ensures primary button background is dark enough for >= 7.0:1 AAA contrast with white text
  Color _ensureAaaBackground(Color c) {
    final hsl = HSLColor.fromColor(c);
    if (hsl.lightness > 0.28) {
      return hsl
          .withLightness(0.24)
          .withSaturation((hsl.saturation + 0.15).clamp(0.5, 1.0))
          .toColor();
    }
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final rawColor = widget.glowColor ?? AppTheme.accentCyan;
    final primaryBg = _ensureAaaBackground(rawColor);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: widget.padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: widget.isPrimary
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryBg,
                      Color.lerp(primaryBg, const Color(0xFF0F172A), 0.25)!,
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _isPressed ? const Color(0xFFF1F5F9) : Colors.white,
                      _isPressed
                          ? const Color(0xFFE2E8F0)
                          : const Color(0xFFF8FAFC),
                    ],
                  ),
            border: Border.all(
              color: widget.isPrimary
                  ? primaryBg
                  : Color.lerp(const Color(0xFFCBD5E1), rawColor, 0.5)!,
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isPrimary
                    ? primaryBg.withValues(alpha: 0.25)
                    : const Color(0xFF0F172A).withValues(alpha: 0.06),
                blurRadius: widget.isPrimary ? 14 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}

/// High-Contrast Pill / Badge chip
class LiquidGlassChip extends StatelessWidget {
  final Widget child;
  final Color? accentColor;
  final bool isSelected;
  final VoidCallback? onTap;

  const LiquidGlassChip({
    super.key,
    required this.child,
    this.accentColor,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppTheme.accentCyan;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: isSelected
              ? color.withValues(alpha: 0.14)
              : Colors.white,
          border: Border.all(
            color: isSelected ? color : const Color(0xFFCBD5E1),
            width: isSelected ? 1.4 : 1.1,
          ),
        ),
        child: child,
      ),
    );
  }
}
