import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Ambient glowing background mesh with soft blurred light orbs
/// that shine and refract through the Liquid Glass 3D functional layer.
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
        // 1. Deep cosmic obsidian canvas
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF060911),
                Color(0xFF0A0F1D),
                Color(0xFF080C16),
              ],
            ),
          ),
        ),

        // 2. Glowing Ambient Orbs for 3D glass refraction
        if (showAmbientOrbs) ...[
          Positioned(
            top: -60,
            right: -40,
            child: _GlowOrb(
              color: AppTheme.accentCyan.withValues(alpha: 0.18),
              size: 260,
              blurSigma: 80,
            ),
          ),
          Positioned(
            top: 240,
            left: -80,
            child: _GlowOrb(
              color: AppTheme.accentPurple.withValues(alpha: 0.16),
              size: 280,
              blurSigma: 90,
            ),
          ),
          Positioned(
            bottom: 40,
            right: -60,
            child: _GlowOrb(
              color: AppTheme.accentBlue.withValues(alpha: 0.14),
              size: 300,
              blurSigma: 100,
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
  final double blurSigma;

  const _GlowOrb({
    required this.color,
    required this.size,
    required this.blurSigma,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

/// 3D Liquid Glass Card inspired by Tammi & Apple iOS Liquid Glass
/// Features dual-specular bevel borders, tactile depth, backdrop blur,
/// and smooth light refraction.
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
    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: tintGradient ??
                LinearGradient(
                  begin: const Alignment(-0.6, -1.0),
                  end: const Alignment(0.6, 1.0),
                  colors: [
                    tintColor?.withValues(alpha: 0.22) ??
                        Colors.white.withValues(alpha: 0.16),
                    tintColor?.withValues(alpha: 0.08) ??
                        Colors.white.withValues(alpha: 0.05),
                  ],
                ),
            border: customBorder ??
                Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 1.2,
                ),
            boxShadow: [
              // Soft 3D drop shadow
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 22,
                spreadRadius: -2,
                offset: const Offset(0, 10),
              ),
              // Subtle colored specular ambient glow if tinted
              if (tintColor != null)
                BoxShadow(
                  color: tintColor!.withValues(alpha: 0.15),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          splashColor: Colors.white.withValues(alpha: 0.1),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          child: card,
        ),
      );
    }

    return card;
  }
}

/// 3D Tactile Liquid Glass Button with beveled sheen & press animation
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

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.glowColor ?? AppTheme.accentCyan;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
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
                          activeColor.withValues(alpha: 0.85),
                          activeColor.withValues(alpha: 0.60),
                        ],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: _isPressed ? 0.25 : 0.15),
                          Colors.white.withValues(alpha: _isPressed ? 0.12 : 0.06),
                        ],
                      ),
                border: Border.all(
                  color: widget.isPrimary
                      ? Colors.white.withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.25),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.isPrimary
                        ? activeColor.withValues(alpha: 0.40)
                        : Colors.black.withValues(alpha: 0.25),
                    blurRadius: widget.isPrimary ? 16 : 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Liquid Glass Pill / Badge chip
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.35),
                        color.withValues(alpha: 0.15),
                      ],
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.04),
                      ],
                    ),
              border: Border.all(
                color: isSelected
                    ? color.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.18),
                width: 1.1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
