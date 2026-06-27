import 'dart:typed_data';

/// Metadata representing a file stored in the cloud.
class CloudFileInfo {
  const CloudFileInfo({
    required this.path,
    required this.sizeBytes,
    required this.lastModified,
    this.revision,
  });

  final String path;
  final int sizeBytes;
  final DateTime lastModified;
  final String? revision; // ETag or version ID provided by storage
}

/// Abstract manifest state returned after a read.
class CloudManifest {
  const CloudManifest({
    required this.content,
    required this.revision,
  });

  final Map<String, dynamic> content;
  final String revision; // Provider-specific ETag or revision number
}

/// Interface for user-owned cloud storage sync providers.
abstract class UserCloudStorageProvider {
  /// Unique identifier of the provider (e.g. 'google_drive', 'icloud').
  String get providerId;

  /// Returns true if the user has authenticated and connected this storage provider.
  Future<bool> isConnected();

  /// Prompts the user to authorize access to their cloud storage container.
  Future<bool> connect();

  /// Revokes authorization and disconnects the storage provider locally.
  Future<void> disconnect();

  /// Reads the global manifest.json file from the cloud.
  /// Returns null if the manifest does not exist.
  Future<CloudManifest?> readManifest();

  /// Writes the global manifest.json file.
  /// If [expectedRevision] is provided, performs a conditional write (optimistic locking).
  /// Throws a [StateError] if the current cloud revision does not match [expectedRevision].
  Future<void> writeManifest(
    Map<String, dynamic> manifestData, {
    String? expectedRevision,
  });

  /// Downloads the binary payload of a cloud file.
  Future<Uint8List?> readFile(String path);

  /// Writes a binary file to the cloud.
  /// Supports optional optimistic locking via [expectedRevision].
  Future<void> writeFile(
    String path,
    Uint8List bytes, {
    String? expectedRevision,
  });

  /// Lists all files matching a specific prefix.
  Future<List<CloudFileInfo>> listFiles(String prefix);

  /// Deletes a file at the specified path.
  Future<void> deleteFile(String path);
}
