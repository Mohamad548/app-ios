import 'package:flutter/material.dart';

import '../l10n.dart';
import '../theme.dart';
import 'app_icon.dart';

class SignalPill extends StatelessWidget {
  const SignalPill({
    super.key,
    required this.available,
    this.demo = false,
  });

  final bool available;
  final bool demo;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final color = demo
        ? p.on
        : (available ? p.tech : p.danger);
    final label = demo
        ? L10n.demo
        : (available ? L10n.gsm : L10n.noSignal);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            available || demo ? 'signal' : 'no-signal',
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: T.meta(p).copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
