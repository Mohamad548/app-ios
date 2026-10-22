import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

import 'protocol.dart';
import 'sms_transport.dart';

/// PWA / browser: opens the system Messages app with `sms:`.
/// The user must tap Send. There is no inbox and no silent send.
class WebSmsTransport extends SmsTransportBase {
  @override
  SmsPlatformKind get kind => SmsPlatformKind.web;

  @override
  Future<bool> hasPermission() async => kIsWeb;

  @override
  Future<bool> requestPermission() async => kIsWeb;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<bool> send(String number, String message, {bool hide = true}) async {
    final uri = smsLaunchUri(number, message);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      throw const SmsError('Could not open the SMS app');
    }
    // Sheet opened. We cannot know if the user tapped Send.
    // Return true so the UI shows Pending (not Confirmed).
    return true;
  }
}
