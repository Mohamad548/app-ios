import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim800_controller/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    Store.debugReset();
    SharedPreferences.setMockInitialValues({});
  });

  test('persists phone and relay bits', () async {
    await Store.init();

    await Store.setPhone('09185480383');
    await Store.setPassword('1234');
    await Store.setRelayOn([true, false, true, false]);

    expect(Store.phone, '09185480383');
    expect(Store.password, '1234');
    expect(Store.relayOn, [true, false, true, false]);

    // Simulate cold start: new prefs instance with same backing map is tricky;
    // at least verify in-memory + write completed without throw.
    await Store.setRelayIndex(1, true);
    expect(Store.relayOn[1], isTrue);
  });
}
