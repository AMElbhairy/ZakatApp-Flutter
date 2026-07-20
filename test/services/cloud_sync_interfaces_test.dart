import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../support/mock_cloud_storage_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserCloudStorageProvider Interface & Mock Tests', () {
    late MockCloudStorageProvider provider;

    setUp(() {
      provider = MockCloudStorageProvider();
    });

    test('Initial state is not connected, but connect() changes it', () async {
      expect(await provider.isConnected(), isFalse);
      final connected = await provider.connect();
      expect(connected, isTrue);
      expect(await provider.isConnected(), isTrue);

      await provider.disconnect();
      expect(await provider.isConnected(), isFalse);
    });

    test('Reading non-existent manifest returns null', () async {
      final manifest = await provider.readManifest();
      expect(manifest, isNull);
    });

    test('Writing manifest and reading it back works', () async {
      final initialData = {'schemaVersion': 1, 'latestGlobalSequence': 0};
      await provider.writeManifest(initialData);

      final manifest = await provider.readManifest();
      expect(manifest, isNotNull);
      expect(manifest!.content, equals(initialData));
      expect(manifest.revision, isNotEmpty);
    });

    test('Conditional manifest write succeeds with correct expectedRevision', () async {
      final data1 = {'schemaVersion': 1, 'latestGlobalSequence': 10};
      await provider.writeManifest(data1);

      final manifest1 = await provider.readManifest();
      final revision1 = manifest1!.revision;

      final data2 = {'schemaVersion': 1, 'latestGlobalSequence': 20};
      await provider.writeManifest(data2, expectedRevision: revision1);

      final manifest2 = await provider.readManifest();
      expect(manifest2!.content, equals(data2));
      expect(manifest2.revision, isNot(equals(revision1)));
    });

    test('Conditional manifest write fails when expectedRevision is stale', () async {
      final data1 = {'schemaVersion': 1, 'latestGlobalSequence': 10};
      await provider.writeManifest(data1);

      final manifest1 = await provider.readManifest();
      final revision1 = manifest1!.revision;

      // Make a concurrent write that updates the revision
      final data2 = {'schemaVersion': 1, 'latestGlobalSequence': 20};
      await provider.writeManifest(data2, expectedRevision: revision1);

      // Now revision in provider is updated. Trying to write using revision1 (stale) should fail.
      final data3 = {'schemaVersion': 1, 'latestGlobalSequence': 30};
      expect(
        () => provider.writeManifest(data3, expectedRevision: revision1),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Revision mismatch'))),
      );

      // Verify the manifest content in the cloud is still the second write, not the third
      final currentManifest = await provider.readManifest();
      expect(currentManifest!.content, equals(data2));
    });

    test('File CRUD operations work correctly', () async {
      const filePath = 'snapshots/snapshot_001.sqlite';
      final fileData = Uint8List.fromList([1, 2, 3, 4, 5]);

      // Read non-existent
      final missing = await provider.readFile(filePath);
      expect(missing, isNull);

      // Write file
      await provider.writeFile(filePath, fileData);

      // Read back
      final readData = await provider.readFile(filePath);
      expect(readData, equals(fileData));

      // List files matching prefix
      final list = await provider.listFiles('snapshots/');
      expect(list.length, equals(1));
      expect(list.first.path, equals(filePath));
      expect(list.first.sizeBytes, equals(5));

      // Delete file
      await provider.deleteFile(filePath);
      final deleted = await provider.readFile(filePath);
      expect(deleted, isNull);

      final listAfterDelete = await provider.listFiles('snapshots/');
      expect(listAfterDelete, isEmpty);
    });

    test('Conditional file write fails when expectedRevision is stale', () async {
      const filePath = 'logs/log_1.json';
      final data1 = Uint8List.fromList([10, 20]);
      await provider.writeFile(filePath, data1);

      final files = await provider.listFiles('logs/');
      final revision1 = files.first.revision;
      expect(revision1, isNotNull);

      // Perform a write updating the file and revision
      final data2 = Uint8List.fromList([30, 40]);
      await provider.writeFile(filePath, data2, expectedRevision: revision1);

      // Stale write should fail
      final data3 = Uint8List.fromList([50, 60]);
      expect(
        () => provider.writeFile(filePath, data3, expectedRevision: revision1),
        throwsStateError,
      );
    });
  });
}
