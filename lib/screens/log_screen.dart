import 'package:flutter/material.dart';

import '../l10n.dart';
import '../models.dart';
import '../sms_service.dart';
import '../theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/aurora_background.dart';

enum _Filter { all, sent, error }

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  _Filter _filter = _Filter.all;

  String _two(int v) => v.toString().padLeft(2, '0');

  String _time(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

  List<LogEntry> get _entries {
    final all = CommandLog.entries;
    return switch (_filter) {
      _Filter.all => all,
      _Filter.sent => all.where((e) => e.ok).toList(),
      _Filter.error => all.where((e) => !e.ok).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final entries = _entries;

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: AppIcon('back-rtl', size: 22, color: p.txt),
                    ),
                    Expanded(
                      child: Text(
                        L10n.log,
                        textAlign: TextAlign.center,
                        style: T.title(p).copyWith(fontSize: 20),
                      ),
                    ),
                    IconButton(
                      onPressed: entries.isEmpty
                          ? null
                          : () => setState(CommandLog.clear),
                      icon: AppIcon('filter', size: 20, color: p.txtDim),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  8,
                  AppSpace.gutter,
                  8,
                ),
                child: _FilterBar(
                  value: _filter,
                  onChanged: (v) => setState(() => _filter = v),
                ),
              ),
              Expanded(
                child: entries.isEmpty ? _empty(p) : _list(p, entries),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(Palette p) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.gutter),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(L10n.emptyLog, style: T.meta(p)),
              const SizedBox(height: 16),
              Image.asset(
                'assets/illustrations/empty-log.webp',
                width: 140,
                height: 140,
                errorBuilder: (_, _, _) => AppIcon('sms', size: 64, color: p.tech),
              ),
              const SizedBox(height: 16),
              Text(L10n.emptyTitle, style: T.device(p).copyWith(fontSize: 16)),
              const SizedBox(height: 6),
              Text(
                L10n.emptyBody,
                textAlign: TextAlign.center,
                style: T.meta(p),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(Palette p, List<LogEntry> entries) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        4,
        AppSpace.gutter,
        24,
      ),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final e = entries[i];
        final color = switch (e.kind) {
          LogKind.error => p.danger,
          LogKind.reply => p.tech,
          LogKind.sent => p.on,
        };
        final badge = switch (e.kind) {
          LogKind.error => L10n.sendError,
          LogKind.reply => L10n.reply,
          LogKind.sent => L10n.sent,
        };
        final icon = switch (e.kind) {
          LogKind.error => 'error',
          LogKind.reply => 'reply',
          LogKind.sent => 'send',
        };

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.15),
                      border: Border.all(color: color.withValues(alpha: 0.5)),
                    ),
                    child: Center(child: AppIcon(icon, size: 14, color: color)),
                  ),
                  if (i < entries.length - 1)
                    Expanded(
                      child: Container(width: 2, color: p.stroke),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.title, style: T.body(p).copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            )),
                            const SizedBox(height: 2),
                            Text(
                              e.detail,
                              textDirection: TextDirection.ltr,
                              style: T.meta(p),
                            ),
                            if (!e.ok)
                              Text(
                                L10n.sendError,
                                style: T.meta(p).copyWith(color: p.danger),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_time(e.at), style: T.meta(p)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(AppRadii.pill),
                              border: Border.all(
                                color: color.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppIcon(icon, size: 12, color: color),
                                const SizedBox(width: 4),
                                Text(
                                  badge,
                                  style: T.meta(p).copyWith(
                                    color: color,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.value, required this.onChanged});

  final _Filter value;
  final ValueChanged<_Filter> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget chip(_Filter f, String label) {
      final active = value == f;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(f),
          child: AnimatedContainer(
            duration: AppTheme.toggle,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? p.tech : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              label,
              style: T.button(p).copyWith(
                fontSize: 13,
                color: active
                    ? (p.isDark ? const Color(0xFF04222A) : Colors.white)
                    : p.txt,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: p.stroke),
      ),
      child: Row(
        children: [
          chip(_Filter.all, L10n.all),
          chip(_Filter.sent, L10n.filterSent),
          chip(_Filter.error, L10n.filterError),
        ],
      ),
    );
  }
}
