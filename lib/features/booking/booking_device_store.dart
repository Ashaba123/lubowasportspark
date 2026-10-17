import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Per-device booking state: a random device id for slot holds, the tokens of bookings made here
/// (so guests can see them without an account) and the last contact details used.
class BookingDeviceStore {
  BookingDeviceStore(this._prefs);

  static Future<BookingDeviceStore> open() async => BookingDeviceStore(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  static const String _deviceIdKey = 'booking_device_id';
  static const String _tokensKey = 'booking_guest_tokens';
  static const String _nameKey = 'booking_contact_name';
  static const String _phoneKey = 'booking_contact_phone';
  static const String _emailKey = 'booking_contact_email';

  String get deviceId {
    final String? existing = _prefs.getString(_deviceIdKey);
    if (existing != null && existing.length == 32) return existing;
    final Random random = Random.secure();
    final String id = List<String>.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    _prefs.setString(_deviceIdKey, id);
    return id;
  }

  List<String> get guestTokens => _prefs.getStringList(_tokensKey) ?? <String>[];

  /// Newest first; the bridge reads at most 50.
  Future<void> addGuestToken(String token) async {
    final List<String> tokens = <String>[token, ...guestTokens.where((String t) => t != token)];
    await _prefs.setStringList(_tokensKey, tokens.take(50).toList());
  }

  String get contactName => _prefs.getString(_nameKey) ?? '';
  String get contactPhone => _prefs.getString(_phoneKey) ?? '';
  String get contactEmail => _prefs.getString(_emailKey) ?? '';

  Future<void> saveContact({required String name, required String phone, required String email}) async {
    await _prefs.setString(_nameKey, name);
    await _prefs.setString(_phoneKey, phone);
    await _prefs.setString(_emailKey, email);
  }
}

/// Mirrors the bridge's normalize_phone: "0772 123456" / "772123456" / "+256 772 123456" are valid.
bool isValidBookingPhone(String raw) {
  String digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 10 && digits.startsWith('0')) {
    digits = '256${digits.substring(1)}';
  } else if (digits.length == 9 && digits.startsWith('7')) {
    digits = '256$digits';
  }
  return digits.length >= 10 && digits.length <= 15;
}
