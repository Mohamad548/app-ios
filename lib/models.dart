enum RelayUiState {
  off,
  on,
  sending,
  awaiting,
  error,
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
