import 'package:flutter/material.dart';

import '../theme.dart';

/// Deep gradient + optional aurora webp from the Asset Kit.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, this.child, this.useAuroraImage = true});

  final Widget? child;
  final bool useAuroraImage;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [p.bg, p.bgEnd],
            ),
          ),
        ),
        if (useAuroraImage)
          Positioned.fill(
            child: Opacity(
              opacity: p.isDark ? 0.85 : 0.55,
              child: Image.asset(
                p.aurora,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ?child,
      ],
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.sm),
    this.borderColor,
    this.glow,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color? glow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final box = AnimatedContainer(
      duration: AppTheme.toggle,
      curve: AppTheme.standard,
      padding: padding,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: borderColor ?? p.stroke),
        boxShadow: [
          if (glow != null)
            BoxShadow(color: glow!.withValues(alpha: 0.22), blurRadius: 28),
          if (!p.isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: box,
      ),
    );
  }
}
