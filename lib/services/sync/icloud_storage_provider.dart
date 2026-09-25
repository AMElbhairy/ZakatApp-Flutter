import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'user_cloud_storage_provider.dart';

enum ICloudAvailability {
  unavailable,
  checking,
  available,
  connected,
  syncing,
  error,
}

class ICloudStorageProvider implements UserCloudStorageProvider {
  final String namespacePrefix;
  final MethodChannel _channel;
  bool _simulationFallbackActive = false;

  ICloudStorageProvider({this.namespacePrefix = '', MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.zakatapp.icloud');

  @override
  String get providerId => 'icloud';

  bool get _shouldSimulate {
    if (kDebugMode) {
      if (!Platform.isIOS && !Platform.isMacOS) {
        return true;
      }
      return _simulationFallbackActive;
    }
    return false;
  }

  bool get isSupportedPlatform {
    return Platform.isIOS || Platform.isMacOS || _shouldSimulate;
  }

  Future<ICloudAvailability> getAvailability() async {
    if (!isSupportedPlatform) {
      return ICloudAvailability.unavailable;
    }
    if (_shouldSimulate) {
      return ICloudAvailability.connected;
    }
    try {
      final String? status = await _channel.invokeMethod<String>(
        'getAvailability',
      );
      final availability = switch (status) {
        'checking' => ICloudAvailability.checking,
        'available' => ICloudAvailability.available,
        'connected' => ICloudAvailability.connected,
        'syncing' => ICloudAvailability.syncing,
        'error' => ICloudAvailability.error,
        _ => ICloudAvailability.unavailable,
      };
      if (kDebugMode && availability == ICloudAvailability.unavailable) {
        _simulationFallbackActive = true;
        return ICloudAvailability.connected;
      }
      return availability;
    } catch (_) {
      if (kDebugMode) {
        _simulationFallbackActive = true;
        return ICloudAvailability.connected;
      }
      return ICloudAvailability.error;
    }
  }

  @override
  Future<bool> isConnected() async {
    final availability = await getAvailability();
    return availability == ICloudAvailability.connected ||
        availability == ICloudAvailability.syncing;
  }

  @override
  Future<bool> connect() async {
    if (!isSupportedPlatform) {
      return false;
    }
    if (_shouldSimulate) {
      return true;
    }
    try {
      final bool? success = await _channel.invokeMethod<bool>('connect');
      if (success == true) {
        return true;
      }
      if (kDebugMode) {
        _simulationFallbackActive = true;
        return true;
      }
      return false;
    } catch (_) {
      if (kDebugMode) {
        _simulationFallbackActive = true;
        return true;
      }
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    if (!isSupportedPlatform || _shouldSimulate) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('disconnect');
    } catch (_) {}
  }

  Future<Directory> _getSimulationDirectory() async {
    final appSupportDir = await getApplicationSupportDirectory();
    final dir = Directory(
      '${appSupportDir.path}/icloud_simulation/$namespacePrefix',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _scopePath(String path) {
    if (namespacePrefix.isEmpty) return path;
    return '$namespacePrefix/$path';
  }

  @override
  Future<CloudManifest?> readManifest() async {
    if (!isSupportedPlatform) {
      throw StateError('iCloud is not supported on this platform.');
    }
    if (_shouldSimulate) {
      final dir = await _getSimulationDirectory();
      final file = File('${dir.path}/manifest.json');
      if (!await file.exists()) {
        return null;
      }
      final content = await file.readAsString();
      return CloudManifest(
        content: jsonDecode(content) as Map<String, dynamic>,
        revision: 'sim_rev_${content.hashCode}',
      );
    }

    try {
      final String? result = await _channel.invokeMethod<String>(
        'readManifest',
        {'namespace': namespacePrefix},
      );
      if (result == null) return null;
      final data = jsonDecode(result) as Map<String, dynamic>;
      final dynamic rawContent = data['content'];
      final Map<String, dynamic> content = rawContent is Map<String, dynamic>
          ? rawContent
          : rawContent is String
          ? Map<String, dynamic>.from(
              jsonDecode(rawContent) as Map<dynamic, dynamic>,
            )
          : throw StateError('Invalid iCloud manifest payload.');
      return CloudManifest(
        content: content,
        revision: data['revision']?.toString() ?? '1',
      );
    } catch (e) {
      debugPrint('iCloud readManifest error: $e');
      return null;
    }
  }

  @override
  Future<void> writeManifest(
    Map<String, dynamic> manifestData, {
    String? expectedRevision,
  }) async {
    if (!isSupportedPlatform) {
      throw StateError('iCloud is not supported on this platform.');
    }
    if (_shouldSimulate) {
      final dir = await _getSimulationDirectory();
      final file = File('${dir.path}/manifest.json');
      await file.writeAsString(jsonEncode(manifestData));
      return;
    }

    try {
      await _channel.invokeMethod<void>('writeManifest', {
        'namespace': namespacePrefix,
        'manifestData': jsonEncode(manifestData),
        'expectedRevision': expectedRevision,
      });
    } catch (e) {
      throw StateError('iCloud writeManifest error: $e');
    }
  }

  @override
  Future<Uint8List?> readFile(String path) async {
    if (!isSupportedPlatform) {
      throw StateError('iCloud is not supported on this platform.');
    }
    if (_shouldSimulate) {
      final dir = await _getSimulationDirectory();
      final file = File('${dir.path}/$path');
      if (!await file.exists()) {
        return null;
      }
      return file.readAsBytes();
    }

    try {
      final Uint8List? bytes = await _channel.invokeMethod<Uint8List>(
        'readFile',
        {'namespace': namespacePrefix, 'path': path},
      );
      return bytes;
    } catch (e) {
      debugPrint('iCloud readFile error ($path): $e');
      return null;
    }
  }

  @override
  Future<void> writeFile(
    String path,
    Uint8List bytes, {
    String? expectedRevision,
  }) async {
    if (!isSupportedPlatform) {
      throw StateError('iCloud is not supported on this platform.');
    }
    if (_shouldSimulate) {
      final dir = await _getSimulationDirectory();
      final file = File('${dir.path}/$path');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      return;
    }

    try {
      await _channel.invokeMethod<void>('writeFile', {
        'namespace': namespacePrefix,
        'path': path,
        'bytes': bytes,
        'expectedRevision': expectedRevision,
      });
    } catch (e) {
      throw StateError('iCloud writeFile error ($path): $e');
    }
  }

  @override
  Future<List<CloudFileInfo>> listFiles(String prefix) async {
    if (!isSupportedPlatform) {
      throw StateError('iCloud is not supported on this platform.');
    }
    if (_shouldSimulate) {
      final dir = await _getSimulationDirectory();
      final List<CloudFileInfo> results = [];
      final targetDir = Directory('${dir.path}/$prefix');
      if (await targetDir.exists()) {
        await for (final entity in targetDir.list(recursive: true)) {
          if (entity is File) {
            final relPath = entity.path.substring(dir.path.length + 1);
            final stat = await entity.stat();
            results.add(
              CloudFileInfo(
                path: relPath,
                sizeBytes: stat.size,
                lastModified: stat.modified,
                revision:
                    'sim_rev_${stat.size}_${stat.modified.millisecondsSinceEpoch}',
              ),
            );
          }
        }
      }
      return results;
    }

    try {
      final List<dynamic>? list = await _channel.invokeMethod<List<dynamic>>(
        'listFiles',
        {'namespace': namespacePrefix, 'prefix': prefix},
      );
      if (list == null) return [];
      return list.map((dynamic item) {
        final map = Map<String, dynamic>.from(item as Map);
        return CloudFileInfo(
          path: map['path'].toString(),
          sizeBytes: map['sizeBytes'] as int,
          lastModified: DateTime.fromMillisecondsSinceEpoch(
            map['lastModified'] as int,
          ),
          revision: map['revision']?.toString(),
        );
      }).toList();
    } catch (e) {
      debugPrint('iCloud listFiles error ($prefix): $e');
      return [];
    }
  }

  @override
  Future<void> deleteFile(String path) async {
    if (!isSupportedPlatform) {
      throw StateError('iCloud is not supported on this platform.');
    }
    if (_shouldSimulate) {
      final dir = await _getSimulationDirectory();
      final file = File('${dir.path}/$path');
      if (await file.exists()) {
        await file.delete();
      }
      return;
    }

    try {
      await _channel.invokeMethod<void>('deleteFile', {
        'namespace': namespacePrefix,
        'path': path,
      });
    } catch (e) {
      throw StateError('iCloud deleteFile error ($path): $e');
    }
  }
}
