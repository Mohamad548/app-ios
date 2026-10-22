import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models.dart';
import '../theme.dart';

/// Layered fan from Asset Kit: rotor → cage → hub (+ sending arc).
/// Only the rotor rotates when ON (1800ms linear).
class FanVisual extends StatefulWidget {
  const FanVisual({
    super.key,
    required this.state,
    this.size = 120,
  });

  final RelayUiState state;
  final double size;

  @override
  State<FanVisual> createState() => _FanVisualState();
}

class _FanVisualState extends State<FanVisual> with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: AppTheme.fanTurn,
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: AppTheme.pulse,
  );
  late final AnimationController _send = AnimationController(
    vsync: this,
    duration: AppTheme.sending,
  );

  bool get _on => widget.state == RelayUiState.on;

  bool get _busy =>
      widget.state == RelayUiState.sending ||
      widget.state == RelayUiState.awaiting;

  @override
  void didUpdateWidget(covariant FanVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _sync();
  }

  void _sync() {
    if (!mounted) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (_on && !reduce) {
      if (!_spin.isAnimating) _spin.repeat();
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _spin.stop();
      _pulse.stop();
      if (!_on) {
        _spin.value = 0;
        _pulse.value = 0;
      }
    }
    if (_busy && !reduce) {
      if (!_send.isAnimating) _send.repeat();
    } else {
      _send.stop();
      _send.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    _send.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final dir = p.fanDir;
    final rotorAsset =
        _on ? '$dir/rotor-on.svg' : '$dir/rotor-off.svg';

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_spin, _pulse, _send]),
        builder: (context, _) {
          final glow = _on ? (0.55 + 0.45 * _pulse.value) : 0.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (_on)
                Container(
                  width: widget.size * 0.92,
                  height: widget.size * 0.92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: p.on.withValues(alpha: 0.22 * glow),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              Transform.rotate(
                angle: _spin.value * 2 * math.pi,
                child: SvgPicture.asset(
                  rotorAsset,
                  width: widget.size,
                  height: widget.size,
                ),
              ),
              SvgPicture.asset(
                '$dir/cage.svg',
                width: widget.size,
                height: widget.size,
              ),
              SvgPicture.asset(
                '$dir/hub.svg',
                width: widget.size,
                height: widget.size,
              ),
              if (_busy)
                CustomPaint(
                  size: Size.square(widget.size),
                  painter: _SendingArcPainter(
                    progress: _send.value,
                    color: p.tech,
                  ),
                ),
              if (widget.state == RelayUiState.error)
                Positioned(
                  bottom: 4,
                  child: Icon(Icons.error_rounded, color: p.danger, size: 22),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SendingArcPainter extends CustomPainter {
  _SendingArcPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.46;
    final rect = Rect.fromCircle(center: c, radius: r);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -math.pi / 2 + progress * 2 * math.pi, math.pi * 0.7,
        false, paint);
  }

  @override
  bool shouldRepaint(covariant _SendingArcPainter old) =>
      old.progress != progress || old.color != color;
}
