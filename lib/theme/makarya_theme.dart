// =============================================================================
// MAKARYA HYBRID ERP — TRUE GLASSMORPHISM THEME (Refactored)
// File: lib/theme/makarya_theme.dart
// =============================================================================
// REFACTOR NOTES:
// - GlassPanel now delegates to GlassContainer (glass_widgets.dart).
// - MetricCard refactored to use GlassCard base with enterprise styling.
// - GlassBackground removed image asset dependency; uses solid gradient
//   to avoid nested BackdropFilter and missing asset crashes on Web.
// - All business logic, color palette, typography — UNCHANGED.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/glass_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COLOR PALETTE
// ─────────────────────────────────────────────────────────────────────────────

abstract final class MakaryaColors {
  // ── Background ────────────────────────────────────────────────────────────
  static const Color darkEspresso = Color(0xFF050508);
  static const Color surface01    = Color(0xFF0A0A0F);
  static const Color surface02    = Color(0xFF12121A);
  static const Color surface03    = Color(0xFF1A1A25);

  // ── True Glass ────────────────────────────────────────────────────────────
  static const Color glassBg       = Color(0x08FFFFFF);   // white 3%
  static const Color glassBorder   = Color(0x18FFFFFF);   // white 9%
  static const Color glassHover    = Color(0x12FFFFFF);   // white 7%
  static const Color iconBg        = Color(0x0AFFFFFF);   // white 4%
  static const Color iconBorder    = Color(0x15FFFFFF);   // white 8%

  // ── Background Blobs (untuk glass effect) ─────────────────────────────────
  static const Color blobCyan    = Color.fromARGB(199, 6, 185, 170);
  static const Color blobPurple  = Color(0xFF8B5CF6);
  static const Color blobBlue    = Color(0xFF3B82F6);

  // ── Accents ───────────────────────────────────────────────────────────────
  static const Color woodBrown    = Color(0xFF06B6D4);
  static const Color woodLight    = Color(0xFF67E8F9);
  static const Color goldAccent   = Color(0xFFF97316);
  static const Color copperAccent = Color(0xFFEA580C);
  static const Color warningAmber = Color(0xFFFBBF24);
  static const Color infoBlue     = Color(0xFF4F8EF7);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color profitGreen  = Color(0xFF34D399);
  static const Color lossRed      = Color(0xFFF87171);
  static const Color concreteGrey = Color(0xFF64748B);

  // ── Category ──────────────────────────────────────────────────────────────
  static const Color categoryCoffee = Color(0xFF06B6D4);
  static const Color categoryFood   = Color(0xFFF97316);
  static const Color categoryBook   = Color(0xFF4F8EF7);
  static const Color categoryMerch  = Color(0xFFA78BFA);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFFFFFFF); // 100% white
  static const Color textSecondary = Color(0xCCFFFFFF); // 80% white
  static const Color textMuted     = Color(0x99FFFFFF); // 60% white
}

// ─────────────────────────────────────────────────────────────────────────────
// RESPONSIVE HELPER
// ─────────────────────────────────────────────────────────────────────────────

class Responsive {
  static bool isMobile(BuildContext context) => 
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) => 
      MediaQuery.of(context).size.width >= 600 && 
      MediaQuery.of(context).size.width < 1200;

  static bool isDesktop(BuildContext context) => 
      MediaQuery.of(context).size.width >= 1200;

  static T value<T>(BuildContext context, {
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    if (isMobile(context)) return mobile;
    if (isTablet(context) && tablet != null) return tablet;
    return desktop;
  }
}

const String _kFontFamily = 'Inter';

// ─────────────────────────────────────────────────────────────────────────────
// THEME BUILDER
// ─────────────────────────────────────────────────────────────────────────────

abstract final class MakaryaTheme {
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: _kFontFamily,

      colorScheme: const ColorScheme.dark(
        brightness:       Brightness.dark,
        primary:          MakaryaColors.woodBrown,
        onPrimary:        Colors.black,
        primaryContainer: MakaryaColors.woodBrown,
        secondary:        MakaryaColors.goldAccent,
        onSecondary:      Colors.black,
        surface:          MakaryaColors.surface01,
        onSurface:        MakaryaColors.textPrimary,
        error:            MakaryaColors.lossRed,
        onError:          Colors.white,
      ),

      scaffoldBackgroundColor: MakaryaColors.darkEspresso,

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: MakaryaColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily:  _kFontFamily,
          fontSize:    18,
          fontWeight:  FontWeight.w600,
          color:       MakaryaColors.textPrimary,
          letterSpacing: -0.5,
        ),
      ),

      cardTheme: CardThemeData(
        color: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
            color: MakaryaColors.glassBorder,
            width: 0.5,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      dividerTheme: DividerThemeData(
        color:     MakaryaColors.surface03,
        thickness: 0.5,
        space:     0,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled:         true,
        fillColor:      MakaryaColors.surface03,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: MakaryaColors.woodBrown.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MakaryaColors.woodBrown, width: 1.5),
        ),
        hintStyle: const TextStyle(
          color:      MakaryaColors.textMuted,
          fontSize:   14,
          fontFamily: _kFontFamily,
        ),
        labelStyle: const TextStyle(
          color:      MakaryaColors.textSecondary,
          fontSize:   14,
          fontFamily: _kFontFamily,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MakaryaColors.goldAccent.withValues(alpha: 0.2), // primary button opacity 20%
          foregroundColor: Colors.white,
          elevation:       8, // glow effect
          shadowColor:     MakaryaColors.goldAccent.withValues(alpha: 0.4), // glow tipis oranye
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24), 
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 1.2),
          ),
          textStyle: const TextStyle(
            fontFamily:   _kFontFamily,
            fontSize:     14,
            fontWeight:   FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.15), // secondary button glass biasa
          foregroundColor: Colors.white,
          elevation:       0, // tanpa glow
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: const TextStyle(
            fontFamily: _kFontFamily,
            fontSize:   14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MakaryaColors.woodLight,
          textStyle: const TextStyle(
            fontFamily: _kFontFamily,
            fontSize:   14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      textTheme: const TextTheme(
        displayLarge:   TextStyle(color: MakaryaColors.textPrimary,   fontFamily: _kFontFamily, fontWeight: FontWeight.w700, letterSpacing: -2),
        displayMedium:  TextStyle(color: MakaryaColors.textPrimary,   fontFamily: _kFontFamily, fontWeight: FontWeight.w700, letterSpacing: -1.5),
        displaySmall:   TextStyle(color: MakaryaColors.textPrimary,   fontFamily: _kFontFamily, fontWeight: FontWeight.w700, letterSpacing: -1),
        headlineLarge:  TextStyle(color: MakaryaColors.textPrimary,   fontFamily: _kFontFamily, fontWeight: FontWeight.w600, letterSpacing: -0.5),
        headlineMedium: TextStyle(color: MakaryaColors.textPrimary,   fontFamily: _kFontFamily, fontWeight: FontWeight.w600),
        headlineSmall:  TextStyle(color: MakaryaColors.textPrimary,   fontFamily: _kFontFamily, fontWeight: FontWeight.w600),
        titleLarge:     TextStyle(color: MakaryaColors.textPrimary,   fontFamily: _kFontFamily, fontWeight: FontWeight.w600, fontSize: 16),
        titleMedium:    TextStyle(color: MakaryaColors.textPrimary,   fontFamily: _kFontFamily, fontWeight: FontWeight.w500, fontSize: 14),
        titleSmall:     TextStyle(color: MakaryaColors.textSecondary, fontFamily: _kFontFamily, fontWeight: FontWeight.w500, fontSize: 12),
        bodyLarge:      TextStyle(color: MakaryaColors.textPrimary,   fontFamily: _kFontFamily, fontSize: 15),
        bodyMedium:     TextStyle(color: MakaryaColors.textPrimary,   fontFamily: _kFontFamily, fontSize: 14),
        bodySmall:      TextStyle(color: MakaryaColors.textSecondary, fontFamily: _kFontFamily, fontSize: 12),
        labelLarge:     TextStyle(color: MakaryaColors.textPrimary,   fontFamily: _kFontFamily, fontWeight: FontWeight.w600, fontSize: 14),
        labelMedium:    TextStyle(color: MakaryaColors.textSecondary, fontFamily: _kFontFamily, fontSize: 12),
        labelSmall:     TextStyle(color: MakaryaColors.textMuted,     fontFamily: _kFontFamily, fontSize: 11, letterSpacing: 0.5),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: MakaryaColors.surface02,
        labelStyle: const TextStyle(
          fontFamily: _kFontFamily,
          fontSize:   12,
          color:      MakaryaColors.textSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: MakaryaColors.woodBrown.withValues(alpha: 0.3), width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      tabBarTheme: const TabBarThemeData(
        labelColor:           MakaryaColors.woodLight,
        unselectedLabelColor: MakaryaColors.textMuted,
        indicatorColor:       MakaryaColors.woodBrown,
        labelStyle: TextStyle(
          fontFamily: _kFontFamily,
          fontSize:   13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: _kFontFamily,
          fontSize:   13,
          fontWeight: FontWeight.w400,
        ),
      ),

      listTileTheme: const ListTileThemeData(
        tileColor:      Colors.transparent,
        textColor:      MakaryaColors.textPrimary,
        iconColor:      MakaryaColors.concreteGrey,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color:            MakaryaColors.woodBrown,
        linearTrackColor: MakaryaColors.surface02,
      ),

      iconTheme: const IconThemeData(
        color: MakaryaColors.concreteGrey,
        size:  20,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GLASS PANEL — delegates to canonical GlassContainer
// ─────────────────────────────────────────────────────────────────────────────

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final double borderRadius;
  final bool showShimmer;        // kept for API compatibility; ignored
  final bool accentBorderLeft;
  final Color? accentBorderColor;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.borderRadius     = 20,
    this.showShimmer      = true,
    this.accentBorderLeft = false,
    this.accentBorderColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    if (accentBorderLeft) {
      content = Stack(
        children: [
          content,
          Positioned(
            left: 0,
            top:  20,
            bottom: 20,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: (accentBorderColor ?? MakaryaColors.woodBrown).withOpacity(0.7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      );
    }

    return GlassContainer(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(20),
      borderRadius: borderRadius,
      blurSigma: 10,
      child: content,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// METRIC CARD — GlassCard-based with hover & responsive
// ─────────────────────────────────────────────────────────────────────────────

class MetricCard extends StatefulWidget {
  final String label;
  final String value;
  final String? subtitle;
  final String? trend;
  final bool trendUp;
  final IconData? icon;
  final VoidCallback? onTap;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.trend,
    this.trendUp    = true,
    this.icon,
    this.onTap,
  });

  @override
  State<MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<MetricCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    final valueFontSize     = isMobile ? 18.0 : 28.0;
    final labelFontSize     = isMobile ? 10.0 : 13.0;
    final iconContainerSize = isMobile ? 26.0 : 36.0;
    final iconSize          = isMobile ? 13.0 : 18.0;
    final headerSpacing     = isMobile ?  6.0 : 16.0;
    final footerSpacing     = isMobile ?  4.0 : 10.0;
    final trendFontSize     = isMobile ?  9.0 : 11.0;
    final subtitleFontSize  = isMobile ?  9.0 : 11.0;
    final padding           = isMobile ? 12.0 : 20.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit:  (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: GlassCard(
          blurSigma: 10,
          borderRadius: 20,
          padding: EdgeInsets.all(padding),
          animateOnHover: false,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHovered
                    ? const Color(0x25FFFFFF)
                    : Colors.transparent,
                width: 0.5,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.label,
                            style: TextStyle(
                              fontSize: labelFontSize,
                              fontWeight: FontWeight.w500,
                              color: MakaryaColors.textSecondary,
                              fontFamily: _kFontFamily,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (widget.icon != null)
                          Container(
                            width: iconContainerSize,
                            height: iconContainerSize,
                            decoration: BoxDecoration(
                              color: MakaryaColors.iconBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: MakaryaColors.iconBorder,
                                width: 0.5,
                              ),
                            ),
                            child: Icon(
                              widget.icon,
                              size: iconSize,
                              color: MakaryaColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: headerSpacing),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.value,
                        style: TextStyle(
                          fontSize: valueFontSize,
                          fontWeight: FontWeight.w700,
                          color: MakaryaColors.textPrimary,
                          fontFamily: _kFontFamily,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: footerSpacing),
                    Row(
                      children: [
                        if (widget.trend != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: (widget.trendUp
                                      ? MakaryaColors.profitGreen
                                      : MakaryaColors.lossRed)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.trendUp
                                      ? Icons.arrow_upward_rounded
                                      : Icons.arrow_downward_rounded,
                                  size: trendFontSize,
                                  color: widget.trendUp
                                      ? MakaryaColors.profitGreen
                                      : MakaryaColors.lossRed,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  widget.trend!,
                                  style: TextStyle(
                                    fontSize: trendFontSize,
                                    fontWeight: FontWeight.w600,
                                    color: widget.trendUp
                                        ? MakaryaColors.profitGreen
                                        : MakaryaColors.lossRed,
                                    fontFamily: _kFontFamily,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (widget.subtitle != null)
                          Expanded(
                            child: Text(
                              widget.subtitle!,
                              style: TextStyle(
                                fontSize: subtitleFontSize,
                                color: MakaryaColors.textMuted,
                                fontFamily: _kFontFamily,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GLASS BACKGROUND — solid gradient, no image asset / blur
// ─────────────────────────────────────────────────────────────────────────────

class GlassBackground extends StatelessWidget {
  final Widget child;
  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MakaryaColors.darkEspresso,
            MakaryaColors.surface01,
          ],
        ),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIVE STATUS BADGE
// ─────────────────────────────────────────────────────────────────────────────

class LiveStatusBadge extends StatefulWidget {
  final String label;
  final bool connected;
  final String? detail;

  const LiveStatusBadge({
    super.key,
    required this.label,
    required this.connected,
    this.detail,
  });

  @override
  State<LiveStatusBadge> createState() => _LiveStatusBadgeState();
}

class _LiveStatusBadgeState extends State<LiveStatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor =
        widget.connected ? MakaryaColors.profitGreen : MakaryaColors.lossRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:  statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Opacity(
              opacity: widget.connected ? _pulseAnim.value : 1.0,
              child: Container(
                width:  6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            widget.label,
            style: TextStyle(
              fontSize:     11,
              fontWeight:   FontWeight.w600,
              color:        statusColor,
              fontFamily:   _kFontFamily,
              letterSpacing: 0.3,
            ),
          ),
          if (widget.detail != null) ...[
            const SizedBox(width: 4),
            Text(
              widget.detail!,
              style: TextStyle(
                fontSize:  10,
                color:     statusColor.withValues(alpha: 0.7),
                fontFamily: _kFontFamily,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize:     15,
                fontWeight:   FontWeight.w600,
                color:        MakaryaColors.textPrimary,
                fontFamily:   _kFontFamily,
                letterSpacing: -0.3,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize:   12,
                  color:      MakaryaColors.textMuted,
                  fontFamily: _kFontFamily,
                ),
              ),
            ],
          ],
        ),
        if (action != null) ...[
          const Spacer(),
          action!,
        ],
      ],
    );
  }
}
