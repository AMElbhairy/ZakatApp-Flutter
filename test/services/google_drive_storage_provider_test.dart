import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:zakatapp_flutter/services/sync/google_drive_storage_provider.dart';

class _MockFile {
  _MockFile({
    required this.id,
    required this.name,
    required this.content,
    required this.revision,
    required this.modifiedTime,
  });

  final String id;
  final String name;
  Uint8List content;
  String revision;
  DateTime modifiedTime;
}

Uint8List? _extractMediaBytes(Uint8List bodyBytes, String bodyString) {
  int occurrence = 0;
  int index = -1;
  for (int i = 0; i < bodyBytes.length - 3; i++) {
    if (bodyBytes[i] == 13 && bodyBytes[i + 1] == 10 && bodyBytes[i + 2] == 13 && bodyBytes[i + 3] == 10) {
      occurrence++;
      if (occurrence == 2) {
        index = i + 4;
        break;
      }
    }
  }
  if (index != -1) {
    int end = bodyBytes.length;
    for (int i = index; i < bodyBytes.length - 4; i++) {
      if (bodyBytes[i] == 13 && bodyBytes[i + 1] == 10 && bodyBytes[i + 2] == 45 && bodyBytes[i + 3] == 45) {
        end = i;
        break;
      }
    }
    final rawBytes = bodyBytes.sublist(index, end);
    // Googleapis encodes multipart attachments in base64 if they contain binary or complex strings
    if (bodyString.contains('content-transfer-encoding: base64') || bodyString.contains('base64')) {
      final base64String = utf8.decode(rawBytes).trim();
      return base64.decode(base64String);
    }
    return rawBytes;
  }
  return null;
}

class _FakeGoogleSignInAccount extends Fake implements GoogleSignInAccount {
  _FakeGoogleSignInAccount(this.email);

  @override
  final String email;

  @override
  String get displayName => 'Test User';

  @override
  Future<Map<String, String>> get authHeaders async => {'Authorization': 'Bearer test-token'};
}

class _FakeGoogleSignIn extends Fake implements GoogleSignIn {
  _FakeGoogleSignInAccount? account;
  bool allowInteractiveSignIn = true;
  bool requestScopesAllowed = true;
  bool driveScopeGranted = false;
  int signInSilentlyCalls = 0;
  int signInCalls = 0;
  int requestScopesCalls = 0;

  _FakeGoogleSignIn({String email = 'user@example.com'}) {
    account = _FakeGoogleSignInAccount(email);
  }

  @override
  Future<bool> isSignedIn() async => account != null;

  @override
  Future<GoogleSignInAccount?> signInSilently({
    bool suppressErrors = true,
    bool reAuthenticate = false,
  }) async {
    signInSilentlyCalls += 1;
    return account;
  }

  @override
  Future<GoogleSignInAccount?> signIn() async {
    signInCalls += 1;
    if (!allowInteractiveSignIn) return null;
    account ??= _FakeGoogleSignInAccount('user@example.com');
    return account;
  }

  @override
  Future<GoogleSignInAccount?> signOut() async {
    account = null;
    driveScopeGranted = false;
    return null;
  }

  @override
  Future<bool> canAccessScopes(List<String> scopes, {String? accessToken}) async {
    return account != null && driveScopeGranted;
  }

  @override
  GoogleSignInAccount? get currentUser => account;

  @override
  Future<bool> requestScopes(List<String> scopes) async {
    requestScopesCalls += 1;
    if (!requestScopesAllowed) {
      driveScopeGranted = false;
      return false;
    }
    driveScopeGranted = true;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GoogleDriveStorageProvider Tests with Mock HTTP Client', () {
    late Map<String, _MockFile> driveStore;
    late int fileIdCounter;
    late int revisionCounter;

    setUp(() {
      driveStore = {};
      fileIdCounter = 0;
      revisionCounter = 0;
    });

    String nextFileId() => 'file_id_${++fileIdCounter}';
    String nextRevision() => 'rev_id_${++revisionCounter}';

    http.Client createMockDriveHttpClient() {
      return MockClient((request) async {
        final uri = request.url;

        // 1. GET requests (List or Download)
        if (request.method == 'GET') {
          if (uri.path.endsWith('/files')) {
            final q = uri.queryParameters['q'] ?? '';
            final filesJson = <Map<String, dynamic>>[];

            for (final file in driveStore.values) {
              bool match = true;
              if (q.contains("name = '")) {
                final namePattern = q.split("name = '")[1].split("'")[0];
                if (file.name != namePattern) match = false;
              }
              if (match) {
                filesJson.add({
                  'id': file.id,
                  'name': file.name,
                  'size': file.content.length.toString(),
                  'modifiedTime': file.modifiedTime.toUtc().toIso8601String(),
                  'headRevisionId': file.revision,
                });
              }
            }

            return http.Response(
              jsonEncode({'files': filesJson}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          } else if (uri.path.contains('/files/')) {
            final segments = uri.pathSegments;
            final fileId = segments[segments.indexOf('files') + 1];
            final file = driveStore[fileId];

            if (file == null) {
              return http.Response('File not found', 404);
            }

            if (uri.queryParameters['alt'] == 'media') {
              return http.Response.bytes(
                file.content,
                200,
                headers: {'content-type': 'application/octet-stream'},
              );
            } else {
              return http.Response(
                jsonEncode({
                  'id': file.id,
                  'name': file.name,
                  'size': file.content.length.toString(),
                  'modifiedTime': file.modifiedTime.toUtc().toIso8601String(),
                  'headRevisionId': file.revision,
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }
          }
        }

        // 2. POST requests (Create files)
        if (request.method == 'POST' && uri.path.endsWith('/files')) {
          final contentType = request.headers['content-type'] ?? '';
          String? name;
          Uint8List? fileContent;

          if (contentType.contains('multipart')) {
            final bodyBytes = request.bodyBytes;
            final bodyString = utf8.decode(bodyBytes, allowMalformed: true);
            
            final nameMatch = RegExp(r'"name"\s*:\s*"([^"]+)"').firstMatch(bodyString);
            if (nameMatch != null) {
              name = nameMatch.group(1);
            }
            fileContent = _extractMediaBytes(bodyBytes, bodyString);
          }

          name ??= 'unknown';
          fileContent ??= Uint8List(0);

          final id = nextFileId();
          final rev = nextRevision();
          final newFile = _MockFile(
            id: id,
            name: name,
            content: fileContent,
            revision: rev,
            modifiedTime: DateTime.now(),
          );
          driveStore[id] = newFile;

          return http.Response(
            jsonEncode({
              'id': id,
              'name': name,
              'headRevisionId': rev,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        // 3. PATCH / PUT requests (Update files)
        if (request.method == 'PATCH' || request.method == 'PUT') {
          final segments = uri.pathSegments;
          final fileId = segments.firstWhere((s) => driveStore.containsKey(s), orElse: () => '');
          final file = driveStore[fileId];

          if (file == null) {
            return http.Response('File not found', 404);
          }

          final ifMatchHeader = request.headers['If-Match'] ?? request.headers['if-match'];
          if (ifMatchHeader != null && ifMatchHeader != file.revision) {
            return http.Response(
              jsonEncode({
                'error': {
                  'code': 412,
                  'message': 'Precondition Failed',
                  'errors': [
                    {'domain': 'global', 'reason': 'conditionNotMet', 'message': 'Precondition Failed'}
                  ]
                }
              }),
              412,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }

          final bodyBytes = request.bodyBytes;
          final bodyString = utf8.decode(bodyBytes, allowMalformed: true);
          final updatedContent = _extractMediaBytes(bodyBytes, bodyString);
          if (updatedContent != null) {
            file.content = updatedContent;
          }
          file.revision = nextRevision();
          file.modifiedTime = DateTime.now();

          return http.Response(
            jsonEncode({
              'id': file.id,
              'name': file.name,
              'headRevisionId': file.revision,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        // 4. DELETE requests
        if (request.method == 'DELETE') {
          final segments = uri.pathSegments;
          final fileId = segments.last;
          if (driveStore.containsKey(fileId)) {
            driveStore.remove(fileId);
            return http.Response('', 204);
          }
          return http.Response('Not found', 404);
        }

        return http.Response('Bad request', 400);
      });
    }

    test('GoogleDriveStorageProvider works end-to-end with mock HTTP calls', () async {
      final mockClient = createMockDriveHttpClient();

      final provider = GoogleDriveStorageProvider(
        getAuthHeaders: () async => {'Authorization': 'Bearer test-token'},
        checkConnected: () async => true,
        requestConnect: () async => true,
        requestDisconnect: () async {},
        httpClient: mockClient,
      );

      // Verify connection logic
      expect(await provider.isConnected(), isTrue);
      expect(provider.providerId, equals('google_drive'));

      // 1. Manifest read returns null when manifest does not exist
      final manifest1 = await provider.readManifest();
      expect(manifest1, isNull);

      // 2. Write manifest
      final manifestData = {
        'schemaVersion': 1,
        'latestGlobalSequence': 100,
      };
      await provider.writeManifest(manifestData);

      // 3. Read manifest back
      final manifest2 = await provider.readManifest();
      expect(manifest2, isNotNull);
      expect(manifest2!.content['latestGlobalSequence'], equals(100));
      final revision1 = manifest2.revision;
      expect(revision1, isNotEmpty);

      // 4. Update manifest with correct ETag succeeds
      final manifestData2 = {
        'schemaVersion': 1,
        'latestGlobalSequence': 200,
      };
      await provider.writeManifest(manifestData2, expectedRevision: revision1);

      final manifest3 = await provider.readManifest();
      expect(manifest3!.content['latestGlobalSequence'], equals(200));
      expect(manifest3.revision, isNot(equals(revision1)));

      // 5. Update manifest with stale ETag fails with StateError
      expect(
        () => provider.writeManifest(manifestData, expectedRevision: revision1),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Revision mismatch'))),
      );

      // 6. Write and read binary file
      const filePath = 'snapshots/snapshot_1.sqlite';
      final fileData = Uint8List.fromList([42, 43, 44]);
      await provider.writeFile(filePath, fileData);

      final readData = await provider.readFile(filePath);
      expect(readData, equals(fileData));

      // 7. List files
      final files = await provider.listFiles('snapshots/');
      expect(files.length, equals(1));
      expect(files.first.path, equals(filePath));
      expect(files.first.sizeBytes, equals(3));

      // 8. Delete file
      await provider.deleteFile(filePath);
      final readAfterDelete = await provider.readFile(filePath);
      expect(readAfterDelete, isNull);
    });
  });

  group('GoogleDriveStorageProvider auth flow', () {
    test('scope denied keeps disconnected', () async {
      final fakeGoogleSignIn = _FakeGoogleSignIn();
      fakeGoogleSignIn.requestScopesAllowed = false;

      bool grantedFlag = false;
      final provider = GoogleDriveStorageProvider(
        googleSignIn: fakeGoogleSignIn,
        getAuthHeaders: () async => await fakeGoogleSignIn.currentUser!.authHeaders,
        checkConnected: () async => false,
        requestConnect: () async => false,
        requestDisconnect: () async {},
        hasGrantedDriveScope: () async => grantedFlag,
        setGrantedDriveScope: (bool granted) async {
          grantedFlag = granted;
        },
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({'files': <Map<String, dynamic>>[]}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final connected = await provider.connect();
      expect(connected, isFalse);
      expect(provider.lastConnectionErrorMessage, isNotNull);
      expect(grantedFlag, isFalse);
      expect(await provider.isConnected(), isFalse);
    });

    test('granted scope marks connected', () async {
      final fakeGoogleSignIn = _FakeGoogleSignIn();
      fakeGoogleSignIn.requestScopesAllowed = true;

      bool grantedFlag = false;
      final provider = GoogleDriveStorageProvider(
        googleSignIn: fakeGoogleSignIn,
        getAuthHeaders: () async => await fakeGoogleSignIn.currentUser!.authHeaders,
        checkConnected: () async => false,
        requestConnect: () async => false,
        requestDisconnect: () async {},
        hasGrantedDriveScope: () async => grantedFlag,
        setGrantedDriveScope: (bool granted) async {
          grantedFlag = granted;
        },
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({'files': <Map<String, dynamic>>[]}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final connected = await provider.connect();
      expect(connected, isTrue);
      expect(provider.lastConnectionErrorMessage, isNull);
      expect(grantedFlag, isTrue);
      expect(await provider.isConnected(), isTrue);
    });

    test('isConnected false if scope missing', () async {
      final fakeGoogleSignIn = _FakeGoogleSignIn();

      final provider = GoogleDriveStorageProvider(
        googleSignIn: fakeGoogleSignIn,
        getAuthHeaders: () async => await fakeGoogleSignIn.currentUser!.authHeaders,
        checkConnected: () async => false,
        requestConnect: () async => false,
        requestDisconnect: () async {},
        hasGrantedDriveScope: () async => false,
        setGrantedDriveScope: (_) async {},
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({'files': <Map<String, dynamic>>[]}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      expect(await provider.isConnected(), isFalse);
    });

    test('isConnected true if Drive test succeeds', () async {
      final fakeGoogleSignIn = _FakeGoogleSignIn();
      fakeGoogleSignIn.driveScopeGranted = true;

      final provider = GoogleDriveStorageProvider(
        googleSignIn: fakeGoogleSignIn,
        getAuthHeaders: () async => await fakeGoogleSignIn.currentUser!.authHeaders,
        checkConnected: () async => false,
        requestConnect: () async => false,
        requestDisconnect: () async {},
        hasGrantedDriveScope: () async => true,
        setGrantedDriveScope: (_) async {},
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({'files': <Map<String, dynamic>>[]}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      expect(await provider.isConnected(), isTrue);
    });
  });
}
