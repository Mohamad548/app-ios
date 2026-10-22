/// Parse kit reply bodies such as `R1=1 R2=0 R3=0 R4=0`.
List<bool>? parseRelayStatus(String body) {
  final text = body.toUpperCase();
  final out = List<bool>.filled(4, false);
  var found = 0;
  for (var i = 1; i <= 4; i++) {
    final m = RegExp('R$i\\s*=\\s*([01])').firstMatch(text);
    if (m != null) {
      out[i - 1] = m.group(1) == '1';
      found++;
    }
  }
  if (found == 4) return out;

  // Fallback: "R1 ON OK" style single-channel ack — not a full snapshot.
  return null;
}

bool looksLikeKitReply(String body) {
  final t = body.toUpperCase();
  return t.contains('R1=') ||
      t.contains(' ON OK') ||
      t.contains(' OFF OK') ||
      t.contains('PASS ERROR') ||
      t.contains('UNKNOWN CMD');
}
