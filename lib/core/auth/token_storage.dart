import 'package:shared_preferences/shared_preferences.dart';

/// Simple token storage abstraction. Implement with secure storage for production.
/// [currentToken] is synchronous for API client interceptor.
abstract class TokenStorage {
  /// Synchronous token for API client. Override in implementations.
  String? get currentToken => null;

  Future<String?> getToken();
  Future<void> setToken(String? token);
  Future<void> clear();
}

/// In-memory token holder. Use for bootstrap; replace with secure impl for auth.
/// [currentToken] is synchronous for use in API interceptor.
class InMemoryTokenStorage implements TokenStorage {
  String? _token;

  /// Synchronous token for API client interceptor. Use after [setToken] or [getToken].
  String? get currentToken => _token;

  @override
  Future<String?> getToken() async => _token;

  @override
  Future<void> setToken(String? token) async {
    _token = token;
  }

  @override
  Future<void> clear() async {
    _token = null;
  }
}

const String _keyToken = 'lubowa_jwt';

/// Persists JWT in SharedPreferences so login survives app restart.
/// For production consider flutter_secure_storage for tokens.
class SharedPreferencesTokenStorage implements TokenStorage {
  SharedPreferencesTokenStorage([SharedPreferences? prefs]) : _prefs = prefs;

  SharedPreferences? _prefs;
  String? _currentToken;

  Future<SharedPreferences> get _storage async =>
      _prefs ??= await SharedPreferences.getInstance();

  @override
  String? get currentToken => _currentToken;

  @override
  Future<String?> getToken() async {
    if (_currentToken != null) return _currentToken;
    final prefs = await _storage;
    _currentToken = prefs.getString(_keyToken);
    return _currentToken;
  }

  @override
  Future<void> setToken(String? token) async {
    final prefs = await _storage;
    if (token == null) {
      await prefs.remove(_keyToken);
    } else {
      await prefs.setString(_keyToken, token);
    }
    _currentToken = token;
  }

  @override
  Future<void> clear() async {
    final prefs = await _storage;
    await prefs.remove(_keyToken);
    _currentToken = null;
  }
}
