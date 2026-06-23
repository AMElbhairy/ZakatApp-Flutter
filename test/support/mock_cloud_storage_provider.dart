import 'dart:convert';
import 'dart:typed_data';
import 'package:zakatapp_flutter/services/sync/user_cloud_storage_provider.dart';

class MockCloudStorageProvider implements UserCloudStorageProvider {
  MockCloudStorageProvider({
    this.connected = false,
  });

  bool connected;
  
  // In-memory file storage: path -> bytes
  final Map<String, Uint8List> _files = {};
  
  // In-memory revisions: path -> revision string
  final Map<String, String> _revisions = {};
  
  int _revisionCounter = 0;

  String _nextRevision() {
    _revisionCounter++;
    return 'rev_$_revisionCounter';
  }

  @override
  String get providerId => 'mock_provider';

  @override
  Future<bool> isConnected() async => connected;

  @override
  Future<bool> connect() async {
    connected = true;
    return true;
  }

  @override
  Future<void> disconnect() async {
    connected = false;
  }

  @override
  Future<CloudManifest?> readManifest() async {
    const path = 'manifest.json';
    final bytes = _files[path];
    if (bytes == null) {
      return null;
    }
    final contentString = utf8.decode(bytes);
    final content = jsonDecode(contentString) as Map<String, dynamic>;
    final revision = _revisions[path] ?? 'rev_0';
    return CloudManifest(content: content, revision: revision);
  }

  @override
  Future<void> writeManifest(
    Map<String, dynamic> manifestData, {
    String? expectedRevision,
  }) async {
    const path = 'manifest.json';
    final currentRevision = _revisions[path];

    if (expectedRevision != null) {
      if (currentRevision != expectedRevision) {
        throw StateError(
          'Revision mismatch: expected "$expectedRevision", but got "$currentRevision"',
        );
      }
    }

    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(manifestData)));
    _files[path] = bytes;
    _revisions[path] = _nextRevision();
  }

  @override
  Future<Uint8List?> readFile(String path) async {
    return _files[path];
  }

  @override
  Future<void> writeFile(
    String path,
    Uint8List bytes, {
    String? expectedRevision,
  }) async {
    final currentRevision = _revisions[path];

    if (expectedRevision != null) {
      if (currentRevision != expectedRevision) {
        throw StateError(
          'Revision mismatch: expected "$expectedRevision", but got "$currentRevision"',
        );
      }
    }

    _files[path] = bytes;
    _revisions[path] = _nextRevision();
  }

  @override
  Future<List<CloudFileInfo>> listFiles(String prefix) async {
    final results = <CloudFileInfo>[];
    _files.forEach((path, bytes) {
      if (path.startsWith(prefix)) {
        results.add(
          CloudFileInfo(
            path: path,
            sizeBytes: bytes.length,
            lastModified: DateTime.now(),
            revision: _revisions[path],
          ),
        );
      }
    });
    return results;
  }

  @override
  Future<void> deleteFile(String path) async {
    _files.remove(path);
    _revisions.remove(path);
  }

  // Debug helper to inspect raw files in tests
  Map<String, Uint8List> get files => _files;
}
