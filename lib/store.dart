import 'package:shared_preferences/shared_preferences.dart';

/// Persistence + in-memory cache (phone, PIN, names, last known relay states).
class Store {
  Store._();

  static SharedPreferences? _p;
  static String _phone = '';
  static String _password = '0000';
  static bool _silent = true;
  static List<String> _names = List<String>.from(_defaultNames);
  static List<bool> _relayOn = List<bool>.filled(4, false);
  static bool _ready = false;

  static const _kPhone = 'kit_phone';
  static const _kPass = 'kit_pass';
  static const _kSilent = 'silent_send';
  static const _kNames = 'device_names';
  static const _kRelay = 'relay_on_bits';

  static const List<String> _defaultNames = [
    'فەن ١',
    'فەن ٢',
    'فەن ٣',
    'فەن ٤',
  ];

  static Future<void> init() async {
    await _ensure();
  }

  /// Test-only: clear singleton so mock prefs can be reloaded.
  static void debugReset() {
    _p = null;
    _ready = false;
    _phone = '';
    _password = '0000';
    _silent = true;
    _names = List<String>.from(_defaultNames);
    _relayOn = List<bool>.filled(4, false);
  }

  static Future<SharedPreferences> _ensure() async {
    if (_p != null) return _p!;
    final prefs = await SharedPreferences.getInstance();
    _p = prefs;
    if (!_ready) {
      _phone = prefs.getString(_kPhone) ?? '';
      _password = prefs.getString(_kPass) ?? '0000';
      _silent = prefs.getBool(_kSilent) ?? true;
      final names = prefs.getStringList(_kNames);
      _names = (names != null && names.length == 4)
          ? List<String>.from(names)
          : List<String>.from(_defaultNames);
      final bits = prefs.getString(_kRelay) ?? '0000';
      _relayOn = [
        for (var i = 0; i < 4; i++)
          i < bits.length && bits[i] == '1',
      ];
      _ready = true;
    }
    return prefs;
  }

  static String get phone => _phone;

  static Future<void> setPhone(String v) async {
    _phone = v.trim();
    final prefs = await _ensure();
    await prefs.setString(_kPhone, _phone);
  }

  static String get password => _password;

  static Future<void> setPassword(String v) async {
    _password = v.trim();
    final prefs = await _ensure();
    await prefs.setString(_kPass, _password);
  }

  static bool get silent => _silent;

  static Future<void> setSilent(bool v) async {
    _silent = v;
    final prefs = await _ensure();
    await prefs.setBool(_kSilent, v);
  }

  static List<String> get names => List<String>.from(_names);

  static Future<void> setNames(List<String> v) async {
    _names = List<String>.from(v);
    final prefs = await _ensure();
    await prefs.setStringList(_kNames, _names);
  }

  /// Last known ON/OFF for R1..R4 (local cache; refreshed by STATUS when possible).
  static List<bool> get relayOn => List<bool>.from(_relayOn);

  static Future<void> setRelayOn(List<bool> states) async {
    assert(states.length == 4);
    _relayOn = List<bool>.from(states);
    final prefs = await _ensure();
    final bits = [
      for (final on in _relayOn) on ? '1' : '0',
    ].join();
    await prefs.setString(_kRelay, bits);
  }

  static Future<void> setRelayIndex(int index, bool on) async {
    if (index < 0 || index > 3) return;
    final next = relayOn;
    next[index] = on;
    await setRelayOn(next);
  }

  static bool get isConfigured => phone.isNotEmpty;

  static bool get hasPassword => password.length == 4;
}
