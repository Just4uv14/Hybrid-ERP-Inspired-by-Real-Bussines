import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/makarya_theme.dart';

/// ============================================
/// GLASSMORPHISM WIDGETS - ENTERPRISE ERP STYLE
/// Inspired by Apple Liquid Glass
/// Compatible: Flutter Web, Android, Windows Desktop
/// ============================================

/// Reusable glass card for Dashboard KPI, Summary cards, Analytics widgets.
/// DO NOT use for: DataTable, Inventory Table, Financial Report, Forms, POS Grid.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double borderRadius;
  final double blurSigma;
  final Color? tintColor;
  final double tintOpacity;
  final BorderSide? borderSide;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final bool animateOnHover;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius = 24.0,
    this.blurSigma = 40.0,
    this.tintColor,
    this.tintOpacity = 0.0,
    this.borderSide,
    this.boxShadow,
    this.onTap,
    this.animateOnHover = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = borderSide ??
        BorderSide(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1.0,
        );

    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(20),
          margin: margin,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (tintColor ?? Colors.white).withValues(alpha: tintColor != null ? 0.15 : 0.06),
                (tintColor ?? Colors.white).withValues(alpha: tintColor != null ? 0.03 : 0.01),
              ],
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.fromBorderSide(effectiveBorder),
            boxShadow: boxShadow ??
                [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                    spreadRadius: -4,
                  ),
                ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      card = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        splashColor: Colors.white.withOpacity(0.05),
        highlightColor: Colors.white.withOpacity(0.03),
        child: card,
      );
    }

    if (animateOnHover && onTap != null) {
      card = _HoverScale(child: card);
    }

    return card;
  }
}

/// General-purpose glass container for wrapping sections, headers, dialogs, modals.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double borderRadius;
  final double blurSigma;
  final Color? tintColor;
  final double tintOpacity;
  final BorderSide? borderSide;
  final BoxConstraints? constraints;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius = 24.0,
    this.blurSigma = 40.0,
    this.tintColor,
    this.tintOpacity = 0.0,
    this.borderSide,
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = borderSide ??
        BorderSide(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1.0,
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          margin: margin,
          constraints: constraints,
          decoration: BoxDecoration(
            color: tintColor, // Allow overriding with solid color
            gradient: tintColor == null ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.06),
                Colors.white.withValues(alpha: 0.01),
              ],
            ) : null,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.fromBorderSide(effectiveBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Glass AppBar / Header wrapper untuk dashboard sections.
class GlassHeader extends StatelessWidget {
  final Widget child;
  final double height;
  final double blurSigma;
  final EdgeInsetsGeometry? padding;

  const GlassHeader({
    super.key,
    required this.child,
    this.height = 72,
    this.blurSigma = 12,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          height: height,
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Glass Sidebar / NavigationRail background.
/// Gunakan ini sebagai background wrapper di sidebar, bukan di setiap item.
class GlassSidebar extends StatelessWidget {
  final Widget child;
  final double width;
  final double blurSigma;

  const GlassSidebar({
    super.key,
    required this.child,
    this.width = 260,
    this.blurSigma = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withOpacity(0.40)
                : Colors.white.withOpacity(0.55),
            border: Border(
              right: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.05),
                width: 1,
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Dialog/Modal dengan glass effect.
class GlassDialog extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final double borderRadius;
  final double blurSigma;

  const GlassDialog({
    super.key,
    required this.child,
    this.maxWidth = 520,
    this.borderRadius = 24,
    this.blurSigma = 16,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.grey.shade900.withOpacity(0.70)
                    : Colors.white.withOpacity(0.75),
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.15)
                      : Colors.black.withOpacity(0.08),
                  width: 1.2,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Hover animation helper untuk desktop/web.
class _HoverScale extends StatefulWidget {
  final Widget child;
  const _HoverScale({required this.child});

  @override
  State<_HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<_HoverScale> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// GLASS BACKGROUND WITH IMAGE — for wallpaper/artistic backgrounds
// Uses a single BackdropFilter at the root level, cards overlay on top.
// Optimized for Flutter Web: image is cached, blur is only on overlay cards.
// ─────────────────────────────────────────────────────────────────────────────

class GlassBackgroundImage extends StatelessWidget {
  final Widget child;
  final String imageAsset;
  final BoxFit fit;
  final Color? overlayColor;
  final double overlayOpacity;

  const GlassBackgroundImage({
    super.key,
    required this.child,
    required this.imageAsset,
    this.fit = BoxFit.cover,
    this.overlayColor,
    this.overlayOpacity = 0.08,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOverlay = overlayColor ?? Colors.black.withValues(alpha: overlayOpacity);

    return Stack(
      children: [
        // Background image
        Positioned.fill(
          child: Image.asset(
            imageAsset,
            fit: fit,
            errorBuilder: (context, error, stackTrace) {
              // Fallback gradient if image fails to load
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      MakaryaColors.darkEspresso,
                      MakaryaColors.surface01,
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Dark overlay for readability (kill noise)
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.75), 
          ),
        ),
        // Ambient Glow 1 (Top Right - Warm Gold/Orange)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.8, -0.8),
                radius: 1.5,
                colors: [
                  const Color(0xFFF59E0B).withValues(alpha: 0.15), // Amber
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Ambient Glow 2 (Bottom Left - Teal/Purple)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.8, 0.8),
                radius: 1.5,
                colors: [
                  const Color(0xFF3B82F6).withValues(alpha: 0.15), // Blue
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Content
        child,
      ],
    );
  }
}
