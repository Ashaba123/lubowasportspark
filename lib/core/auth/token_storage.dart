/// Simple token storage abstraction. Implement with secure storage for production.
/// For bootstrap, in-memory is sufficient; replace with flutter_secure_storage when adding login.
abstract class TokenStorage {
  Future<String?> getToken();
  Future<void> setToken(String? token);
  Future<void> clear();
}

/// In-memory token holder. Use for bootstrap; replace with secure impl for auth.
class InMemoryTokenStorage implements TokenStorage {
  String? _token;

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
