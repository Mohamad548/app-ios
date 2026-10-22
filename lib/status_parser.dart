import 'sms/protocol.dart';

export 'sms/protocol.dart' show looksLikeKitReply, parseKitAck, KitAck, KitAckKind;

/// Parse kit reply bodies such as `R1=1 R2=0 R3=0 R4=0`.
/// Single-channel `R1 ON OK` is not a full snapshot — returns null.
List<bool>? parseRelayStatus(String body) => parseKitAck(body)?.snapshot;
