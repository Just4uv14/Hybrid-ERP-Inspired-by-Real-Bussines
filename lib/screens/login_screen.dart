// =============================================================================
// MAKARYA HYBRID ERP — Login Screen (Glassmorphism + Animated Bear)
// File: lib/screens/login_screen.dart
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/makarya_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BEAR STATE
// ─────────────────────────────────────────────────────────────────────────────

enum BearState { idle, peek, cover, angry, happy }

// ─────────────────────────────────────────────────────────────────────────────
// LOGIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _employeeIdCtrl = TextEditingController();
  final _pinCtrl        = TextEditingController();
  final _idFocus        = FocusNode();
  final _pinFocus       = FocusNode();

  bool _obscurePin = true;
  BearState _bearState = BearState.idle;

  late AnimationController _entryCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<double>   _scaleAnim;

  late AnimationController _shakeCtrl;
  late Animation<double>   _shakeAnim;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    );
    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.1, 0.9, curve: Curves.easeOutBack),
      ),
    );

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 10).chain(
      CurveTween(curve: Curves.elasticIn),
    ).animate(_shakeCtrl);

    _idFocus.addListener(_onFocusChange);
    _pinFocus.addListener(_onFocusChange);

    _entryCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _idFocus.requestFocus();
    });
  }

  void _onFocusChange() {
    setState(() {
      if (_pinFocus.hasFocus) {
        _bearState = BearState.cover;
      } else if (_idFocus.hasFocus) {
        _bearState = BearState.peek;
      } else {
        _bearState = BearState.idle;
      }
    });
  }

  @override
  void dispose() {
    _employeeIdCtrl.dispose();
    _pinCtrl.dispose();
    _idFocus.removeListener(_onFocusChange);
    _pinFocus.removeListener(_onFocusChange);
    _idFocus.dispose();
    _pinFocus.dispose();
    _entryCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    HapticFeedback.lightImpact();

    final id  = _employeeIdCtrl.text.trim();
    final pin = _pinCtrl.text.trim();

    if (id.isEmpty || pin.length < 4) {
      _shakeCtrl.forward(from: 0);
      return;
    }

    final rawId = id.toUpperCase().replaceAll(' ', '');
    final auth  = context.read<AuthProvider>();
    final ok    = await auth.login(rawId, pin);

    if (!ok && mounted) {
      _shakeCtrl.forward(from: 0);
      setState(() => _bearState = BearState.angry);
      _pinCtrl.clear();
      _pinFocus.requestFocus();
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && _bearState == BearState.angry) {
          setState(() => _bearState = BearState.cover);
        }
      });
    }
  }

  void _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _onLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackground(
        child: KeyboardListener(
          focusNode: FocusNode(),
          onKeyEvent: _onKeyEvent,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: AnimatedBuilder(
                  animation: _entryCtrl,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnim,
                      child: ScaleTransition(
                        scale: _scaleAnim,
                        child: child,
                      ),
                    );
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      // ── Bear di atas card (BESAR) ───────────────────
                      Positioned(
                        top: -90,
                        child: MakaryaBear(state: _bearState),
                      ),

                      // ── Glass Card ──────────────────────────────────
                      GlassPanel(
                        borderRadius: 24,
                        showShimmer: true,
                        padding: const EdgeInsets.fromLTRB(32, 64, 32, 40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 12),

                            // ── Title ─────────────────────────────────
                            const Text(
                              'Masuk',
                              style: TextStyle(
                                color: MakaryaColors.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Inter',
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // ── Subtitle ──────────────────────────────
                            Text(
                              'Silakan masukkan detail Anda untuk masuk.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: MakaryaColors.textMuted,
                                fontSize: 12,
                                fontFamily: 'Inter',
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 28),

                            // ── Employee ID ───────────────────────────
                            _buildTextField(
                              controller: _employeeIdCtrl,
                              focusNode: _idFocus,
                              hint: 'ID Karyawan (contoh: EMP-001)',
                              icon: Icons.badge_outlined,
                              textCapitalization: TextCapitalization.characters,
                              onSubmitted: (_) => _pinFocus.requestFocus(),
                              onChanged: (_) => auth.clearError(),
                            ),
                            const SizedBox(height: 16),

                            // ── PIN ───────────────────────────────────
                            _buildTextField(
                              controller: _pinCtrl,
                              focusNode: _pinFocus,
                              hint: 'PIN (4 digit)',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscurePin,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              onSubmitted: (_) => _onLogin(),
                              onChanged: (_) => auth.clearError(),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePin
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                  color: MakaryaColors.textMuted,
                                ),
                                onPressed: () => setState(
                                    () => _obscurePin = !_obscurePin),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // ── Lupa PIN ──────────────────────────────
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Hubungi Manager untuk reset PIN.'),
                                      backgroundColor: MakaryaColors.surface03,
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 32),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Lupa PIN?',
                                  style: TextStyle(
                                    color: MakaryaColors.woodLight,
                                    fontSize: 11,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ── Error message ─────────────────────────
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: auth.errorMessage != null
                                  ? _buildError(auth.errorMessage!)
                                  : const SizedBox.shrink(
                                      key: ValueKey('no-error')),
                            ),

                            // ── Tombol Masuk ──────────────────────────
                            AnimatedBuilder(
                              animation: _shakeAnim,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(
                                    _shakeAnim.value *
                                        (_shakeCtrl.value < 0.5 ? 1 : -1),
                                    0,
                                  ),
                                  child: child,
                                );
                              },
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: auth.loading ? null : _onLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor:
                                        MakaryaColors.darkEspresso,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                  child: auth.loading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: MakaryaColors.darkEspresso,
                                          ),
                                        )
                                      : const Text('Masuk'),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // ── Footer ────────────────────────────────
                            Text(
                              "Belum punya akun? Hubungi Manager",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: MakaryaColors.textMuted,
                                fontSize: 11,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Reusable glass input ─────────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
    ValueChanged<String>? onSubmitted,
    ValueChanged<String>? onChanged,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      textInputAction: TextInputAction.next,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      style: const TextStyle(
        color: MakaryaColors.textPrimary,
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: MakaryaColors.textMuted,
          fontFamily: 'Inter',
          fontSize: 13,
        ),
        filled: true,
        fillColor: MakaryaColors.surface02,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: MakaryaColors.glassBorder,
            width: 0.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: MakaryaColors.woodBrown,
            width: 1.5,
          ),
        ),
        prefixIcon: Icon(icon, size: 18, color: MakaryaColors.textMuted),
        suffixIcon: suffixIcon,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        counterText: '',
      ),
    );
  }

  // ── Error banner ─────────────────────────────────────────────────────────
  Widget _buildError(String message) => Padding(
        key: ValueKey(message),
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: MakaryaColors.lossRed.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: MakaryaColors.lossRed.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 16,
                color: MakaryaColors.lossRed,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: MakaryaColors.lossRed,
                    fontSize: 12,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

// =============================================================================
// MAKARYA BEAR — Animated bear widget (pure Flutter, no assets)
// =============================================================================

class MakaryaBear extends StatelessWidget {
  final BearState state;
  const MakaryaBear({super.key, required this.state});

  static const _furDark   = Color(0xFF6B4F1E);
  static const _furLight  = Color(0xFFC4A265);
  static const _furMedium = Color(0xFF8B6914);
  static const _nose      = Color(0xFF2D1F0E);

  bool get _isCover => state == BearState.cover;
  bool get _isAngry => state == BearState.angry;
  bool get _isHappy => state == BearState.happy;
  bool get _isPeek  => state == BearState.peek;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // ── Ears ──────────────────────────────────────────────────────
          Positioned(
            top: 4,
            left: 22,
            child: _ear(),
          ),
          Positioned(
            top: 4,
            right: 22,
            child: _ear(),
          ),

          // ── Head ──────────────────────────────────────────────────────
          Container(
            width: 120,
            height: 110,
            decoration: const BoxDecoration(
              color: _furDark,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(56),
                topRight: Radius.circular(56),
                bottomLeft: Radius.circular(48),
                bottomRight: Radius.circular(48),
              ),
            ),
          ),

          // ── Snout ─────────────────────────────────────────────────────
          Positioned(
            bottom: 18,
            child: Container(
              width: 56,
              height: 38,
              decoration: BoxDecoration(
                color: _furLight,
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),

          // ── Nose ──────────────────────────────────────────────────────
          Positioned(
            bottom: 36,
            child: Container(
              width: 18,
              height: 12,
              decoration: BoxDecoration(
                color: _nose,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

          // ── Mouth ─────────────────────────────────────────────────────
          Positioned(
            bottom: 22,
            child: _mouth(),
          ),

          // ── Eyes ──────────────────────────────────────────────────────
          if (!_isCover) ...[
            Positioned(
              top: 42,
              left: 34,
              child: _eye(isLeft: true),
            ),
            Positioned(
              top: 42,
              right: 34,
              child: _eye(isLeft: false),
            ),
          ],

          // ── Eyebrows (angry only) ─────────────────────────────────────
          if (_isAngry) ...[
            Positioned(
              top: 32,
              left: 32,
              child: Transform.rotate(
                angle: 0.5,
                child: _eyebrow(),
              ),
            ),
            Positioned(
              top: 32,
              right: 32,
              child: Transform.rotate(
                angle: -0.5,
                child: _eyebrow(),
              ),
            ),
          ],

          // ── Paws (animated) ───────────────────────────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            top: _isCover ? 32 : 72,
            left: 26,
            child: _paw(),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            top: _isCover ? 32 : 72,
            right: 26,
            child: _paw(),
          ),
        ],
      ),
    );
  }

  // ── Ear ──────────────────────────────────────────────────────────────────
  Widget _ear() => Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: _furDark,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: _furLight,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );

  // ── Eye ──────────────────────────────────────────────────────────────────
  Widget _eye({required bool isLeft}) {
    final pupilOffset = _isPeek
        ? (isLeft ? const Offset(3, -1) : const Offset(-3, -1))
        : _isAngry
            ? (isLeft ? const Offset(4, 2) : const Offset(-4, 2))
            : _isHappy
                ? (isLeft ? const Offset(0, -2) : const Offset(0, -2))
                : Offset.zero;

    return Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 14,
          height: _isHappy ? 5 : 14,
          margin: EdgeInsets.only(
            left: pupilOffset.dx + 5,
            top: pupilOffset.dy + 5,
          ),
          decoration: BoxDecoration(
            color: _isHappy ? _furDark : _nose,
            borderRadius: _isHappy
                ? BorderRadius.circular(5)
                : BorderRadius.circular(7),
          ),
        ),
      ),
    );
  }

  // ── Eyebrow ──────────────────────────────────────────────────────────────
  Widget _eyebrow() => Container(
        width: 18,
        height: 5,
        decoration: BoxDecoration(
          color: _nose,
          borderRadius: BorderRadius.circular(3),
        ),
      );

  // ── Mouth ────────────────────────────────────────────────────────────────
  Widget _mouth() {
    if (_isAngry) {
      return Container(
        width: 20,
        height: 10,
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: _nose, width: 2.5),
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
          ),
        ),
      );
    }
    if (_isHappy) {
      return Container(
        width: 20,
        height: 10,
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: _nose, width: 2.5),
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
        ),
      );
    }
    return Container(
      width: 16,
      height: 8,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _nose, width: 2),
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
    );
  }

  // ── Paw ──────────────────────────────────────────────────────────────────
  Widget _paw() => Container(
        width: 30,
        height: 24,
        decoration: BoxDecoration(
          color: _furMedium,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            3,
            (i) => Container(
              width: 5,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: _furLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      );
}
