import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';

import 'models.dart';

class IncomingSms {
  IncomingSms({required this.from, required this.body});
  final String from;
  final String body;
}

/// Bridge to native SMS:
/// - Android: SmsManager (silent send when permitted)
/// - iOS: MFMessageComposeViewController (user taps Send in Messages)
class SmsService {
  SmsService._();

  static const MethodChannel _ch = MethodChannel('sim800/sms');
  static const EventChannel _inbox = EventChannel('sim800/sms_inbox');

  static bool get demo => kIsWeb;

  /// iOS shows the system Messages sheet; command text is visible.
  static bool get usesComposeSheet =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Auto STATUS sync would pop Messages on every resume — only Android.
  static bool get supportsBackgroundSync => !demo && !usesComposeSheet;

  /// Inbox STATUS replies only work on Android with RECEIVE_SMS.
  static bool get supportsInbox => !demo && !usesComposeSheet;

  static Stream<IncomingSms> get inbox {
    if (demo || !supportsInbox) return const Stream.empty();
    return _inbox.receiveBroadcastStream().map((raw) {
      final map = Map<String, dynamic>.from(raw as Map);
      return IncomingSms(
        from: '${map['from'] ?? ''}',
        body: '${map['body'] ?? ''}',
      );
    });
  }

  static Future<bool> hasPermission() async {
    if (demo) return true;
    try {
      return await _ch.invokeMethod<bool>('canSend') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> canReceive() async {
    if (demo || !supportsInbox) return false;
    try {
      return await _ch.invokeMethod<bool>('canReceive') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> shouldShowRationale() async {
    if (demo || usesComposeSheet) return false;
    try {
      return await _ch.invokeMethod<bool>('shouldShowRationale') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> requestPermission() async {
    if (demo) return true;
    try {
      return await _ch.invokeMethod<bool>('requestPermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> requestReceivePermission() async {
    if (demo || !supportsInbox) return false;
    try {
      return await _ch.invokeMethod<bool>('requestReceivePermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> openAppSettings() async {
    if (demo) return;
    try {
      await _ch.invokeMethod<bool>('openAppSettings');
    } on PlatformException {
      // ignore
    } on MissingPluginException {
      // ignore
    }
  }

  /// Returns `true` if sent, `false` if user cancelled the compose sheet.
  static Future<bool> send(
    String number,
    String message, {
    bool hide = true,
  }) async {
    if (demo) return true;
    try {
      final ok = await _ch.invokeMethod<bool>('send', {
        'number': number,
        'message': message,
        // iOS always shows Messages; hide is Android-only best-effort.
        'hide': usesComposeSheet ? false : hide,
      });
      return ok ?? false;
    } on PlatformException catch (e) {
      throw SmsError(e.message ?? 'send failed (${e.code})');
    } on MissingPluginException {
      throw const SmsError('native channel unavailable');
    }
  }
}

class SmsError implements Exception {
  const SmsError(this.message);
  final String message;

  @override
  String toString() => message;
}

class CommandLog {
  CommandLog._();

  static final List<LogEntry> entries = <LogEntry>[];

  static void add(
    String title,
    String detail,
    bool ok, {
    LogKind kind = LogKind.sent,
  }) {
    entries.insert(
      0,
      LogEntry(
        title: title,
        detail: detail,
        ok: ok,
        kind: ok ? kind : LogKind.error,
      ),
    );
    if (entries.length > 100) entries.removeLast();
  }

  static void clear() => entries.clear();
}
