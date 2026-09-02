/// Helpers for carrying the in-progress registration data between routes.
class CadastroDraftUtils {
  const CadastroDraftUtils._();

  static Map<String, dynamic> resolve({
    required Map<String, dynamic> persisted,
    Object? routeExtra,
  }) {
    if (persisted.isNotEmpty) return persisted;
    if (routeExtra is Map<String, dynamic>) return routeExtra;
    if (routeExtra is Map) {
      return routeExtra.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  static bool hasCredentials(Map<String, dynamic> draft) {
    final email = draft['email']?.toString().trim() ?? '';
    final password = (draft['senha'] ?? draft['password'])?.toString() ?? '';
    return email.isNotEmpty && password.isNotEmpty;
  }
}
