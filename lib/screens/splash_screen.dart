// =============================================================================
// MAKARYA HYBRID ERP — Post-Login Splash Screen (Silver Shimmer WELCOME)
// File: lib/screens/splash_screen.dart
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/makarya_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _ctrl;

  late Animation<double> _shimmerAnim;
  late Animation<double> _textFadeAnim;
  late Animation<double> _textScaleAnim;
  late Animation<double> _exitFadeAnim;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // ── Silver shimmer sweep: W → E (0% to 65%)
    _shimmerAnim = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.65, curve: Curves.easeInOut),
      ),
    );

    // ── Text fade in
    _textFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
      ),
    );

    // ── Text scale (subtle futuristic pop)
    _textScaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.30, curve: Curves.easeOutBack),
      ),
    );

    // ── Exit fade out
    _exitFadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.75, 1.0, curve: Curves.easeIn),
      ),
    );

    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 3100), () {
      if (mounted) {
        context.read<AuthProvider>().dismissSplash();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MakaryaColors.darkEspresso,
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Opacity(
            opacity: _exitFadeAnim.value.clamp(0.0, 1.0),
            child: SizedBox.expand(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // ── Subtle ambient cyan glow (theme accent) ─────────
                  Center(
                    child: Opacity(
                      opacity: 0.10 * _textFadeAnim.value,
                      child: Container(
                        width: 340,
                        height: 160,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              MakaryaColors.woodBrown.withValues(alpha: 0.6),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── WELCOME: Silver shimmer sweep W → E ─────────────
                  Center(
                    child: Transform.scale(
                      scale: _textScaleAnim.value.clamp(0.0, 1.0),
                      alignment: Alignment.center,
                      child: Opacity(
                        opacity: _textFadeAnim.value.clamp(0.0, 1.0),
                        child: _SilverShimmerText(
                          text: 'WELCOME',
                          shimmerProgress: _shimmerAnim.value,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Silver Shimmer Text — Metallic sweep dari kiri (W) ke kanan (E)
// =============================================================================

class _SilverShimmerText extends StatelessWidget {
  final String text;
  final double shimmerProgress;

  const _SilverShimmerText({
    required this.text,
    required this.shimmerProgress,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        final double w = bounds.width;
        final double h = bounds.height;
        final double gWidth = w * 3;

        // Bright center bergerak dari -0.5w (kiri teks) ke 1.5w (kanan teks)
        final double brightCenter =
            (shimmerProgress + 1) / 3 * 2 * w - 0.5 * w;
        final double left = brightCenter - 1.5 * w;

        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Color(0xFF1F2937), // very dark grey
            Color(0xFF4B5563), // dark silver
            Color(0xFF9CA3AF), // mid silver
            Color(0xFFD1D5DB), // bright silver
            Color(0xFFFFFFFF), // white shine peak
            Color(0xFFD1D5DB), // bright silver
            Color(0xFF9CA3AF), // mid silver
            Color(0xFF4B5563), // dark silver
            Color(0xFF1F2937), // very dark grey
          ],
          stops: const [
            0.00,
            0.15,
            0.30,
            0.42,
            0.50,
            0.58,
            0.70,
            0.85,
            1.00,
          ],
        ).createShader(
          Rect.fromLTWH(left, 0, gWidth, h),
        );
      },
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w900,
          fontFamily: 'Inter',
          letterSpacing: 12, // wide tracking = futuristic
          color: Colors.white, // base, di-mask oleh gradient silver
        ),
      ),
    );
  }
}