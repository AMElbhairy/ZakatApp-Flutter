import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakatapp_flutter/services/sync/sync_encryption_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncEncryptionService Tests', () {
    late SyncEncryptionService encryptionService;

    setUp(() {
      encryptionService = SyncEncryptionService();
    });

    test('Key derivation is consistent and deterministic', () async {
      const password = 'my-secure-password-123';
      final salt = encryptionService.generateSalt();

      final key1 = await encryptionService.deriveKey(
        passphrase: password,
        salt: salt,
      );
      final key2 = await encryptionService.deriveKey(
        passphrase: password,
        salt: salt,
      );

      final bytes1 = await key1.extractBytes();
      final bytes2 = await key2.extractBytes();

      expect(bytes1, equals(bytes2));
      expect(bytes1.length, equals(32)); // 256 bits
    });

    test('Key derivation with different salt produces different key', () async {
      const password = 'my-secure-password-123';
      final salt1 = encryptionService.generateSalt();
      final salt2 = encryptionService.generateSalt();

      final key1 = await encryptionService.deriveKey(
        passphrase: password,
        salt: salt1,
      );
      final key2 = await encryptionService.deriveKey(
        passphrase: password,
        salt: salt2,
      );

      final bytes1 = await key1.extractBytes();
      final bytes2 = await key2.extractBytes();

      expect(bytes1, isNot(equals(bytes2)));
    });

    test('Encrypt and decrypt roundtrip works with JSON strings', () async {
      const password = 'test-encryption-passphrase';
      final salt = encryptionService.generateSalt();
      final key = await encryptionService.deriveKey(passphrase: password, salt: salt);

      final originalPayload = {
        'deviceId': 'test-device-id',
        'sequence': 42,
        'operations': [
          {'id': 'op-1', 'type': 'upsert', 'table': 'transactions', 'data': {'amount': 1000}}
        ]
      };
      final jsonString = jsonEncode(originalPayload);
      final clearText = Uint8List.fromList(utf8.encode(jsonString));

      final encrypted = await encryptionService.encrypt(
        clearText: clearText,
        secretKey: key,
      );

      // Verify prefix sizes: nonce is 12 bytes, mac is 16 bytes, total metadata = 28 bytes
      expect(encrypted.length, greaterThan(28));

      final decrypted = await encryptionService.decrypt(
        encryptedData: encrypted,
        secretKey: key,
      );

      final decryptedString = utf8.decode(decrypted);
      final decryptedPayload = jsonDecode(decryptedString) as Map<String, dynamic>;

      expect(decryptedPayload, equals(originalPayload));
    });

    test('Decryption fails and throws when ciphertext is tampered', () async {
      const password = 'test-tamper-passphrase';
      final salt = encryptionService.generateSalt();
      final key = await encryptionService.deriveKey(passphrase: password, salt: salt);

      final clearText = Uint8List.fromList(utf8.encode('Top Secret Data'));

      final encrypted = await encryptionService.encrypt(
        clearText: clearText,
        secretKey: key,
      );

      // Tamper with the ciphertext (which starts at index 28)
      final tampered = Uint8List.fromList(encrypted);
      tampered[tampered.length - 1] ^= 0xFF; // Flip bits in the last byte

      expect(
        () => encryptionService.decrypt(encryptedData: tampered, secretKey: key),
        throwsException, // AES-GCM tag verification will fail and throw cryptography's exception
      );
    });

    test('Decryption throws ArgumentError for too short payloads', () async {
      const password = 'short-payload-passphrase';
      final salt = encryptionService.generateSalt();
      final key = await encryptionService.deriveKey(passphrase: password, salt: salt);

      final shortData = Uint8List.fromList(List.generate(27, (index) => index));

      expect(
        () => encryptionService.decrypt(encryptedData: shortData, secretKey: key),
        throwsArgumentError,
      );
    });
  });
}
