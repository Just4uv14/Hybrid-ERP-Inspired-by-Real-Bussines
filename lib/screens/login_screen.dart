// =============================================================================
// MAKARYA HYBRID ERP — Login Screen (Cyber/Crypto Aesthetic)
// File: lib/screens/login_screen.dart
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/makarya_theme.dart';
import '../widgets/glass_widgets.dart'; // Still using the base glass widgets

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

    _entryCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _idFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _employeeIdCtrl.dispose();
    _pinCtrl.dispose();
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
      _pinCtrl.clear();
      _pinFocus.requestFocus();
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
      backgroundColor: const Color(0xFF0D0E15), // Deep dark background
      body: Stack(
        children: [
          // Background ambient glows (Cyber Aesthetic)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.2,
            right: MediaQuery.of(context).size.width * 0.2,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFE94057).withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.1,
            left: MediaQuery.of(context).size.width * 0.2,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Content
          KeyboardListener(
            focusNode: FocusNode(),
            onKeyEvent: _onKeyEvent,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
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
                        // ── Glass Card ──────────────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.05),
                                blurRadius: 40,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
                          child: GlassCard(
                            blurSigma: 24,
                            tintColor: const Color(0xFF141620), // Darker glass
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.05),
                              width: 1,
                            ),
                            padding: const EdgeInsets.fromLTRB(40, 48, 40, 40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Glowing Avatar
                                Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFF1E293B),
                                        border: Border.all(
                                          color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                                            blurRadius: 24,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.person_rounded,
                                        size: 32,
                                        color: Color(0xFF60A5FA),
                                      ),
                                    ),
                                    Positioned(
                                      top: -10,
                                      left: -10,
                                      child: Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 20,
                                        color: Colors.amberAccent.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),
  
                                // ── Title (Gradient Text) ─────────────────
                                ShaderMask(
                                  shaderCallback: (bounds) => const LinearGradient(
                                    colors: [Colors.white, Color(0xFFFFD1D1)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ).createShader(bounds),
                                  child: const Text(
                                    'Let\'s get you started',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Inter',
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
  
                                // ── Subtitle ──────────────────────────────
                                const Text(
                                  'Silakan masukkan ID Karyawan dan PIN untuk mengakses Makarya ERP.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                    fontFamily: 'Inter',
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 36),
  
                                // ── Employee ID ───────────────────────────
                                _buildTextField(
                                  controller: _employeeIdCtrl,
                                  focusNode: _idFocus,
                                  hint: 'ID Karyawan',
                                  textCapitalization: TextCapitalization.characters,
                                  onSubmitted: (_) => _pinFocus.requestFocus(),
                                  onChanged: (_) => auth.clearError(),
                                ),
                                const SizedBox(height: 20),
  
                                // ── PIN ───────────────────────────────────
                                _buildTextField(
                                  controller: _pinCtrl,
                                  focusNode: _pinFocus,
                                  hint: 'PIN',
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
                                      color: const Color(0xFF64748B),
                                    ),
                                    onPressed: () => setState(
                                        () => _obscurePin = !_obscurePin),
                                  ),
                                ),
                                const SizedBox(height: 16),
  
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
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Lupa PIN?',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 12,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
  
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
                                    height: 52,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(30),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF3B82F6),
                                            Color(0xFF2563EB),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          )
                                        ]
                                      ),
                                      child: ElevatedButton(
                                        onPressed: auth.loading ? null : _onLogin,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(30),
                                          ),
                                          textStyle: const TextStyle(
                                            fontSize: 15,
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
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Text('Next'),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),
  
                                // ── Footer ────────────────────────────────
                                Text(
                                  "Belum punya akun? Hubungi Manager",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: const Color(0xFF64748B),
                                    fontSize: 12,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable capsule input ───────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
    ValueChanged<String>? onSubmitted,
    ValueChanged<String>? onChanged,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ]
      ),
      child: TextField(
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
          color: Colors.white,
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFF475569),
            fontFamily: 'Inter',
            fontSize: 14,
          ),
          filled: true,
          fillColor: const Color(0xFF0F172A), // Very dark slate
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(
              color: Color(0xFF3B82F6),
              width: 1.5,
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          suffixIcon: suffixIcon != null ? Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: suffixIcon,
          ) : null,
          counterText: '',
        ),
      ),
    );
  }

  // ── Error banner ─────────────────────────────────────────────────────────
  Widget _buildError(String message) => Padding(
        key: ValueKey(message),
        padding: const EdgeInsets.only(bottom: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: MakaryaColors.lossRed.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: MakaryaColors.lossRed.withValues(alpha: 0.3),
              width: 1,
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
