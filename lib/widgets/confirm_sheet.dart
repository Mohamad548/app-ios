import 'package:flutter/material.dart';

import '../l10n.dart';
import '../theme.dart';
import 'app_icon.dart';

/// Confirmation bottom sheet: sent + awaiting reply + 3s dismissal timer.
Future<void> showConfirmSheet(
  BuildContext context, {
  required String code,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ConfirmSheet(code: code),
  );
}

class _ConfirmSheet extends StatefulWidget {
  const _ConfirmSheet({required this.code});
  final String code;

  @override
  State<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends State<_ConfirmSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bar = AnimationController(
    vsync: this,
    duration: AppTheme.sheetDismiss,
  );

  @override
  void initState() {
    super.initState();
    _bar.forward();
    _bar.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        Navigator.of(context).maybePop();
      }
    });
  }

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadii.sheet),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: p.stroke,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      L10n.sentTo(widget.code),
                      style: T.device(p).copyWith(fontSize: 18),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.techSoft,
                    ),
                    child: Center(
                      child: AppIcon('check', size: 20, color: p.tech),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(L10n.awaitingReply, style: T.meta(p)),
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _bar,
                builder: (context, _) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: _bar.value,
                      minHeight: 4,
                      backgroundColor: p.stroke,
                      color: p.tech,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: AppSpace.touch,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: p.surfaceAlt,
                    foregroundColor: p.txt,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.button),
                    ),
                  ),
                  child: Text(L10n.log, style: T.button(p)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
