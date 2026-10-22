/// Kit SMS protocol — extracted from the app/firmware docs.
/// Do not invent new command shapes; firmware is case-insensitive ASCII.
library;

/// How long to wait for a kit reply before marking the command timed out.
const Duration kitReplyTimeout = Duration(seconds: 12);

/// Minimum gap between commands so the modem can finish a send.
const Duration commandGap = Duration(milliseconds: 320);

class KitCommand {
  const KitCommand._(this.body);
  final String body;

  /// `R1EN0000` … `R4DS0000`
  factory KitCommand.relay({
    required int index,
    required bool enable,
    required String pin,
  }) {
    if (index < 1 || index > 4) {
      throw ArgumentError.value(index, 'index', 'relay must be 1..4');
    }
    final p = _pin(pin);
    final op = enable ? 'EN' : 'DS';
    return KitCommand._('R$index$op$p');
  }

  /// `STATUS0000`
  factory KitCommand.status(String pin) => KitCommand._('STATUS${_pin(pin)}');

  static String _pin(String pin) {
    final p = pin.trim();
    if (p.length != 4 || int.tryParse(p) == null) {
      throw ArgumentError.value(pin, 'pin', 'PIN must be 4 digits');
    }
    return p;
  }
}

/// Build an `sms:` URI that works on Android and iOS Messages.
/// Body stays ASCII (protocol). `?` is Android-friendly; iOS also accepts it.
Uri smsLaunchUri(String number, String body) {
  final n = number.trim();
  return Uri(
    scheme: 'sms',
    path: n,
    queryParameters: <String, String>{'body': body},
  );
}

enum KitAckKind { on, off, status, passError, unknownCmd, other }

class KitAck {
  const KitAck({
    required this.kind,
    this.relayIndex,
    this.snapshot,
  });

  final KitAckKind kind;

  /// 0-based relay when the reply names a single channel.
  final int? relayIndex;

  /// Full R1..R4 when present.
  final List<bool>? snapshot;
}

/// Parse a kit SMS body. Protocol is not changed; unknown text returns null.
KitAck? parseKitAck(String body) {
  final text = body.toUpperCase();
  final snap = _snapshot(text);
  if (snap != null) {
    return KitAck(kind: KitAckKind.status, snapshot: snap);
  }
  if (text.contains('PASS ERROR')) {
    return const KitAck(kind: KitAckKind.passError);
  }
  if (text.contains('UNKNOWN CMD')) {
    return const KitAck(kind: KitAckKind.unknownCmd);
  }
  final on = RegExp(r'R([1-4])\s+ON\s+OK').firstMatch(text);
  if (on != null) {
    return KitAck(kind: KitAckKind.on, relayIndex: int.parse(on.group(1)!) - 1);
  }
  final off = RegExp(r'R([1-4])\s+OFF\s+OK').firstMatch(text);
  if (off != null) {
    return KitAck(
      kind: KitAckKind.off,
      relayIndex: int.parse(off.group(1)!) - 1,
    );
  }
  return null;
}

List<bool>? _snapshot(String text) {
  final out = List<bool>.filled(4, false);
  var found = 0;
  for (var i = 1; i <= 4; i++) {
    final m = RegExp('R$i\\s*=\\s*([01])').firstMatch(text);
    if (m != null) {
      out[i - 1] = m.group(1) == '1';
      found++;
    }
  }
  return found == 4 ? out : null;
}

bool looksLikeKitReply(String body) => parseKitAck(body) != null;

/// Last 10 digits — used to match the kit number loosely.
String phoneTail(String number) {
  final digits = number.replaceAll(RegExp(r'\D'), '');
  if (digits.length <= 10) return digits;
  return digits.substring(digits.length - 10);
}

bool samePhone(String a, String b) {
  final ta = phoneTail(a);
  final tb = phoneTail(b);
  if (ta.isEmpty || tb.isEmpty) return false;
  return ta == tb || ta.endsWith(tb) || tb.endsWith(ta);
}

/// Drop duplicate sends of the same body within [window].
class CommandGate {
  CommandGate({this.window = const Duration(seconds: 2)});

  final Duration window;
  String? _lastBody;
  DateTime? _lastAt;
  bool _inflight = false;

  bool get inflight => _inflight;

  /// Returns false when the same command was just sent (replay guard).
  bool tryAcquire(String body, {DateTime? now}) {
    if (_inflight) return false;
    final t = now ?? DateTime.now();
    if (_lastBody == body &&
        _lastAt != null &&
        t.difference(_lastAt!) < window) {
      return false;
    }
    _inflight = true;
    _lastBody = body;
    _lastAt = t;
    return true;
  }

  void release() {
    _inflight = false;
  }
}
