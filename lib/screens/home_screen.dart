import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n.dart';
import '../models.dart';
import '../sms_service.dart';
import '../status_parser.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/aurora_background.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/fan_card.dart';
import '../widgets/signal_pill.dart';
import 'log_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final List<Device> _devices = <Device>[];
  bool _hasPerm = true;
  bool _busyAll = false;
  bool _syncing = false;
  DateTime? _lastReply;
  StreamSubscription<IncomingSms>? _inboxSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
    _refreshPermissionStatus();
    _listenInbox();
    // Android only: STATUS SMS would open Messages on every launch on iOS.
    if (SmsService.supportsBackgroundSync) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncFromKit());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inboxSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissionStatus();
      if (SmsService.supportsBackgroundSync) {
        _syncFromKit();
      }
    }
  }

  void _reload() {
    final names = Store.names;
    final on = Store.relayOn;
    _devices
      ..clear()
      ..addAll(List<Device>.generate(
        4,
        (i) => Device(
          index: i + 1,
          name: names[i],
          isOn: on[i],
          ui: on[i] ? RelayUiState.on : RelayUiState.off,
        ),
      ));
  }

  Future<void> _persistStates() async {
    await Store.setRelayOn([for (final d in _devices) d.isOn]);
  }

  void _listenInbox() {
    _inboxSub?.cancel();
    _inboxSub = SmsService.inbox.listen((sms) {
      final parsed = parseRelayStatus(sms.body);
      if (parsed == null) {
        if (looksLikeKitReply(sms.body)) {
          CommandLog.add(L10n.reply, sms.body, true, kind: LogKind.reply);
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < 4; i++) {
          _devices[i].isOn = parsed[i];
          _devices[i].ui =
              parsed[i] ? RelayUiState.on : RelayUiState.off;
        }
        _lastReply = DateTime.now();
        _syncing = false;
      });
      _persistStates();
      CommandLog.add(L10n.reply, sms.body, true, kind: LogKind.reply);
    });
  }

  /// Send STATUS+PIN so firmware replies `R1=… R4=…`. Falls back to cache.
  Future<void> _syncFromKit() async {
    if (SmsService.demo || Store.phone.isEmpty) return;
    if (_syncing) return;
    final canSend = await SmsService.hasPermission();
    if (!canSend || !mounted) return;

    setState(() => _syncing = true);
    _toast(L10n.syncing);

    // Receiving the reply needs RECEIVE_SMS (optional).
    if (!await SmsService.canReceive()) {
      await SmsService.requestReceivePermission();
    }

    try {
      await SmsService.send(
        Store.phone,
        'STATUS${Store.password}',
        hide: Store.silent,
      );
      CommandLog.add(L10n.testConnection, 'STATUS…', true);
      // Kit reply arrives via inbox stream; timeout keeps local cache.
      Future<void>.delayed(const Duration(seconds: 12), () {
        if (mounted && _syncing) {
          setState(() => _syncing = false);
          _toast(L10n.syncLocal);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _syncing = false);
        _toast(L10n.syncLocal);
      }
    }
  }

  Future<void> _refreshPermissionStatus() async {
    final ok = await SmsService.hasPermission();
    if (!mounted) return;
    setState(() => _hasPerm = ok);
  }

  /// Android: explain → system Allow/Deny.
  /// iOS: Messages compose needs no runtime permission; only canSendText.
  Future<bool> _ensureSmsPermission() async {
    if (SmsService.demo) return true;
    if (await SmsService.hasPermission()) {
      if (mounted) setState(() => _hasPerm = true);
      return true;
    }
    if (!mounted) return false;

    if (SmsService.usesComposeSheet) {
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          final p = Palette.of(ctx);
          return AlertDialog(
            backgroundColor: p.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            title: Text(L10n.smsDeniedTitle, style: T.device(p)),
            content: Text(L10n.smsUnavailableIos, style: T.body(p)),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(backgroundColor: p.tech),
                child: Text(
                  L10n.ok,
                  style: T.button(p).copyWith(color: const Color(0xFF04222A)),
                ),
              ),
            ],
          );
        },
      );
      if (mounted) setState(() => _hasPerm = false);
      return false;
    }

    final allow = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final p = Palette.of(ctx);
        return AlertDialog(
          backgroundColor: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          title: Text(L10n.smsPermissionTitle, style: T.device(p)),
          content: Text(L10n.smsPermissionBody, style: T.body(p)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(L10n.cancel, style: T.button(p).copyWith(color: p.txtDim)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: p.tech),
              child: Text(
                L10n.allow,
                style: T.button(p).copyWith(color: const Color(0xFF04222A)),
              ),
            ),
          ],
        );
      },
    );
    if (allow != true || !mounted) return false;

    final granted = await SmsService.requestPermission();
    if (!mounted) return false;
    setState(() => _hasPerm = granted);
    if (granted) return true;

    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final p = Palette.of(ctx);
        return AlertDialog(
          backgroundColor: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          title: Text(L10n.smsDeniedTitle, style: T.device(p)),
          content: Text(L10n.smsDeniedBody, style: T.body(p)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(L10n.cancel, style: T.button(p).copyWith(color: p.txtDim)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: p.tech),
              child: Text(
                L10n.openSettings,
                style: T.button(p).copyWith(color: const Color(0xFF04222A)),
              ),
            ),
          ],
        );
      },
    );
    if (open == true) {
      await SmsService.openAppSettings();
      await _refreshPermissionStatus();
      return _hasPerm;
    }
    return false;
  }

  int get _onCount => _devices.where((d) => d.isOn).length;

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    final p = Palette.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? p.danger : p.surfaceAlt,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _openSettings() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const SettingsScreen()),
    );
    if (!mounted) return false;
    setState(_reload);
    if (Store.phone.isNotEmpty && SmsService.supportsBackgroundSync) {
      unawaited(_syncFromKit());
    }
    return saved == true || Store.phone.isNotEmpty;
  }

  Future<void> _toggle(int i) async {
    final d = _devices[i];
    if (d.ui == RelayUiState.sending || d.ui == RelayUiState.awaiting) return;

    if (!SmsService.demo) {
      if (Store.phone.isEmpty) {
        _toast(L10n.setupNeeded);
        final ok = await _openSettings();
        if (!ok || Store.phone.isEmpty) return;
      }
      final smsOk = await _ensureSmsPermission();
      if (!smsOk) {
        _toast(L10n.smsDeniedTitle, error: true);
        return;
      }
    }

    final target = !d.isOn;
    final cmd = '${d.code}${target ? 'EN' : 'DS'}${Store.password}';
    final previous = d.ui;

    setState(() => d.ui = RelayUiState.sending);

    if (SmsService.demo) {
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      setState(() {
        d.isOn = target;
        d.ui = target ? RelayUiState.on : RelayUiState.off;
        _lastReply = DateTime.now();
      });
      await _persistStates();
      CommandLog.add(d.name, cmd, true);
      if (!mounted) return;
      await showConfirmSheet(context, code: d.code);
      return;
    }

    try {
      final ok = await SmsService.send(
        Store.phone,
        cmd,
        hide: Store.silent,
      );
      if (!mounted) return;
      if (!ok) {
        // User cancelled the iOS Messages sheet (or send aborted).
        setState(() => d.ui = previous);
        _toast(L10n.smsCancelled);
        return;
      }

      setState(() => d.ui = RelayUiState.awaiting);
      CommandLog.add(d.name, cmd, true, kind: LogKind.sent);
      if (!mounted) return;
      await showConfirmSheet(context, code: d.code);

      // Optimistic local state; kit reply (if RECEIVE_SMS) can refine it.
      if (!mounted) return;
      setState(() {
        d.isOn = target;
        d.ui = target ? RelayUiState.on : RelayUiState.off;
        _lastReply = DateTime.now();
      });
      await _persistStates();
    } catch (_) {
      if (!mounted) return;
      setState(() => d.ui = previous == RelayUiState.unknown
          ? RelayUiState.error
          : previous);
      CommandLog.add(d.name, cmd, false, kind: LogKind.error);
      _toast(L10n.sendError, error: true);
    }
  }

  Future<void> _allOff() async {
    if (_busyAll) return;
    if (!SmsService.demo && Store.phone.isEmpty) {
      await _openSettings();
      return;
    }
    if (!SmsService.demo) {
      final smsOk = await _ensureSmsPermission();
      if (!smsOk) {
        _toast(L10n.smsDeniedTitle, error: true);
        return;
      }
    }

    final targets = <int>[
      for (var i = 0; i < 4; i++)
        if (_devices[i].isOn || _devices[i].ui == RelayUiState.on) i,
    ];
    if (targets.isEmpty) {
      _toast(L10n.allOff);
      return;
    }

    setState(() {
      _busyAll = true;
      for (final i in targets) {
        _devices[i].ui = RelayUiState.sending;
      }
    });

    var failed = 0;
    var cancelled = false;
    for (final i in targets) {
      final cmd = '${_devices[i].code}DS${Store.password}';
      if (SmsService.demo) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (mounted) {
          setState(() {
            _devices[i].isOn = false;
            _devices[i].ui = RelayUiState.off;
          });
        }
        CommandLog.add(_devices[i].name, cmd, true);
      } else {
        try {
          final ok = await SmsService.send(
            Store.phone,
            cmd,
            hide: Store.silent,
          );
          if (!ok) {
            cancelled = true;
            if (mounted) {
              setState(() {
                _devices[i].ui =
                    _devices[i].isOn ? RelayUiState.on : RelayUiState.off;
              });
            }
            break;
          }
          if (mounted) {
            setState(() {
              _devices[i].isOn = false;
              _devices[i].ui = RelayUiState.off;
            });
          }
          CommandLog.add(_devices[i].name, cmd, true);
        } catch (_) {
          failed++;
          CommandLog.add(_devices[i].name, cmd, false, kind: LogKind.error);
          if (mounted) {
            setState(() => _devices[i].ui = RelayUiState.error);
          }
        }
        if (!SmsService.usesComposeSheet) {
          await Future<void>.delayed(const Duration(milliseconds: 320));
        }
      }
    }

    if (mounted) {
      setState(() {
        _busyAll = false;
        if (!cancelled) _lastReply = DateTime.now();
        for (final d in _devices) {
          if (d.ui == RelayUiState.sending) {
            d.ui = d.isOn ? RelayUiState.on : RelayUiState.off;
          }
        }
      });
      await _persistStates();
      if (cancelled) {
        _toast(L10n.smsCancelled);
      } else {
        _toast(
          failed == 0 ? L10n.allOff : '${L10n.sendError} ($failed)',
          error: failed > 0,
        );
      }
    }
  }

  String _fmtTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final configured = Store.phone.isNotEmpty;

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              _header(p, configured),
              if (!configured && !SmsService.demo) _setupBanner(p),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  8,
                  AppSpace.gutter,
                  0,
                ),
                child: Row(
                  children: [
                    Text(L10n.devices, style: T.greeting(p)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LogScreen(),
                        ),
                      ),
                      icon: AppIcon('history', size: 18, color: p.tech),
                      label: Text(
                        L10n.log,
                        style: T.meta(p).copyWith(color: p.tech),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = AppSpace.cardGap;
                    const padH = AppSpace.gutter;
                    final cellW =
                        (constraints.maxWidth - padH * 2 - gap) / 2;
                    final cellH = math.min(
                      (constraints.maxHeight - 12 - gap) / 2,
                      cellW / 0.68,
                    );
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(padH, 8, padH, 8),
                      itemCount: 4,
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: gap,
                        crossAxisSpacing: gap,
                        mainAxisExtent: cellH,
                      ),
                      itemBuilder: (context, i) => FanCard(
                        title: _devices[i].name,
                        code: _devices[i].code,
                        state: _devices[i].ui,
                        onTap: () => _toggle(i),
                      ),
                    );
                  },
                ),
              ),
              if (_lastReply != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${L10n.lastReply}: ${_fmtTime(_lastReply!)}',
                    style: T.meta(p),
                  ),
                ),
              _bottomBar(p),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(Palette p, bool configured) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 12, 12, 4),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: p.techSoft,
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/brand/app-mark.png',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Center(child: AppIcon('relay', size: 22, color: p.tech)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(L10n.hello, style: T.greeting(p)),
                Text(
                  '$_onCount لە ٤ · ${L10n.subtitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.meta(p),
                ),
              ],
            ),
          ),
          SignalPill(
            available: configured && _hasPerm,
            demo: SmsService.demo,
          ),
        ],
      ),
    );
  }

  Widget _setupBanner(Palette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        8,
        AppSpace.gutter,
        0,
      ),
      child: GlassCard(
        onTap: _openSettings,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderColor: p.on.withValues(alpha: 0.35),
        child: Row(
          children: [
            AppIcon('info', size: 18, color: p.on),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                L10n.setupNeeded,
                style: T.meta(p).copyWith(color: p.on),
              ),
            ),
            AppIcon('chevron-left', size: 16, color: p.on),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar(Palette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        4,
        AppSpace.gutter,
        16,
      ),
      child: Row(
        children: [
          SizedBox(
            width: AppSpace.touch + 8,
            height: AppSpace.touch + 8,
            child: Material(
              color: p.surface,
              borderRadius: BorderRadius.circular(AppRadii.button),
              child: InkWell(
                onTap: _openSettings,
                borderRadius: BorderRadius.circular(AppRadii.button),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon('settings', size: 20, color: p.txtDim),
                    const SizedBox(height: 2),
                    Text(
                      L10n.settings,
                      style: T.meta(p).copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: AppSpace.touch + 8,
              child: FilledButton.icon(
                onPressed: _busyAll ? null : _allOff,
                style: FilledButton.styleFrom(
                  backgroundColor: p.tech,
                  foregroundColor:
                      p.isDark ? const Color(0xFF04222A) : Colors.white,
                  disabledBackgroundColor: p.surfaceAlt,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.button),
                  ),
                ),
                icon: AppIcon(
                  'power',
                  size: 20,
                  color: p.isDark ? const Color(0xFF04222A) : Colors.white,
                ),
                label: Text(L10n.allOff, style: T.button(p).copyWith(
                  color: p.isDark ? const Color(0xFF04222A) : Colors.white,
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
