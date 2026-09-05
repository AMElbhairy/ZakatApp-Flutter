import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'user_cloud_storage_provider.dart';
import '../sync_diagnostics_service.dart';

enum DriveConnectionFailureReason {
  cancelled,
  permissionDenied,
  driveApiDisabled,
  oauthTestUserMissing,
  missingIosConfig,
  authMissing,
  unknown,
}

class DriveConnectionStatus {
  const DriveConnectionStatus({
    required this.connected,
    this.failureReason,
    this.message,
    this.grantedScopes = const <String>[],
    this.accountEmail,
  });

  final bool connected;
  final DriveConnectionFailureReason? failureReason;
  final String? message;
  final List<String> grantedScopes;
  final String? accountEmail;
}

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
        (request.method == 'POST' ||
            request.method == 'PATCH' ||
            request.method == 'PUT')) {
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
  final GoogleSignIn? googleSignIn;
  final Future<bool> Function()? hasGrantedDriveScope;
  final Future<void> Function(bool granted)? setGrantedDriveScope;
  final String namespacePrefix;
  final http.Client? _mockHttpClient;

  static const List<String> _driveScopes = <String>[
    'https://www.googleapis.com/auth/drive.appdata',
  ];

  DriveConnectionStatus? _lastConnectionStatus;

  GoogleDriveStorageProvider({
    required this.getAuthHeaders,
    required this.checkConnected,
    required this.requestConnect,
    required this.requestDisconnect,
    this.googleSignIn,
    this.hasGrantedDriveScope,
    this.setGrantedDriveScope,
    this.namespacePrefix = '',
    http.Client? httpClient,
  }) : _mockHttpClient = httpClient;

  @override
  String get providerId => 'google_drive';

  @override
  Future<bool> isConnected() async {
    if (googleSignIn != null) {
      try {
        final bool canAccess = await googleSignIn!.canAccessScopes(
          _driveScopes,
        );
        if (!canAccess) {
          if (setGrantedDriveScope != null) {
            await setGrantedDriveScope!(false);
          }
          _lastConnectionStatus = const DriveConnectionStatus(
            connected: false,
            message: 'Google Drive is not connected.',
          );
          return false;
        }
      } catch (_) {
        // Fall through to the slower probe when the client cannot confirm scope state.
      }

      final status = await resolveConnection(
        interactive: false,
        phase: 'is_connected',
      );
      return status.connected;
    }
    return checkConnected();
  }

  @override
  Future<bool> connect() async {
    if (googleSignIn != null) {
      final status = await resolveConnection(
        interactive: true,
        phase: 'connect',
      );
      return status.connected;
    }
    return requestConnect();
  }

  @override
  Future<void> disconnect() => requestDisconnect();

  drive.DriveApi _getDriveApi() {
    return drive.DriveApi(
      AuthenticatedClient(getAuthHeaders, inner: _mockHttpClient),
    );
  }

  String _scopePath(String path) {
    final String cleanNamespace = namespacePrefix.trim();
    final String cleanPath = path.trim();
    if (cleanNamespace.isEmpty) {
      return cleanPath;
    }
    if (cleanPath.isEmpty) {
      return cleanNamespace;
    }
    if (cleanPath == cleanNamespace ||
        cleanPath.startsWith('$cleanNamespace/')) {
      return cleanPath;
    }
    return '$cleanNamespace/$cleanPath';
  }

  String _scopePrefix(String prefix) {
    final String cleanNamespace = namespacePrefix.trim();
    final String cleanPrefix = prefix.trim();
    if (cleanNamespace.isEmpty) {
      return cleanPrefix;
    }
    if (cleanPrefix.isEmpty) {
      return '$cleanNamespace/';
    }
    if (cleanPrefix == cleanNamespace ||
        cleanPrefix.startsWith('$cleanNamespace/')) {
      return cleanPrefix;
    }
    return '$cleanNamespace/$cleanPrefix';
  }

  DriveConnectionStatus? get lastConnectionStatus => _lastConnectionStatus;
  String? get lastConnectionErrorMessage => _lastConnectionStatus?.message;

  void _logAuth(String phase, {GoogleSignInAccount? account, Object? error}) {
    final String providerIds = _providerIds().join(',');
    final String googleAccount =
        account?.email ?? googleSignIn?.currentUser?.email ?? 'null';
    final String errMsg = error?.toString() ?? 'none';
    SyncDiagnosticsService.record(
      level: error != null ? 'error' : 'info',
      subsystem: 'google_drive',
      message: 'Auth phase: $phase',
      metadata: <String, dynamic>{
        'providerIds': providerIds,
        'googleAccount': googleAccount,
        'error': errMsg,
      },
    );
  }

  List<String> _providerIds() {
    final List<String> values = <String>[];
    final GoogleSignInAccount? account = googleSignIn?.currentUser;
    if (account != null) {
      values.add(account.email);
    }
    return values;
  }

  Future<GoogleSignInAccount?> _resolveGoogleAccount({
    required bool interactive,
  }) async {
    if (googleSignIn == null) return null;
    GoogleSignInAccount? account;
    try {
      account = await googleSignIn!.signInSilently();
      _logAuth('sign_in_silently', account: account);
    } catch (error) {
      _logAuth('sign_in_silently_error', error: error);
    }

    if (account == null && interactive) {
      account = await googleSignIn!.signIn();
      _logAuth('sign_in', account: account);
    }

    return account;
  }

  Future<DriveConnectionStatus> _probeAppDataAccess({
    required String phase,
    required GoogleSignInAccount account,
  }) async {
    try {
      final headers = await account.authHeaders;
      final api = drive.DriveApi(
        AuthenticatedClient(() async => headers, inner: _mockHttpClient),
      );
      final list = await api.files.list(
        spaces: 'appDataFolder',
        pageSize: 1,
        $fields: 'files(id)',
      );
      _logAuth(
        '$phase:drive_probe',
        account: account,
        error: 'success files=${list.files?.length ?? 0}',
      );
      return DriveConnectionStatus(
        connected: true,
        grantedScopes: _driveScopes,
        accountEmail: account.email,
      );
    } on drive.DetailedApiRequestError catch (error) {
      final message = _mapDriveApiError(error);
      _logAuth('$phase:drive_probe_error', account: account, error: message);
      return DriveConnectionStatus(
        connected: false,
        failureReason: _failureReasonFromDriveError(error),
        message: message,
        grantedScopes: _driveScopes,
        accountEmail: account.email,
      );
    } catch (error) {
      final message = _mapGenericConnectionError(error);
      _logAuth('$phase:drive_probe_error', account: account, error: message);
      return DriveConnectionStatus(
        connected: false,
        failureReason: _failureReasonFromGenericError(error),
        message: message,
        grantedScopes: _driveScopes,
        accountEmail: account.email,
      );
    }
  }

  DriveConnectionFailureReason _failureReasonFromDriveError(
    drive.DetailedApiRequestError error,
  ) {
    final String raw = '${error.message} ${error.toString()}'.toLowerCase();
    if (error.status == 401) {
      return DriveConnectionFailureReason.authMissing;
    }
    if (error.status == 403) {
      if (raw.contains('access_not_configured') ||
          raw.contains('drive api has not been used') ||
          raw.contains('api not used')) {
        return DriveConnectionFailureReason.driveApiDisabled;
      }
      if (raw.contains('test user') ||
          raw.contains('testing') ||
          raw.contains('oauth consent')) {
        return DriveConnectionFailureReason.oauthTestUserMissing;
      }
      return DriveConnectionFailureReason.permissionDenied;
    }
    if (error.status == 404) {
      return DriveConnectionFailureReason.driveApiDisabled;
    }
    return DriveConnectionFailureReason.unknown;
  }

  DriveConnectionFailureReason _failureReasonFromGenericError(Object error) {
    final String raw = error.toString().toLowerCase();
    if (raw.contains('cancel') ||
        raw.contains('canceled') ||
        raw.contains('cancelled')) {
      return DriveConnectionFailureReason.cancelled;
    }
    if (raw.contains('reversed_client_id') ||
        raw.contains('client id') ||
        raw.contains('url scheme') ||
        raw.contains('gIDclientid'.toLowerCase())) {
      return DriveConnectionFailureReason.missingIosConfig;
    }
    if (raw.contains('403')) {
      return DriveConnectionFailureReason.permissionDenied;
    }
    return DriveConnectionFailureReason.unknown;
  }

  String _mapDriveApiError(drive.DetailedApiRequestError error) {
    final raw = error.toString();
    if (error.status == 401) {
      return 'Google Drive authorization is missing or expired.';
    }
    if (error.status == 403) {
      if (raw.toLowerCase().contains('access_not_configured') ||
          raw.toLowerCase().contains('drive api has not been used')) {
        return 'Google Drive API is disabled or not configured for this project.';
      }
      if (raw.toLowerCase().contains('test user') ||
          raw.toLowerCase().contains('oauth consent')) {
        return 'Google OAuth consent screen may need the account added as a test user.';
      }
      return 'Google Drive permission was denied.';
    }
    if (error.status == 404) {
      return 'Google Drive API appears to be unavailable for this account.';
    }
    return 'Google Drive access could not be completed.';
  }

  String _mapGenericConnectionError(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('cancel')) {
      return 'Google Drive connection was cancelled.';
    }
    if (lower.contains('reversed_client_id') ||
        lower.contains('url scheme') ||
        lower.contains('client id') ||
        lower.contains('gidclientid')) {
      return 'Google Drive iOS client configuration is missing or invalid.';
    }
    return 'Google Drive connection could not be completed.';
  }

  Future<DriveConnectionStatus> resolveConnection({
    required bool interactive,
    required String phase,
  }) async {
    _lastConnectionStatus = null;
    _logAuth('$phase:start');

    final account = await _resolveGoogleAccount(interactive: interactive);
    if (account == null) {
      final status = DriveConnectionStatus(
        connected: false,
        failureReason: DriveConnectionFailureReason.cancelled,
        message: interactive
            ? 'Google Drive connection was cancelled.'
            : 'Google Drive is not connected.',
      );
      _lastConnectionStatus = status;
      return status;
    }

    if (!interactive) {
      try {
        final bool canAccess = await googleSignIn!.canAccessScopes(
          _driveScopes,
        );
        if (!canAccess) {
          final status = DriveConnectionStatus(
            connected: false,
            failureReason: DriveConnectionFailureReason.permissionDenied,
            message: 'Google Drive permission is required for cloud backup.',
            grantedScopes: const <String>[],
            accountEmail: account.email,
          );
          if (setGrantedDriveScope != null) {
            await setGrantedDriveScope!(false);
          }
          _lastConnectionStatus = status;
          return status;
        }
      } catch (_) {
        // If the plugin cannot answer scope access directly, fall back to probing.
      }
      final status = await _probeAppDataAccess(phase: phase, account: account);
      if (status.connected && setGrantedDriveScope != null) {
        await setGrantedDriveScope!(true);
      } else if (setGrantedDriveScope != null) {
        await setGrantedDriveScope!(false);
      }
      _lastConnectionStatus = status;
      return status;
    }

    final bool alreadyAuthorized = await googleSignIn!.canAccessScopes(
      _driveScopes,
    );
    final bool requested = alreadyAuthorized
        ? true
        : await googleSignIn!.requestScopes(_driveScopes);
    _logAuth(
      '$phase:request_scopes',
      account: account,
      error: requested ? null : 'denied',
    );

    final status = await _probeAppDataAccess(phase: phase, account: account);

    if (!requested) {
      if (setGrantedDriveScope != null) {
        await setGrantedDriveScope!(false);
      }
      final deniedStatus = DriveConnectionStatus(
        connected: false,
        failureReason: DriveConnectionFailureReason.permissionDenied,
        message: 'Google Drive permission is required for cloud backup.',
        grantedScopes: _driveScopes,
        accountEmail: account.email,
      );
      _lastConnectionStatus = deniedStatus;
      return deniedStatus;
    }

    if (setGrantedDriveScope != null && !status.connected) {
      await setGrantedDriveScope!(false);
    }
    if (setGrantedDriveScope != null) {
      await setGrantedDriveScope!(status.connected);
    }

    final resolved = DriveConnectionStatus(
      connected: status.connected,
      failureReason: status.failureReason,
      message: status.message,
      grantedScopes: _driveScopes,
      accountEmail: account.email,
    );
    _lastConnectionStatus = resolved;
    return resolved;
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
    final String path = _scopePath('manifest.json');
    final api = _getDriveApi();
    final file = await _findFile(api, path);
    if (file == null || file.id == null) {
      return null;
    }

    final drive.Media media =
        await api.files.get(
              file.id!,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

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
    final String path = _scopePath('manifest.json');
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
        throw StateError(
          'Revision mismatch (Google Drive ETag mismatch): ${e.message}',
        );
      }
      rethrow;
    }
  }

  @override
  Future<Uint8List?> readFile(String path) async {
    final api = _getDriveApi();
    final file = await _findFile(api, _scopePath(path));
    if (file == null || file.id == null) {
      return null;
    }

    final drive.Media media =
        await api.files.get(
              file.id!,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

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
    final String scopedPath = _scopePath(path);
    final file = await _findFile(api, scopedPath);

    final media = drive.Media(Stream.value(bytes), bytes.length);

    try {
      if (file == null) {
        if (expectedRevision != null && expectedRevision.isNotEmpty) {
          throw StateError(
            'Revision mismatch: file does not exist, but expectedRevision "$expectedRevision" was provided.',
          );
        }
        final driveFile = drive.File()
          ..name = scopedPath
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
        throw StateError(
          'Revision mismatch (Google Drive ETag mismatch): ${e.message}',
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<CloudFileInfo>> listFiles(String prefix) async {
    final api = _getDriveApi();
    final String scopedPrefix = _scopePrefix(prefix);
    final String cleanNamespace = namespacePrefix.trim();
    final list = await api.files.list(
      spaces: 'appDataFolder',
      q: "trashed = false",
      $fields: 'files(id, name, size, modifiedTime, headRevisionId)',
    );

    if (list.files == null) {
      return [];
    }

    return list.files!
        .where(
          (file) => file.name != null && file.name!.startsWith(scopedPrefix),
        )
        .map((file) {
          final String rawPath = file.name ?? '';
          final String exposedPath =
              cleanNamespace.isNotEmpty &&
                  rawPath.startsWith('$cleanNamespace/')
              ? rawPath.substring(cleanNamespace.length + 1)
              : rawPath;
          final sizeString = file.size;
          final sizeBytes = sizeString != null
              ? int.tryParse(sizeString) ?? 0
              : 0;
          return CloudFileInfo(
            path: exposedPath,
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
    final file = await _findFile(api, _scopePath(path));
    if (file != null && file.id != null) {
      await api.files.delete(file.id!);
    }
  }
}
