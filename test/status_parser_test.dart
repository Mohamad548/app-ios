import 'package:flutter_test/flutter_test.dart';
import 'package:sim800_controller/status_parser.dart';
import 'package:sim800_controller/util/digits.dart';

void main() {
  group('parseRelayStatus', () {
    test('parses full snapshot', () {
      expect(
        parseRelayStatus('R1=1 R2=0 R3=1 R4=0'),
        [true, false, true, false],
      );
    });

    test('is case-insensitive and tolerates spaces', () {
      expect(
        parseRelayStatus('r1 = 0  r2=1 r3=1 r4=1'),
        [false, true, true, true],
      );
    });

    test('returns null for single-channel ack', () {
      expect(parseRelayStatus('R1 ON OK'), isNull);
    });
  });

  group('toAsciiDigits', () {
    test('converts persian digits', () {
      expect(toAsciiDigits('۰۹۱۸۵۴۸۰۳۸۳'), '09185480383');
    });

    test('leaves latin digits', () {
      expect(toAsciiDigits('0918'), '0918');
    });
  });

  group('looksLikeKitReply', () {
    test('detects status and errors', () {
      expect(looksLikeKitReply('R1=1 R2=0 R3=0 R4=0'), isTrue);
      expect(looksLikeKitReply('PASS ERROR'), isTrue);
      expect(looksLikeKitReply('hello'), isFalse);
    });
  });
}
