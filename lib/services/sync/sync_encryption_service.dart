import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class SyncEncryptionService {
  SyncEncryptionService();

  final _aesGcm = AesGcm.with256bits();

  /// Derives a 256-bit encryption key from a passphrase and salt using PBKDF2 with HMAC-SHA256 and 100,000 iterations.
  Future<SecretKey> deriveKey({
    required String passphrase,
    required List<int> salt,
  }) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    return await pbkdf2.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );
  }

  /// Encrypts bytes using AES-256-GCM.
  /// Generates a random 12-byte nonce.
  /// Output format: [nonce (12 bytes)] + [mac (16 bytes)] + [ciphertext]
  Future<Uint8List> encrypt({
    required Uint8List clearText,
    required SecretKey secretKey,
  }) async {
    final nonce = _generateRandomBytes(12);
    final secretBox = await _aesGcm.encrypt(
      clearText,
      secretKey: secretKey,
      nonce: nonce,
    );
    
    final macBytes = secretBox.mac.bytes;
    final cipherTextBytes = secretBox.cipherText;
    
    final builder = BytesBuilder();
    builder.add(nonce);
    builder.add(macBytes);
    builder.add(cipherTextBytes);
    return builder.takeBytes();
  }

  /// Decrypts bytes encrypted with [encrypt].
  Future<Uint8List> decrypt({
    required Uint8List encryptedData,
    required SecretKey secretKey,
  }) async {
    if (encryptedData.length < 28) {
      throw ArgumentError('Encrypted data is too short to contain nonce and MAC.');
    }
    final nonce = encryptedData.sublist(0, 12);
    final macBytes = encryptedData.sublist(12, 28);
    final cipherText = encryptedData.sublist(28);

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final decrypted = await _aesGcm.decrypt(
      secretBox,
      secretKey: secretKey,
    );
    return Uint8List.fromList(decrypted);
  }

  /// Helper to generate secure random bytes.
  List<int> _generateRandomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  /// Helper to generate a new random salt.
  List<int> generateSalt() {
    return _generateRandomBytes(16);
  }
}
