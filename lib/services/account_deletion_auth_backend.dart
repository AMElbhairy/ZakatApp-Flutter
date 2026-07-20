import 'package:firebase_auth/firebase_auth.dart';

abstract class AccountDeletionAuthBackend {
  bool get hasCurrentUser;
  String? get uid;
  String? get email;
  List<String> get providerIds;

  Future<void> reauthenticateWithCredential(AuthCredential credential);
  Future<void> deleteAccount();
  Future<void> signOut();
}

class FirebaseAccountDeletionAuthBackend
    implements AccountDeletionAuthBackend {
  FirebaseAccountDeletionAuthBackend({
    FirebaseAuth? firebaseAuth,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  User? get _currentUser => _firebaseAuth.currentUser;

  @override
  bool get hasCurrentUser => _currentUser != null;

  @override
  String? get uid => _currentUser?.uid;

  @override
  String? get email => _currentUser?.email;

  @override
  List<String> get providerIds => _currentUser?.providerData
          .map((UserInfo info) => info.providerId)
          .where((String providerId) => providerId.trim().isNotEmpty)
          .toList(growable: false) ??
      <String>[];

  @override
  Future<void> reauthenticateWithCredential(AuthCredential credential) async {
    final User? user = _currentUser;
    if (user == null) {
      throw StateError('No authenticated Firebase user is available.');
    }
    await user.reauthenticateWithCredential(credential);
  }

  @override
  Future<void> deleteAccount() async {
    final User? user = _currentUser;
    if (user == null) {
      throw StateError('No authenticated Firebase user is available.');
    }
    await user.delete();
  }

  @override
  Future<void> signOut() => _firebaseAuth.signOut();
}
