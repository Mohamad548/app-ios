/// Visual/command state of one relay.
///
/// - [unknown]: no confirmed kit snapshot (cache only, or never synced).
/// - [sending]: request in flight to the phone SMS stack.
/// - [awaiting]: phone accepted the SMS (or PWA opened Messages); kit not confirmed.
/// - [on] / [off]: confirmed by a kit reply on Android, or last cache elsewhere.
/// - [error]: send failed, user-facing failure, or reply timeout / bad PIN.
enum RelayUiState {
  off,
  on,
  sending,
  awaiting,
  error,
  unknown,
}

/// Lifecycle of one outbound command — distinct from the relay's ON/OFF.
enum CommandPhase {
  /// Handed to the platform; radio result not known yet.
  pending,

  /// Phone reports the SMS left the device (Android sent) or user tapped Send (iOS).
  /// On PWA this means Messages was opened — not that Send was tapped.
  sentByPhone,

  /// Kit reply matched this command (Android inbox only).
  confirmed,

  /// Platform error, cancel, timeout, or kit PASS ERROR / UNKNOWN CMD.
  failed,

  /// No trustworthy result (typical on iOS/PWA after the sheet closes).
  unknown,
}

class Device {
  Device({
    required this.index,
    required this.name,
    this.isOn = false,
    this.ui = RelayUiState.unknown,
  });

  /// Relay number on the kit: 1..4
  final int index;
  String name;
  bool isOn;
  RelayUiState ui;

  String get code => 'R$index';

  Device copy() =>
      Device(index: index, name: name, isOn: isOn, ui: ui);
}

enum LogKind { sent, reply, error }

class LogEntry {
  LogEntry({
    required this.title,
    required this.detail,
    required this.ok,
    this.kind = LogKind.sent,
    DateTime? at,
  }) : at = at ?? DateTime.now();

  final String title;
  final String detail;
  final bool ok;
  final LogKind kind;
  final DateTime at;
}
