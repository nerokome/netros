import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Shared palette: white and light gray with a graphite accent.
abstract final class _Palette {
  static const paper = Colors.white;
  static const mist = Color(0xFFF4F5F7); // page background, input fill
  static const fog = Color(0xFFE6E8EC); // borders, grabber
  static const stone = Color(0xFFA3A8B1); // muted headline line
  static const slate = Color(0xFF5B616B); // secondary text, icons
  static const graphite = Color(0xFF1F2226); // headings, primary button
  static const error = Color(0xFFB4423A);
  static const ok = Color(0xFF2F7A55);
}

enum _Status { idle, loading, success }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  // Entrance sequence: hero text, sheet slide-up, staggered form items.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  // Circular reveal of the success screen.
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );
  late final AnimationController _emailShake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final AnimationController _passwordShake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  bool _started = false;
  bool _obscurePassword = true;
  bool _bioScanning = false;
  _Status _status = _Status.idle;
  String? _emailError;
  String? _passwordError;
  String _signedInAs = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _reveal.dispose();
    _emailShake.dispose();
    _passwordShake.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _showNotConnectedMessage(String action) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$action is not connected yet.')));
  }

  Future<void> _submit() async {
    if (_status != _Status.idle) return;
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    String? emailError;
    if (email.isEmpty) {
      emailError = 'Enter your email address';
    } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      emailError = 'That email address is missing an @ or domain';
    }
    final passwordError = _passwordController.text.length < 8
        ? 'Password must be at least 8 characters'
        : null;

    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
    });
    if (emailError != null) _emailShake.forward(from: 0);
    if (passwordError != null) _passwordShake.forward(from: 0);
    if (emailError != null || passwordError != null) {
      HapticFeedback.mediumImpact();
      return;
    }

    setState(() => _status = _Status.loading);
    // TODO: replace with real authentication.
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _status = _Status.success;
      _signedInAs = email;
    });
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _reveal.forward();
  }

  Future<void> _signInWithBiometrics() async {
    if (_bioScanning || _status != _Status.idle) return;
    HapticFeedback.selectionClick();
    setState(() => _bioScanning = true);
    // TODO: connect real biometrics (e.g. the local_auth package).
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() => _signedInAs = 'Verified with biometrics');
    _reveal.forward();
  }

  Future<void> _backToSignIn() async {
    await _reveal.reverse();
    if (!mounted) return;
    setState(() {
      _status = _Status.idle;
      _bioScanning = false;
      _emailError = null;
      _passwordError = null;
    });
    _emailController.clear();
    _passwordController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _theme(Theme.of(context)),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: _Palette.mist,
          body: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final topInset = MediaQuery.paddingOf(context).top;
                  return Column(
                    children: [
                      Expanded(child: _hero()),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight - topInset - 56,
                        ),
                        child: _sheet(),
                      ),
                    ],
                  );
                },
              ),
              Positioned.fill(child: _successOverlay()),
            ],
          ),
        ),
      ),
    );
  }

  ThemeData _theme(ThemeData base) {
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _Palette.graphite,
        primary: _Palette.graphite,
        surface: _Palette.paper,
        error: _Palette.error,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: _Palette.graphite,
        displayColor: _Palette.graphite,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: _Palette.graphite,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _Palette.graphite,
        behavior: SnackBarBehavior.floating,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero: animated dot field, logo and headline
  // ---------------------------------------------------------------------------

  Widget _hero() {
    return Stack(
      children: [
        const Positioned.fill(child: _DotField()),
        IgnorePointer(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 34),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxHeight < 40)
                    return const SizedBox.shrink();
                  final roomy = constraints.maxHeight > 150;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _enter(0.05, 0.4, const _Logo(), dy: -6),
                      const Spacer(),
                      if (roomy) _headline(),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _headline() {
    const style = TextStyle(
      color: _Palette.graphite,
      fontSize: 34,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.1,
      height: 1.08,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _revealLine(
          0.15,
          0.65,
          const Text('Everything you run,', style: style),
        ),
        _revealLine(
          0.22,
          0.72,
          Text('in one place.', style: style.copyWith(color: _Palette.stone)),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom sheet with the form
  // ---------------------------------------------------------------------------

  Widget _sheet() {
    final slide = _intro.drive(
      CurveTween(curve: const Interval(0.18, 0.7, curve: Curves.easeOutCubic)),
    );
    return AnimatedBuilder(
      animation: slide,
      builder: (context, child) => FractionalTranslation(
        translation: Offset(0, 1 - slide.value),
        child: child,
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: _Palette.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Color(0x2E1F2226),
              blurRadius: 40,
              spreadRadius: -20,
              offset: Offset(0, -12),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 22),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: _form(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form() {
    final busy = _status != _Status.idle;
    double at(int i) => 0.4 + i * 0.05;

    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 5,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: _Palette.fog,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            _enter(
              at(0),
              at(0) + 0.35,
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Sign in to continue to your account.',
                    style: TextStyle(color: _Palette.slate, fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _enter(
              at(1),
              at(1) + 0.35,
              _Shake(
                animation: _emailShake,
                child: TextFormField(
                  controller: _emailController,
                  focusNode: _emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  readOnly: busy,
                  autofillHints: const [AutofillHints.email],
                  onChanged: (_) {
                    if (_emailError != null) setState(() => _emailError = null);
                  },
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                  style: const TextStyle(fontSize: 16),
                  decoration: _inputDecoration(
                    label: 'Email address',
                    error: _emailError,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _enter(
              at(2),
              at(2) + 0.35,
              _Shake(
                animation: _passwordShake,
                child: TextFormField(
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  readOnly: busy,
                  autofillHints: const [AutofillHints.password],
                  onChanged: (_) {
                    if (_passwordError != null) {
                      setState(() => _passwordError = null);
                    }
                  },
                  onFieldSubmitted: (_) => _submit(),
                  style: const TextStyle(fontSize: 16),
                  decoration: _inputDecoration(
                    label: 'Password',
                    error: _passwordError,
                    suffix: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      tooltip: _obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, animation) =>
                            RotationTransition(
                              turns: Tween(
                                begin: 0.85,
                                end: 1.0,
                              ).animate(animation),
                              child: ScaleTransition(
                                scale: animation,
                                child: child,
                              ),
                            ),
                        child: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          key: ValueKey(_obscurePassword),
                          color: _Palette.slate,
                          size: 21,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _enter(
              at(3),
              at(3) + 0.35,
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: busy
                      ? null
                      : () => _showNotConnectedMessage('Password reset'),
                  style: TextButton.styleFrom(
                    foregroundColor: _Palette.graphite,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  child: const Text('Forgot password?'),
                ),
              ),
            ),
            const SizedBox(height: 4),
            _enter(at(4), at(4) + 0.35, _signInButton()),
            const SizedBox(height: 10),
            _enter(at(5), at(5) + 0.35, _biometricButton(busy)),
            const SizedBox(height: 14),
            _enter(
              at(6),
              at(6) + 0.3,
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    "Don't have an account?",
                    style: TextStyle(color: _Palette.slate, fontSize: 14),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => _showNotConnectedMessage('Registration'),
                    style: TextButton.styleFrom(
                      foregroundColor: _Palette.graphite,
                      padding: const EdgeInsets.only(left: 6),
                      minimumSize: const Size(0, 36),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    child: const Text('Create account'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _signInButton() {
    return _PressScale(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        height: 56,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _status == _Status.success ? _Palette.ok : _Palette.graphite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x5C1F2226),
              blurRadius: 22,
              spreadRadius: -12,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: _status == _Status.idle ? _submit : null,
            splashColor: Colors.white24,
            highlightColor: Colors.transparent,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, animation) {
                  final incoming = child.key == ValueKey(_status);
                  final slide = animation.drive(
                    Tween<Offset>(
                      begin: Offset(0, incoming ? 0.8 : -0.8),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutCubic)),
                  );
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: _buttonContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buttonContent() {
    const label = TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
    return switch (_status) {
      _Status.idle => const Text(
        'Sign in',
        key: ValueKey(_Status.idle),
        style: label,
      ),
      _Status.loading => const SizedBox(
        key: ValueKey(_Status.loading),
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
      ),
      _Status.success => const Row(
        key: ValueKey(_Status.success),
        mainAxisSize: MainAxisSize.min,
        children: [
          _AnimatedCheck(color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text('Signed in', style: label),
        ],
      ),
    };
  }

  Widget _biometricButton(bool busy) {
    return _PressScale(
      child: SizedBox(
        height: 54,
        child: OutlinedButton(
          onPressed: busy || _bioScanning ? null : _signInWithBiometrics,
          style: OutlinedButton.styleFrom(
            foregroundColor: _Palette.graphite,
            disabledForegroundColor: _Palette.graphite,
            backgroundColor: _Palette.paper,
            side: const BorderSide(color: _Palette.fog, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ScanIcon(scanning: _bioScanning),
              const SizedBox(width: 10),
              const Text('Sign in with biometrics'),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    String? error,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: 1.5),
    );

    return InputDecoration(
      labelText: label,
      errorText: error,
      suffixIcon: suffix,
      labelStyle: const TextStyle(color: _Palette.slate, fontSize: 16),
      floatingLabelStyle: const TextStyle(
        color: _Palette.graphite,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      // Light gray at rest, white while focused or showing an error.
      fillColor: WidgetStateColor.resolveWith(
        (states) =>
            states.contains(WidgetState.focused) ||
                states.contains(WidgetState.error)
            ? _Palette.paper
            : _Palette.mist,
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      border: border(Colors.transparent),
      enabledBorder: border(Colors.transparent),
      focusedBorder: border(_Palette.graphite),
      errorBorder: border(_Palette.error),
      focusedErrorBorder: border(_Palette.error),
      errorStyle: const TextStyle(
        color: _Palette.error,
        fontSize: 13,
        height: 1.3,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Success screen (circular reveal from the buttons)
  // ---------------------------------------------------------------------------

  Widget _successOverlay() {
    return AnimatedBuilder(
      animation: _reveal,
      builder: (context, _) {
        final t = _reveal.value;
        if (t == 0) return const SizedBox.shrink();
        double phase(double start, Curve curve) =>
            curve.transform(((t - start) / (1 - start)).clamp(0.0, 1.0));
        final badge = phase(0.45, Curves.easeOutBack);
        final text = phase(0.6, Curves.easeOutCubic);

        return ClipPath(
          clipper: _CircleReveal(Curves.easeInOutCubic.transform(t)),
          child: ColoredBox(
            color: _Palette.paper,
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: badge.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.6 + 0.4 * badge,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            color: _Palette.mist,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: badge > 0
                              ? const _AnimatedCheck(
                                  color: _Palette.ok,
                                  size: 32,
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Opacity(
                      opacity: text,
                      child: Transform.translate(
                        offset: Offset(0, 8 * (1 - text)),
                        child: Column(
                          children: [
                            const Text(
                              "You're signed in",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _signedInAs,
                              style: const TextStyle(
                                color: _Palette.slate,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 22),
                            TextButton(
                              onPressed: _backToSignIn,
                              style: TextButton.styleFrom(
                                foregroundColor: _Palette.slate,
                              ),
                              child: const Text('Back to sign in'),
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
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Animation helpers
  // ---------------------------------------------------------------------------

  /// Fades and slides [child] in during [start]–[end] of the intro.
  Widget _enter(double start, double end, Widget child, {double dy = 12}) {
    final a = _intro.drive(
      CurveTween(curve: Interval(start, end, curve: Curves.easeOutCubic)),
    );
    return AnimatedBuilder(
      animation: a,
      builder: (context, child) => Opacity(
        opacity: a.value,
        child: Transform.translate(
          offset: Offset(0, dy * (1 - a.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }

  /// Slides a line of text up from behind a mask.
  Widget _revealLine(double start, double end, Widget child) {
    final a = _intro.drive(
      CurveTween(curve: Interval(start, end, curve: Curves.easeOutCubic)),
    );
    return ClipRect(
      child: AnimatedBuilder(
        animation: a,
        builder: (context, child) => FractionalTranslation(
          translation: Offset(0, 1.05 * (1 - a.value)),
          child: child,
        ),
        child: child,
      ),
    );
  }
}


class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _Palette.graphite,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.hub_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        const Text(
          'Netros',
          style: TextStyle(
            color: _Palette.graphite,
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

/// Shrinks its child slightly while pressed, then springs back.
class _PressScale extends StatefulWidget {
  const _PressScale({required this.child});

  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: Duration(milliseconds: _down ? 90 : 260),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// Horizontal shake driven by [animation] (0 → 1), used on invalid fields.
class _Shake extends StatelessWidget {
  const _Shake({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final v = animation.value;
        final dx = math.sin(v * math.pi * 4) * 6 * (1 - v);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: child,
    );
  }
}

/// Fingerprint icon that turns green and runs a scan line when [scanning].
class _ScanIcon extends StatelessWidget {
  const _ScanIcon({required this.scanning});

  final bool scanning;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: scanning ? _Palette.ok : _Palette.graphite),
            duration: const Duration(milliseconds: 300),
            builder: (context, color, _) =>
                Icon(Icons.fingerprint, size: 24, color: color),
          ),
          if (scanning)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOut,
              builder: (context, v, _) => Positioned(
                left: 0,
                right: 0,
                top: v * 22,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: _Palette.ok,
                    borderRadius: BorderRadius.circular(1),
                    boxShadow: const [
                      BoxShadow(color: Color(0x662F7A55), blurRadius: 6),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A check mark that draws itself in.
class _AnimatedCheck extends StatelessWidget {
  const _AnimatedCheck({required this.color, this.size = 18});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => CustomPaint(
        size: Size.square(size),
        painter: _CheckPainter(progress: v, color: color),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final path = Path()
      ..moveTo(5 * s, 12.5 * s)
      ..lineTo(9.5 * s, 17 * s)
      ..lineTo(19 * s, 7.5 * s);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}

/// Circle that grows from near the bottom of the screen to cover it.
class _CircleReveal extends CustomClipper<Path> {
  _CircleReveal(this.progress);

  final double progress;

  @override
  Path getClip(Size size) {
    final origin = Offset(size.width / 2, size.height * 0.85);
    final maxRadius = Offset(size.width / 2, origin.dy).distance;
    return Path()
      ..addOval(Rect.fromCircle(center: origin, radius: maxRadius * progress));
  }

  @override
  bool shouldReclip(_CircleReveal old) => old.progress != progress;
}

class _DotField extends StatefulWidget {
  const _DotField();

  @override
  State<_DotField> createState() => _DotFieldState();
}

class _DotFieldState extends State<_DotField>
    with SingleTickerProviderStateMixin {
  static const _offscreen = Offset(-9999, -9999);

  late final Ticker _ticker = createTicker(_onTick);
  final _time = ValueNotifier<double>(0);
  Offset _pointer = _offscreen;
  Offset _target = _offscreen;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _time.value = 100; // Fully revealed, static.
    } else {
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    _pointer = Offset.lerp(_pointer, _target, 0.14)!;
    _time.value = elapsed.inMicroseconds / 1e6;
  }

  void _moveTo(Offset position) {
    if (_pointer == _offscreen) _pointer = position;
    _target = position;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => _moveTo(e.localPosition),
      onPointerMove: (e) => _moveTo(e.localPosition),
      onPointerHover: (e) => _moveTo(e.localPosition),
      onPointerUp: (_) => _target = _offscreen,
      onPointerCancel: (_) => _target = _offscreen,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _DotPainter(time: _time, pointer: () => _pointer),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  _DotPainter({required this.time, required this.pointer})
    : super(repaint: time);

  final ValueNotifier<double> time;
  final Offset Function() pointer;

  static const _gap = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final p = pointer();
    final center = Offset(size.width * 0.7, size.height * 0.35);
    final reveal = t * 420; // radial intro sweep, px per second
    final paint = Paint();

    for (var y = _gap / 2; y < size.height; y += _gap) {
      for (var x = _gap / 2; x < size.width; x += _gap) {
        final dot = Offset(x, y);
        final d = (dot - center).distance;
        if (d > reveal) continue;

        final intro = ((reveal - d) / 120).clamp(0.0, 1.0);
        final wave = math.sin(d * 0.02 - t * 1.4) * 0.5 + 0.5;
        final delta = dot - p;
        final dist = delta.distance;
        final near = (1 - dist / 120).clamp(0.0, 1.0);
        final push = near * near * 9;
        final dir = dist == 0 ? Offset.zero : delta / dist;

        final radius = (1 + wave * 0.8 + near * 2.2) * intro;
        final alpha = ((0.16 + wave * 0.16 + near * 0.5) * intro).clamp(
          0.0,
          1.0,
        );
        paint.color = Color.fromRGBO(91, 97, 107, alpha);
        canvas.drawCircle(dot + dir * push, radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) => false; // Driven by [time].
}
