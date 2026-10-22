import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n.dart';
import '../sms_service.dart';
import '../store.dart';
import '../theme.dart';
import '../util/digits.dart';
import '../widgets/app_icon.dart';
import '../widgets/aurora_background.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _phone;
  late final TextEditingController _pass;
  late final List<TextEditingController> _names;

  bool _silent = Store.silent;
  bool _obscure = true;
  bool _testing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(text: Store.phone);
    _pass = TextEditingController(text: Store.password);
    _names =
        Store.names.map((e) => TextEditingController(text: e)).toList();
  }

  @override
  void dispose() {
    _phone.dispose();
    _pass.dispose();
    for (final c in _names) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    final p = Palette.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: error ? p.danger : p.surfaceAlt,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  Future<void> _save() async {
    if (_saving) return;

    FocusScope.of(context).unfocus();

    final phone = toAsciiDigits(_phone.text)
        .replaceAll(RegExp(r'[\s\-()]'), '')
        .trim();
    var pass = toAsciiDigits(_pass.text).trim();
    if (pass.isEmpty) pass = '0000';

    if (phone.isEmpty) {
      _snack(L10n.phoneNumber, error: true);
      return;
    }
    if (phone.length < 8) {
      _snack(L10n.phoneNumber, error: true);
      return;
    }
    if (pass.length != 4 || int.tryParse(pass) == null) {
      _snack(L10n.passwordHint, error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await Store.setPhone(phone);
      await Store.setPassword(pass);
      await Store.setSilent(SmsService.usesComposeSheet ? false : _silent);
      await Store.setNames([
        for (var i = 0; i < 4; i++)
          _names[i].text.trim().isEmpty
              ? L10n.defaultNames[i]
              : _names[i].text.trim(),
      ]);

      if (!mounted) return;

      if (Store.phone.isEmpty || Store.phone != phone) {
        _snack(L10n.saveFailed, error: true);
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (ctx) {
          final p = Palette.of(ctx);
          return AlertDialog(
            backgroundColor: p.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            title: Text(L10n.saved, style: T.device(p)),
            content: Text(L10n.savedBody, style: T.body(p)),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
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

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) _snack('${L10n.saveFailed}: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    final phone = toAsciiDigits(
      _phone.text.trim().isEmpty ? Store.phone : _phone.text.trim(),
    ).replaceAll(RegExp(r'[\s\-()]'), '');
    final pass = toAsciiDigits(_pass.text.trim());
    if (phone.isEmpty) {
      _snack(L10n.phoneNumber, error: true);
      return;
    }
    setState(() => _testing = true);
    try {
      final has = await SmsService.hasPermission();
      if (!has) {
        final granted = await SmsService.requestPermission();
        if (!granted) {
          _snack(L10n.smsDeniedTitle, error: true);
          return;
        }
      }
      final pin = pass.isEmpty ? Store.password : pass;
      final body = KitCommand.status(pin).body;
      await SmsService.send(phone, body, hide: _silent);
      CommandLog.add(L10n.testConnection, body, true);
      _snack(
        SmsService.usesComposeSheet ? L10n.composeOpened : L10n.sent,
      );
    } on ArgumentError {
      _snack(L10n.passwordHint, error: true);
    } catch (_) {
      CommandLog.add(L10n.testConnection, 'STATUS…', false);
      _snack(L10n.sendError, error: true);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);

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
                      onPressed: _saving
                          ? null
                          : () => Navigator.pop(context, Store.phone.isNotEmpty),
                      icon: AppIcon('back-rtl', size: 22, color: p.txt),
                    ),
                    Expanded(
                      child: Text(
                        L10n.settings,
                        textAlign: TextAlign.center,
                        style: T.title(p).copyWith(fontSize: 20),
                      ),
                    ),
                    TextButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: p.tech,
                              ),
                            )
                          : Text(
                              L10n.save,
                              style: T.button(p).copyWith(
                                color: p.tech,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.gutter,
                    8,
                    AppSpace.gutter,
                    24,
                  ),
                  children: [
                    _section(L10n.connection, p),
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      child: Column(
                        children: [
                          _field(
                            controller: _phone,
                            label: L10n.phoneNumber,
                            icon: 'phone',
                            keyboard: TextInputType.phone,
                            ltr: true,
                            formatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9+۰-۹٠-٩\s\-]'),
                              ),
                            ],
                          ),
                          Divider(color: p.stroke, height: 1),
                          _field(
                            controller: _pass,
                            label: L10n.password,
                            icon: 'lock',
                            keyboard: TextInputType.number,
                            obscure: _obscure,
                            maxLength: 4,
                            formatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9۰-۹٠-٩]'),
                              ),
                            ],
                            suffix: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: AppIcon(
                                _obscure ? 'eye' : 'eye-off',
                                size: 18,
                                color: p.txtDim,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _section(L10n.deviceNames, p),
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < 4; i++) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _names[i],
                                    decoration: InputDecoration(
                                      isDense: true,
                                      border: InputBorder.none,
                                      hintText: L10n.defaultNames[i],
                                      hintStyle: T.body(p)
                                          .copyWith(color: p.txtDim),
                                    ),
                                    style: T.body(p),
                                  ),
                                ),
                                Text(
                                  'R${i + 1}',
                                  textDirection: TextDirection.ltr,
                                  style: T.meta(p).copyWith(
                                    color: p.tech,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AppIcon('edit', size: 16, color: p.txtDim),
                              ],
                            ),
                            if (i < 3) Divider(color: p.stroke, height: 12),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (SmsService.usesComposeSheet)
                      GlassCard(
                        child: Row(
                          children: [
                            AppIcon('info', size: 22, color: p.txtDim),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                SmsService.supportsInbox
                                    ? L10n.iosSmsNote
                                    : L10n.pwaSmsNote,
                                style: T.meta(p),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      GlassCard(
                        child: Row(
                          children: [
                            AppIcon('mute', size: 22, color: p.txtDim),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(L10n.silentSend, style: T.body(p)),
                                  Text(L10n.silentHelper, style: T.meta(p)),
                                ],
                              ),
                            ),
                            Switch(
                              value: _silent,
                              activeThumbColor: p.tech,
                              onChanged: (v) => setState(() => _silent = v),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    GlassCard(
                      onTap: _testing ? null : _test,
                      child: Row(
                        children: [
                          AppIcon('antenna', size: 22, color: p.txtDim),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(L10n.testConnection, style: T.body(p)),
                          ),
                          if (_testing)
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: p.tech,
                              ),
                            )
                          else ...[
                            Text(
                              'SMS',
                              style: T.meta(p).copyWith(color: p.tech),
                            ),
                            const SizedBox(width: 4),
                            AppIcon('chevron-left', size: 16, color: p.txtDim),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: AppSpace.touch + 4,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: p.tech,
                          disabledBackgroundColor: p.surfaceAlt,
                          foregroundColor: const Color(0xFF04222A),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadii.button),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Color(0xFF04222A),
                                ),
                              )
                            : Text(
                                L10n.save,
                                style: T.button(p).copyWith(
                                  color: const Color(0xFF04222A),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String text, Palette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Text(text, style: T.meta(p).copyWith(fontWeight: FontWeight.w600)),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String icon,
    TextInputType? keyboard,
    bool obscure = false,
    bool ltr = false,
    int? maxLength,
    List<TextInputFormatter>? formatters,
    Widget? suffix,
  }) {
    final p = Palette.of(context);
    return Row(
      children: [
        AppIcon(icon, size: 20, color: p.txtDim),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboard,
            obscureText: obscure,
            maxLength: maxLength,
            inputFormatters: formatters,
            textDirection: ltr ? TextDirection.ltr : null,
            style: T.body(p),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: T.meta(p),
              border: InputBorder.none,
              counterText: '',
              suffixIcon: suffix,
            ),
          ),
        ),
      ],
    );
  }
}
