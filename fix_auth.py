with open('lib/services/auth_service.dart', 'r') as f:
    content = f.read()

old_abstract = """abstract class AuthService {
  Future<UserProfile?> signIn();
  Future<void> signOut();
  Future<UserProfile?> restoreSession();
}

class GoogleAuthService implements AuthService {"""

new_abstract = """abstract class AuthService {
  Future<UserProfile?> signIn();
  Future<void> signOut();
  Future<UserProfile?> restoreSession();
  Future<bool> ensureSession();
}

class GoogleAuthService implements AuthService {"""

content = content.replace(old_abstract, new_abstract)

with open('lib/services/auth_service.dart', 'w') as f:
    f.write(content)
