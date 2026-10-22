import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';

import 'sms_transport.dart';

/// Android SmsManager / iOS MFMessageCompose via `sim800/sms`.
class NativeSmsTransport extends SmsTransportBase {
  NativeSmsTransport({
    MethodChannel? channel,
    EventChannel? inboxChannel,
    bool? isWeb,
    TargetPlatform? platform,
  })  : _ch = channel ?? const MethodChannel('sim800/sms'),
        _inboxCh = inboxChannel ?? const EventChannel('sim800/sms_inbox'),
        _isWeb = isWeb ?? kIsWeb,
        _platform = platform ?? defaultTargetPlatform;

  final MethodChannel _ch;
  final EventChannel _inboxCh;
  final bool _isWeb;
  final TargetPlatform _platform;

  @override
  SmsPlatformKind get kind {
    if (_isWeb) return SmsPlatformKind.web;
    if (_platform == TargetPlatform.iOS) return SmsPlatformKind.ios;
    return SmsPlatformKind.android;
  }

  @override
  Stream<IncomingSms> get inbox {
    if (!supportsInbox) return const Stream.empty();
    return _inboxCh.receiveBroadcastStream().map((raw) {
      final map = Map<String, dynamic>.from(raw as Map);
      return IncomingSms(
        from: '${map['from'] ?? ''}',
        body: '${map['body'] ?? ''}',
      );
    });
  }

  @override
  Future<bool> hasPermission() async {
    try {
      return await _ch.invokeMethod<bool>('canSend') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> canReceive() async {
    if (!supportsInbox) return false;
    try {
      return await _ch.invokeMethod<bool>('canReceive') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> shouldShowRationale() async {
    if (usesComposeSheet) return false;
    try {
      return await _ch.invokeMethod<bool>('shouldShowRationale') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      return await _ch.invokeMethod<bool>('requestPermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> requestReceivePermission() async {
    if (!supportsInbox) return false;
    try {
      return await _ch.invokeMethod<bool>('requestReceivePermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> openAppSettings() async {
    try {
      await _ch.invokeMethod<bool>('openAppSettings');
    } on PlatformException {
      // ignore
    } on MissingPluginException {
      // ignore
    }
  }

  @override
  Future<bool> send(String number, String message, {bool hide = true}) async {
    try {
      final ok = await _ch.invokeMethod<bool>('send', {
        'number': number,
        'message': message,
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
