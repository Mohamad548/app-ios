import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n.dart';
import '../models.dart';
import '../theme.dart';
import 'app_icon.dart';
import 'aurora_background.dart';
import 'fan_visual.dart';

/// Fan relay card — OFF / ON / pressed / sending / awaiting / error / unknown.
class FanCard extends StatefulWidget {
  const FanCard({
    super.key,
    required this.title,
    required this.code,
    required this.state,
    required this.onTap,
  });

  final String title;
  final String code;
  final RelayUiState state;
  final VoidCallback onTap;

  @override
  State<FanCard> createState() => _FanCardState();
}

class _FanCardState extends State<FanCard> {
  bool _pressed = false;

  bool get _busy =>
      widget.state == RelayUiState.sending ||
      widget.state == RelayUiState.awaiting;

  bool get _on => widget.state == RelayUiState.on;

  String get _statusLabel {
    switch (widget.state) {
      case RelayUiState.on:
        return L10n.stateOn;
      case RelayUiState.off:
        return L10n.stateOff;
      case RelayUiState.sending:
        return L10n.sending;
      case RelayUiState.awaiting:
        return L10n.awaitingReply;
      case RelayUiState.error:
        return L10n.sendError;
      case RelayUiState.unknown:
        return L10n.unknown;
    }
  }

  String get _actionLabel => _on ? L10n.turnOff : L10n.turnOn;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final accent = switch (widget.state) {
      RelayUiState.on => p.on,
      RelayUiState.error => p.danger,
      RelayUiState.sending || RelayUiState.awaiting => p.tech,
      _ => p.txtDim,
    };
    final border = switch (widget.state) {
      RelayUiState.on => p.on.withValues(alpha: 0.55),
      RelayUiState.sending || RelayUiState.awaiting =>
        p.tech.withValues(alpha: 0.55),
      RelayUiState.error => p.danger.withValues(alpha: 0.45),
      _ => p.stroke,
    };

    return GestureDetector(
      onTapDown: _busy ? null : (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (!_busy) {
          HapticFeedback.selectionClick();
          widget.onTap();
        }
      },
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: AppTheme.press,
        curve: Curves.easeOut,
        child: GlassCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          borderColor: border,
          glow: _on ? p.on : (_busy ? p.tech : null),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    widget.code,
                    textDirection: TextDirection.ltr,
                    style: T.meta(p).copyWith(
                      fontWeight: FontWeight.w600,
                      color: accent,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const Spacer(),
                  _StatusChip(
                    label: _statusLabel,
                    color: accent,
                    busy: _busy,
                    // Web only: keep R1–R4 aligned when Sorani labels change length.
                    reserveWidth: kIsWeb ? 108 : null,
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: FanVisual(state: widget.state, size: 108),
                ),
              ),
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.device(p).copyWith(fontSize: 16),
              ),
              const SizedBox(height: 8),
              _ActionBar(
                label: _busy
                    ? (widget.state == RelayUiState.awaiting
                        ? L10n.awaitingReply
                        : L10n.sending)
                    : _actionLabel,
                on: _on,
                busy: _busy,
                error: widget.state == RelayUiState.error,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.busy,
    this.reserveWidth,
  });

  final String label;
  final Color color;
  final bool busy;
  final double? reserveWidth;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      width: reserveWidth,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: reserveWidth == null ? MainAxisSize.min : MainAxisSize.max,
        children: [
          if (busy)
            SizedBox(
              width: 8,
              height: 8,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: color,
              ),
            )
          else
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
          const SizedBox(width: 6),
          if (reserveWidth == null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 88),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.meta(p).copyWith(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.meta(p).copyWith(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.label,
    required this.on,
    required this.busy,
    required this.error,
  });

  final String label;
  final bool on;
  final bool busy;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final bg = error
        ? p.dangerSoft
        : busy
            ? p.techSoft
            : on
                ? p.on
                : p.surfaceAlt;
    final fg = error
        ? p.danger
        : busy
            ? p.tech
            : on
                ? (p.isDark ? const Color(0xFF241503) : Colors.white)
                : p.txt;

    return AnimatedContainer(
      duration: AppTheme.toggle,
      curve: AppTheme.standard,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppIcon('power', size: 16, color: fg),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: T.button(p).copyWith(fontSize: 13, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
