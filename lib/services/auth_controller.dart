import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/storage_keys.dart';
import '../models/user_profile.dart';
import '../features/auth/auth_service.dart';
import 'local_storage_service.dart';

class AuthController extends ChangeNotifier {
  AuthController({required this.authService, required this.localStorage});

  final AuthService authService;
  final LocalStorageService localStorage;

  UserProfile? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserProfile? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isSignedIn => _currentUser != null;
  String? get error => _error;

  Stream<AuthGateState> get authGateStateChanges {
    if (authService is AuthGateStateSource) {
      return (authService as AuthGateStateSource).authGateStateChanges;
    }
    final UserProfile? user = _currentUser;
    return Stream<AuthGateState>.value(
      user == null
          ? const AuthGateState(status: AuthGateStatus.signedOut)
          : AuthGateState(status: AuthGateStatus.signedIn, user: user),
    );
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final String? raw = await localStorage.loadString(
        StorageKeys.userProfileKey,
      );
      if (raw != null && raw.trim().isNotEmpty) {
        try {
          final Map<String, dynamic> json =
              jsonDecode(raw) as Map<String, dynamic>;
          _currentUser = UserProfile.fromJson(json);
        } catch (_) {
          _currentUser = null;
        }
      }

      final UserProfile? persistedUser = _currentUser;
      if (persistedUser != null &&
          AuthProviderX.parse(persistedUser.provider) == AuthProvider.apple) {
        // Apple sign-in is restored from local profile state; there is no silent
        // Apple session to rehydrate on startup.
      } else {
        final UserProfile? restored = await authService.restoreSession();
        if (restored != null) {
          _currentUser = restored;
          await _persistCurrentUser();
        }
      }
    } catch (error, stackTrace) {
      debugPrint('AuthController.load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn({AuthProvider provider = AuthProvider.google}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final UserProfile? user = await authService.signIn(provider: provider);
      if (user != null) {
        _currentUser = user;
        await _persistCurrentUser();
      }
    } catch (error, stackTrace) {
      debugPrint('AuthController.signIn failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    _error = null;
    final String? userIdAtSignOut = _currentUser?.id;
    notifyListeners();

    try {
      await authService.signOut();
    } catch (error, stackTrace) {
      debugPrint('AuthController.signOut failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _error = error.toString();
    } finally {
      _currentUser = null;
      final String? scopedKey = StorageKeys.appStateKeyForUser(userIdAtSignOut);
      if (scopedKey != null) {
        await localStorage.remove(scopedKey);
      }
      await localStorage.remove(StorageKeys.appStateAnonymousKey);
      await localStorage.remove(StorageKeys.userProfileKey);
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> ensureSession() async {
    if (!isSignedIn) return false;
    if (AuthProviderX.parse(_currentUser?.provider) == AuthProvider.apple) {
      return true;
    }
    final bool isValid = await authService.ensureSession();
    if (!isValid) {
      // Session is stale/invalid, try restoring it (signInSilently).
      final UserProfile? restored = await authService.restoreSession();
      if (restored != null) {
        _currentUser = restored;
        await _persistCurrentUser();
        return true;
      } else {
        await signOut();
        return false;
      }
    }
    return true;
  }

  Future<void> _persistCurrentUser() async {
    final UserProfile? user = _currentUser;
    if (user == null) return;
    await localStorage.saveString(
      StorageKeys.userProfileKey,
      jsonEncode(user.toJson()),
    );
  }
}
