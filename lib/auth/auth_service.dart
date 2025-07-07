typedef Tokens = Map<String, String?>;

abstract class AuthService {
  Future<Tokens> signIn();
  Future<void> signOut();
  Future<Tokens> refreshTokens();
  String get serviceName;
  Future<String?> getCurrentUserEmail();
  Future<String>_getEmailAddress();
}
