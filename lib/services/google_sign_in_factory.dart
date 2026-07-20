import 'package:google_sign_in/google_sign_in.dart';

const String _iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

GoogleSignIn createAppGoogleSignIn({
  List<String> scopes = const <String>['profile', 'email'],
  List<String> extraScopes = const <String>[],
}) {
  return GoogleSignIn(
    clientId: _iosClientId.trim().isEmpty ? null : _iosClientId,
    scopes: <String>[...scopes, ...extraScopes],
  );
}
