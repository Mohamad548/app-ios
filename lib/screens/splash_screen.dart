import 'package:flutter/material.dart';

import '../l10n.dart';
import '../theme.dart';
import '../widgets/aurora_background.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _ready = true);
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _enterHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, _, _) => const HomeScreen(),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce && !_ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_ready) setState(() => _ready = true);
      });
    }

    return Scaffold(
      body: AuroraBackground(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = reduce ? 1.0 : _c.value;
            final ring = AppTheme.splash.transform((t / 0.45).clamp(0.0, 1.0));
            final glyph = AppTheme.splash
                .transform(((t - 0.28) / 0.25).clamp(0.0, 1.0));
            final textT = AppTheme.splash
                .transform(((t - 0.45) / 0.30).clamp(0.0, 1.0));

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    SizedBox(
                      width: 168,
                      height: 168,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: ring,
                            child: Image.asset(
                              'assets/brand/luminous-ring.png',
                              width: 168,
                              height: 168,
                              errorBuilder: (_, _, _) => CustomPaint(
                                size: const Size.square(168),
                                painter: _FallbackRingPainter(
                                  progress: ring,
                                  color: p.tech,
                                ),
                              ),
                            ),
                          ),
                          Opacity(
                            opacity: glyph,
                            child: Image.asset(
                              'assets/brand/relay-glyph.png',
                              width: 88,
                              height: 88,
                              errorBuilder: (_, _, _) => Icon(
                                Icons.settings_input_antenna_rounded,
                                size: 56,
                                color: p.tech,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    Opacity(
                      opacity: textT,
                      child: Transform.translate(
                        offset: Offset(0, 16 * (1 - textT)),
                        child: Column(
                          children: [
                            Text(
                              L10n.welcome,
                              textAlign: TextAlign.center,
                              style: T.welcome(p),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              L10n.subtitle,
                              textAlign: TextAlign.center,
                              style: T.meta(p).copyWith(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(flex: 2),
                    AnimatedOpacity(
                      opacity: _ready ? 1 : textT.clamp(0.0, 0.35),
                      duration: AppTheme.toggle,
                      child: SizedBox(
                        width: double.infinity,
                        height: AppSpace.touch + 4,
                        child: FilledButton(
                          onPressed: _ready ? _enterHome : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: p.tech,
                            disabledBackgroundColor: p.surfaceAlt,
                            foregroundColor: const Color(0xFF04222A),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadii.button),
                            ),
                          ),
                          child: Text(
                            L10n.letsGo,
                            style: T.button(p).copyWith(
                              color: const Color(0xFF04222A),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Opacity(
                      opacity: textT,
                      child: Text(
                        'SIM800 · 4 CHANNEL',
                        style: T.meta(p).copyWith(
                          letterSpacing: 2.4,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FallbackRingPainter extends CustomPainter {
  _FallbackRingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 6;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: 0.2),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -1.5708,
      6.2832 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _FallbackRingPainter old) =>
      old.progress != progress;
}
