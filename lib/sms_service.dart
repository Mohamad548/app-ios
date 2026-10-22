import 'package:flutter/foundation.dart' show kIsWeb;

import 'models.dart';
import 'sms/native_sms_transport.dart';
import 'sms/sms_transport.dart';
import 'sms/web_sms_transport.dart';

export 'sms/protocol.dart';
export 'sms/sms_transport.dart' show IncomingSms, SmsError, SmsPlatformKind;

/// Facade over [SmsTransport]. Android/iOS use the native channel;
/// web/PWA uses `sms:` links. Inbox is never faked on iOS or web.
class SmsService {
  SmsService._();

  static SmsTransport? _override;

  /// Tests inject a fake transport.
  static void debugSetTransport(SmsTransport? transport) {
    _override = transport;
  }

  static SmsTransport get transport =>
      _override ?? (kIsWeb ? WebSmsTransport() : NativeSmsTransport());

  static bool get demo => false;

  static bool get usesComposeSheet => transport.usesComposeSheet;

  static bool get supportsBackgroundSync => transport.supportsBackgroundSync;

  static bool get supportsInbox => transport.supportsInbox;

  static Stream<IncomingSms> get inbox => transport.inbox;

  static Future<bool> hasPermission() => transport.hasPermission();

  static Future<bool> canReceive() => transport.canReceive();

  static Future<bool> shouldShowRationale() => transport.shouldShowRationale();

  static Future<bool> requestPermission() => transport.requestPermission();

  static Future<bool> requestReceivePermission() =>
      transport.requestReceivePermission();

  static Future<void> openAppSettings() => transport.openAppSettings();

  static Future<bool> send(
    String number,
    String message, {
    bool hide = true,
  }) =>
      transport.send(number, message, hide: hide);
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
