/// Platform SMS capabilities. Inbox and silent send exist only on Android.
enum SmsPlatformKind { android, ios, web }

class IncomingSms {
  IncomingSms({required this.from, required this.body});
  final String from;
  final String body;
}

/// Shared SMS contract. Implementations must not fake inbox on iOS/web.
///
/// Concrete helpers live on [SmsTransportBase] because Dart treats a body
/// on an interface method as abstract for `implements`.
abstract class SmsTransport {
  SmsPlatformKind get kind;

  /// Web/PWA and iOS: user must confirm in Messages. Not silent.
  bool get usesComposeSheet;

  /// Automatic STATUS on resume would pop Messages on iOS/PWA.
  bool get supportsBackgroundSync;

  /// Kit reply stream only on Android (RECEIVE_SMS). Never simulated elsewhere.
  bool get supportsInbox;

  Stream<IncomingSms> get inbox;

  Future<bool> hasPermission();

  Future<bool> canReceive();

  Future<bool> shouldShowRationale();

  Future<bool> requestPermission();

  Future<bool> requestReceivePermission();

  Future<void> openAppSettings();

  /// `true` = phone accepted the send (Android API) or user tapped Send (iOS/PWA).
  /// `false` = user cancelled the compose sheet. Throws [SmsError] on hard failure.
  /// Does **not** mean the kit executed the command.
  Future<bool> send(String number, String message, {bool hide = true});
}

/// Default capability flags derived from [kind]. Subclasses override send/permissions.
abstract class SmsTransportBase implements SmsTransport {
  @override
  SmsPlatformKind get kind;

  @override
  bool get usesComposeSheet =>
      kind == SmsPlatformKind.ios || kind == SmsPlatformKind.web;

  @override
  bool get supportsBackgroundSync => kind == SmsPlatformKind.android;

  @override
  bool get supportsInbox => kind == SmsPlatformKind.android;

  @override
  Stream<IncomingSms> get inbox => const Stream.empty();

  @override
  Future<bool> canReceive() async => false;

  @override
  Future<bool> shouldShowRationale() async => false;

  @override
  Future<bool> requestReceivePermission() async => false;

  @override
  Future<void> openAppSettings() async {}
}

class SmsError implements Exception {
  const SmsError(this.message);
  final String message;

  @override
  String toString() => message;
}
