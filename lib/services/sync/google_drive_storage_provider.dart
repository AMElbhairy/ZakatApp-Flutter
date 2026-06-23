import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:googleapis/drive/v3.dart' as drive;
import 'user_cloud_storage_provider.dart';

class AuthenticatedClient extends http.BaseClient {
  final Future<Map<String, String>> Function() _getHeaders;
  final http.Client _inner;

  AuthenticatedClient(this._getHeaders, {http.Client? inner})
      : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final headers = await _getHeaders();
    request.headers.addAll(headers);

    // Dynamic If-Match injection from Zone variable
    final ifMatch = Zone.current[#ifMatch] as String?;
    if (ifMatch != null &&
        (request.method == 'POST' || request.method == 'PATCH' || request.method == 'PUT')) {
      request.headers['If-Match'] = ifMatch;
    }

    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

class GoogleDriveStorageProvider implements UserCloudStorageProvider {
  final Future<Map<String, String>> Function() getAuthHeaders;
  final Future<bool> Function() checkConnected;
  final Future<bool> Function() requestConnect;
  final Future<void> Function() requestDisconnect;
  final http.Client? _mockHttpClient;

  GoogleDriveStorageProvider({
    required this.getAuthHeaders,
    required this.checkConnected,
    required this.requestConnect,
    required this.requestDisconnect,
    http.Client? httpClient,
  }) : _mockHttpClient = httpClient;

  @override
  String get providerId => 'google_drive';

  @override
  Future<bool> isConnected() => checkConnected();

  @override
  Future<bool> connect() => requestConnect();

  @override
  Future<void> disconnect() => requestDisconnect();

  drive.DriveApi _getDriveApi() {
    return drive.DriveApi(AuthenticatedClient(getAuthHeaders, inner: _mockHttpClient));
  }

  Future<drive.File?> _findFile(drive.DriveApi api, String path) async {
    final escapedPath = path.replaceAll("'", "\\'");
    final list = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$escapedPath' and trashed = false",
      $fields: 'files(id, name, size, modifiedTime, headRevisionId)',
    );
    if (list.files == null || list.files!.isEmpty) {
      return null;
    }
    return list.files!.first;
  }

  @override
  Future<CloudManifest?> readManifest() async {
    const path = 'manifest.json';
    final api = _getDriveApi();
    final file = await _findFile(api, path);
    if (file == null || file.id == null) {
      return null;
    }

    final drive.Media media = await api.files.get(
      file.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytesBuilder = BytesBuilder();
    await for (final chunk in media.stream) {
      bytesBuilder.add(chunk);
    }
    final bytes = bytesBuilder.takeBytes();
    final contentString = utf8.decode(bytes);
    final content = jsonDecode(contentString) as Map<String, dynamic>;

    return CloudManifest(
      content: content,
      revision: file.headRevisionId ?? file.id!,
    );
  }

  @override
  Future<void> writeManifest(
    Map<String, dynamic> manifestData, {
    String? expectedRevision,
  }) async {
    const path = 'manifest.json';
    final api = _getDriveApi();
    final file = await _findFile(api, path);

    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(manifestData)));
    final media = drive.Media(Stream.value(bytes), bytes.length);

    try {
      if (file == null) {
        if (expectedRevision != null && expectedRevision.isNotEmpty) {
          throw StateError(
            'Revision mismatch: manifest does not exist, but expectedRevision "$expectedRevision" was provided.',
          );
        }
        final driveFile = drive.File()
          ..name = path
          ..parents = ['appDataFolder'];
        await api.files.create(driveFile, uploadMedia: media);
      } else {
        final fileId = file.id!;
        final driveFile = drive.File();

        if (expectedRevision != null) {
          await runZoned(
            () => api.files.update(driveFile, fileId, uploadMedia: media),
            zoneValues: {#ifMatch: expectedRevision},
          );
        } else {
          await api.files.update(driveFile, fileId, uploadMedia: media);
        }
      }
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status == 412) {
        throw StateError('Revision mismatch (Google Drive ETag mismatch): ${e.message}');
      }
      rethrow;
    }
  }

  @override
  Future<Uint8List?> readFile(String path) async {
    final api = _getDriveApi();
    final file = await _findFile(api, path);
    if (file == null || file.id == null) {
      return null;
    }

    final drive.Media media = await api.files.get(
      file.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytesBuilder = BytesBuilder();
    await for (final chunk in media.stream) {
      bytesBuilder.add(chunk);
    }
    return bytesBuilder.takeBytes();
  }

  @override
  Future<void> writeFile(
    String path,
    Uint8List bytes, {
    String? expectedRevision,
  }) async {
    final api = _getDriveApi();
    final file = await _findFile(api, path);

    final media = drive.Media(Stream.value(bytes), bytes.length);

    try {
      if (file == null) {
        if (expectedRevision != null && expectedRevision.isNotEmpty) {
          throw StateError(
            'Revision mismatch: file does not exist, but expectedRevision "$expectedRevision" was provided.',
          );
        }
        final driveFile = drive.File()
          ..name = path
          ..parents = ['appDataFolder'];
        await api.files.create(driveFile, uploadMedia: media);
      } else {
        final fileId = file.id!;
        final driveFile = drive.File();

        if (expectedRevision != null) {
          await runZoned(
            () => api.files.update(driveFile, fileId, uploadMedia: media),
            zoneValues: {#ifMatch: expectedRevision},
          );
        } else {
          await api.files.update(driveFile, fileId, uploadMedia: media);
        }
      }
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status == 412) {
        throw StateError('Revision mismatch (Google Drive ETag mismatch): ${e.message}');
      }
      rethrow;
    }
  }

  @override
  Future<List<CloudFileInfo>> listFiles(String prefix) async {
    final api = _getDriveApi();
    final list = await api.files.list(
      spaces: 'appDataFolder',
      q: "trashed = false",
      $fields: 'files(id, name, size, modifiedTime, headRevisionId)',
    );

    if (list.files == null) {
      return [];
    }

    return list.files!
        .where((file) => file.name != null && file.name!.startsWith(prefix))
        .map((file) {
          final sizeString = file.size;
          final sizeBytes = sizeString != null ? int.tryParse(sizeString) ?? 0 : 0;
          return CloudFileInfo(
            path: file.name ?? '',
            sizeBytes: sizeBytes,
            lastModified: file.modifiedTime ?? DateTime.now(),
            revision: file.headRevisionId ?? file.id,
          );
        })
        .toList();
  }

  @override
  Future<void> deleteFile(String path) async {
    final api = _getDriveApi();
    final file = await _findFile(api, path);
    if (file != null && file.id != null) {
      await api.files.delete(file.id!);
    }
  }
}
