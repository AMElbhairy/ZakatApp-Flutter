import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'secure_storage_service.dart';
import 'sync/sync_encryption_service.dart';

class BackupKeyRecoveryException implements Exception {
  const BackupKeyRecoveryException(this.message);

  static const String recoveryUnavailableMessage =
      'Your backup encryption key could not be recovered.\n\n'
      'Cloud backups cannot currently be restored.\n\n'
      'Please sign in again or reconnect Backup & Sync.';

  final String message;

  @override
  String toString() => 'BackupKeyRecoveryException: $message';
}

class BackupKeyManager {
  BackupKeyManager({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    SecureStorageService? secureStorageService,
    SyncEncryptionService? encryptionService,
    DateTime Function()? nowProvider,
    String? appVersion,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _secureStorageService = secureStorageService ?? const SecureStorageService(),
        _encryptionService = encryptionService ?? SyncEncryptionService(),
        _nowProvider = nowProvider ?? DateTime.now,
        _appVersion = appVersion ??
            const String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  static const int currentVersion = 1;
  static const String _wrappingContext = 'zakatapp_backup_key_recovery_v1';
  static const String _wrappingSalt = 'zakatapp_backup_key_wrap_salt_v1';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final SecureStorageService _secureStorageService;
  final SyncEncryptionService _encryptionService;
  final DateTime Function() _nowProvider;
  final String _appVersion;

  Future<Uint8List> getOrCreateKey() async {
    final Uint8List? existing = await getExistingKey();
    if (existing != null) {
      return existing;
    }

    final bool hasRecoveryKey = await _hasRecoveryKey();
    if (hasRecoveryKey) {
      await recoverKeyFromFirestore();
      final Uint8List? recovered = await getExistingKey();
      if (recovered != null) {
        return recovered;
      }
      throw const BackupKeyRecoveryException(
        BackupKeyRecoveryException.recoveryUnavailableMessage,
      );
    }

    await recoverKeyFromFirestore();

    final Uint8List generated = _generateKey();
    await _saveLocalKey(generated);
    await uploadRecoveryKey();
    return generated;
  }

  Future<Uint8List?> getExistingKey() async {
    final String? encoded = await _secureStorageService.loadBackupKey(
      userId: _auth.currentUser?.uid,
    );
    if (encoded == null || encoded.trim().isEmpty) {
      return null;
    }
    try {
      return Uint8List.fromList(base64Decode(encoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> uploadRecoveryKey() async {
    final User user = _requireUser();
    final Uint8List? key = await getExistingKey();
    if (key == null || key.isEmpty) {
      throw const BackupKeyRecoveryException(
        BackupKeyRecoveryException.recoveryUnavailableMessage,
      );
    }

    try {
      final DocumentReference<Map<String, dynamic>> docRef = _document(user.uid);
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await docRef.get();
      final Map<String, dynamic>? existingData = snapshot.data();
      final String now = _nowProvider().toUtc().toIso8601String();
      final String wrappedKey = await _wrapKey(user.uid, key);

      await docRef.set(<String, dynamic>{
        'wrappedKey': wrappedKey,
        'version': (existingData?['version'] as int?) ?? currentVersion,
        'createdAt': existingData?['createdAt'] as String? ?? now,
        'updatedAt': now,
        'algorithm': 'AES-256-GCM',
        'appVersion': _appVersion,
        'keyStatus': 'active',
      });
    } on FirebaseException catch (_) {
      throw const BackupKeyRecoveryException(
        BackupKeyRecoveryException.recoveryUnavailableMessage,
      );
    }
  }

  Future<void> recoverKeyFromFirestore() async {
    final User user = _requireUser();

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _document(user.uid).get();
      if (!snapshot.exists) {
        return;
      }
      final Map<String, dynamic>? data = snapshot.data();
      final String? wrappedKey = data?['wrappedKey'] as String?;
      if (wrappedKey == null || wrappedKey.trim().isEmpty) {
        return;
      }
      final Uint8List key = await _unwrapKey(user.uid, wrappedKey);
      await _saveLocalKey(key);
    } on FirebaseException catch (_) {
      throw const BackupKeyRecoveryException(
        BackupKeyRecoveryException.recoveryUnavailableMessage,
      );
    }
  }

  Future<void> rotateKey() async {
    final User user = _requireUser();

    try {
      final DocumentReference<Map<String, dynamic>> docRef = _document(user.uid);
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await docRef.get();
      final Map<String, dynamic>? existingData = snapshot.data();
      final int nextVersion = ((existingData?['version'] as int?) ?? 0) + 1;
      final String now = _nowProvider().toUtc().toIso8601String();

      final Uint8List key = _generateKey();
      await _saveLocalKey(key);
      final String wrappedKey = await _wrapKey(user.uid, key);

      await docRef.set(<String, dynamic>{
        'wrappedKey': wrappedKey,
        'version': nextVersion,
        'createdAt': existingData?['createdAt'] as String? ?? now,
        'updatedAt': now,
        'algorithm': 'AES-256-GCM',
        'appVersion': _appVersion,
        'keyStatus': 'active',
      });
    } on FirebaseException catch (_) {
      throw const BackupKeyRecoveryException(
        BackupKeyRecoveryException.recoveryUnavailableMessage,
      );
    }
  }

  DocumentReference<Map<String, dynamic>> _document(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('security')
        .doc('backupKey');
  }

  User _requireUser() {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw const BackupKeyRecoveryException(
        BackupKeyRecoveryException.recoveryUnavailableMessage,
      );
    }
    return user;
  }

  Uint8List _generateKey() {
    final Random random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
  }

  Future<void> _saveLocalKey(Uint8List key) async {
    await _secureStorageService.saveBackupKey(
      base64Encode(key),
      userId: _auth.currentUser?.uid,
    );
  }

  Future<bool> _hasRecoveryKey() async {
    final User user = _requireUser();
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _document(user.uid).get();
      final Map<String, dynamic>? data = snapshot.data();
      final String? wrappedKey = data?['wrappedKey'] as String?;
      return snapshot.exists &&
          wrappedKey != null &&
          wrappedKey.trim().isNotEmpty;
    } on FirebaseException catch (_) {
      throw const BackupKeyRecoveryException(
        BackupKeyRecoveryException.recoveryUnavailableMessage,
      );
    }
  }

  Future<SecretKey> _deriveWrappingKey(String uid) {
    return _encryptionService.deriveKey(
      passphrase: '$uid:$_wrappingContext',
      salt: utf8.encode(_wrappingSalt),
    );
  }

  Future<String> _wrapKey(String uid, Uint8List key) async {
    final SecretKey wrappingKey = await _deriveWrappingKey(uid);
    final Uint8List encrypted = await _encryptionService.encrypt(
      clearText: key,
      secretKey: wrappingKey,
    );
    return base64Encode(encrypted);
  }

  Future<Uint8List> _unwrapKey(String uid, String wrappedKey) async {
    final SecretKey wrappingKey = await _deriveWrappingKey(uid);
    try {
      return await _encryptionService.decrypt(
        encryptedData: Uint8List.fromList(base64Decode(wrappedKey)),
        secretKey: wrappingKey,
      );
    } catch (_) {
      throw const BackupKeyRecoveryException(
        BackupKeyRecoveryException.recoveryUnavailableMessage,
      );
    }
  }
}
