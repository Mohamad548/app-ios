import 'package:flutter_test/flutter_test.dart';
import 'package:sim800_controller/sms/protocol.dart';

void main() {
  group('KitCommand', () {
    test('builds relay enable/disable with PIN', () {
      expect(
        KitCommand.relay(index: 1, enable: true, pin: '0000').body,
        'R1EN0000',
      );
      expect(
        KitCommand.relay(index: 4, enable: false, pin: '1234').body,
        'R4DS1234',
      );
      expect(KitCommand.status('0000').body, 'STATUS0000');
    });

    test('rejects bad pin and index', () {
      expect(
        () => KitCommand.relay(index: 5, enable: true, pin: '0000'),
        throwsArgumentError,
      );
      expect(
        () => KitCommand.status('12'),
        throwsArgumentError,
      );
    });
  });

  group('parseKitAck', () {
    test('full snapshot', () {
      final ack = parseKitAck('R1=1 R2=0 R3=1 R4=0');
      expect(ack?.kind, KitAckKind.status);
      expect(ack?.snapshot, [true, false, true, false]);
    });

    test('single channel on/off', () {
      expect(parseKitAck('R1 ON OK')?.kind, KitAckKind.on);
      expect(parseKitAck('R2 OFF OK')?.relayIndex, 1);
    });

    test('errors', () {
      expect(parseKitAck('PASS ERROR')?.kind, KitAckKind.passError);
      expect(parseKitAck('UNKNOWN CMD')?.kind, KitAckKind.unknownCmd);
      expect(parseKitAck('hello'), isNull);
    });
  });

  group('sms uri', () {
    test('keeps ASCII body for Android and iOS', () {
      final uri = smsLaunchUri('+9647700000000', 'R1EN0000');
      expect(uri.scheme, 'sms');
      expect(uri.path, '+9647700000000');
      expect(uri.queryParameters['body'], 'R1EN0000');
      expect(uri.toString(), contains('body=R1EN0000'));
    });
  });

  group('CommandGate', () {
    test('blocks duplicate body inside the window', () {
      final gate = CommandGate(window: const Duration(seconds: 2));
      final t = DateTime(2026, 1, 1, 12);
      expect(gate.tryAcquire('R1EN0000', now: t), isTrue);
      gate.release();
      expect(
        gate.tryAcquire('R1EN0000', now: t.add(const Duration(milliseconds: 500))),
        isFalse,
      );
      expect(
        gate.tryAcquire('R1DS0000', now: t.add(const Duration(milliseconds: 600))),
        isTrue,
      );
    });

    test('blocks while in flight', () {
      final gate = CommandGate();
      expect(gate.tryAcquire('STATUS0000'), isTrue);
      expect(gate.tryAcquire('R2EN0000'), isFalse);
      gate.release();
      expect(gate.tryAcquire('R2EN0000'), isTrue);
    });
  });

  group('samePhone', () {
    test('matches last digits', () {
      expect(samePhone('+9647701112233', '07701112233'), isTrue);
      expect(samePhone('09120000000', '09121111111'), isFalse);
    });
  });
}
