import 'dart:convert';

import 'package:http/http.dart' as http;

class DriveBackupFile {
  const DriveBackupFile({
    required this.id,
    required this.name,
    this.createdTime,
    this.modifiedTime,
    this.rawJson,
    this.backupVersion,
    this.userId,
    this.provider,
    this.email,
    this.backupCreatedAt,
    this.backupUpdatedAt,
    this.devicePlatform,
    this.appVersion,
  });

  final String id;
  final String name;
  final DateTime? createdTime;
  final DateTime? modifiedTime;
  final String? rawJson;
  final int? backupVersion;
  final String? userId;
  final String? provider;
  final String? email;
  final DateTime? backupCreatedAt;
  final DateTime? backupUpdatedAt;
  final String? devicePlatform;
  final String? appVersion;

  DateTime? get effectiveUpdatedAt =>
      backupUpdatedAt ?? modifiedTime ?? createdTime;

  DriveBackupFile copyWith({
    String? rawJson,
    DateTime? backupCreatedAt,
    DateTime? backupUpdatedAt,
    String? devicePlatform,
    String? appVersion,
    int? backupVersion,
    String? userId,
    String? provider,
    String? email,
  }) {
    return DriveBackupFile(
      id: id,
      name: name,
      createdTime: createdTime,
      modifiedTime: modifiedTime,
      rawJson: rawJson ?? this.rawJson,
      backupVersion: backupVersion ?? this.backupVersion,
      userId: userId ?? this.userId,
      provider: provider ?? this.provider,
      email: email ?? this.email,
      backupCreatedAt: backupCreatedAt ?? this.backupCreatedAt,
      backupUpdatedAt: backupUpdatedAt ?? this.backupUpdatedAt,
      devicePlatform: devicePlatform ?? this.devicePlatform,
      appVersion: appVersion ?? this.appVersion,
    );
  }
}

class GoogleDriveService {
  GoogleDriveService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  static const String backupFileName = 'zakatapp_backup.json';
  static const String _baseUrl = 'https://www.googleapis.com/drive/v3/files';
  static const String _uploadUrl =
      'https://www.googleapis.com/upload/drive/v3/files';

  final http.Client _httpClient;

  Future<List<DriveBackupFile>> listBackupFiles(String accessToken) async {
    final Uri uri = Uri.parse(_baseUrl).replace(
      queryParameters: <String, String>{
        'spaces': 'appDataFolder',
        'q': "name='$backupFileName'",
        'fields': 'files(id,name,createdTime,modifiedTime)',
        'pageSize': '100',
      },
    );
    final http.Response response = await _httpClient.get(
      uri,
      headers: _authHeaders(accessToken),
    );
    if (response.statusCode != 200) {
      return const <DriveBackupFile>[];
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> files = data['files'] as List<dynamic>? ?? <dynamic>[];
    return files
        .whereType<Map>()
        .map((Map raw) => _driveFileFromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  Future<String?> downloadBackupContent({
    required String accessToken,
    required String fileId,
  }) async {
    final Uri downloadUri = Uri.parse("$_baseUrl/$fileId?alt=media");
    final http.Response response = await _httpClient.get(
      downloadUri,
      headers: _authHeaders(accessToken),
    );
    if (response.statusCode == 200) {
      return response.body;
    }
    return null;
  }

  Future<DriveBackupFile?> fetchLatestBackup(String accessToken) async {
    final List<DriveBackupFile> files = await listBackupFiles(accessToken);
    if (files.isEmpty) return null;

    final List<DriveBackupFile> enriched = <DriveBackupFile>[];
    for (final DriveBackupFile file in files) {
      final String? rawJson = await downloadBackupContent(
        accessToken: accessToken,
        fileId: file.id,
      );
      if (rawJson == null) continue;
      enriched.add(_applyBackupMetadata(file, rawJson));
    }
    if (enriched.isEmpty) return null;

    enriched.sort((DriveBackupFile a, DriveBackupFile b) {
      final DateTime aTime =
          a.effectiveUpdatedAt ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final DateTime bTime =
          b.effectiveUpdatedAt ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      return bTime.compareTo(aTime);
    });
    return enriched.first;
  }

  Future<DriveBackupFile?> uploadBackup({
    required String jsonString,
    required String accessToken,
  }) async {
    final DriveBackupFile? existingFile = await fetchLatestBackup(accessToken);
    if (existingFile != null) {
      final Uri updateUri = Uri.parse(
        "$_uploadUrl/${existingFile.id}?uploadType=media",
      );
      final http.Response updateResponse = await _httpClient.patch(
        updateUri,
        headers: <String, String>{
          ..._authHeaders(accessToken),
          'Content-Type': 'application/json',
        },
        body: jsonString,
      );
      if (updateResponse.statusCode == 200) {
        return _applyBackupMetadata(existingFile, jsonString);
      }
      return null;
    }

    final Uri createUri = Uri.parse("$_uploadUrl?uploadType=multipart");
    final Map<String, dynamic> metadata = <String, dynamic>{
      'name': backupFileName,
      'parents': <String>['appDataFolder'],
    };
    const String boundary = 'zakatapp_backup_boundary';
    final String body = <String>[
      '--$boundary',
      'Content-Type: application/json; charset=UTF-8',
      '',
      jsonEncode(metadata),
      '--$boundary',
      'Content-Type: application/json',
      '',
      jsonString,
      '--$boundary--',
      '',
    ].join('\r\n');

    final http.Response createResponse = await _httpClient.post(
      createUri,
      headers: <String, String>{
        ..._authHeaders(accessToken),
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: body,
    );
    if (createResponse.statusCode != 200 && createResponse.statusCode != 201) {
      return null;
    }

    final Map<String, dynamic> createdJson =
        jsonDecode(createResponse.body) as Map<String, dynamic>;
    return _applyBackupMetadata(_driveFileFromJson(createdJson), jsonString);
  }

  Map<String, String> _authHeaders(String accessToken) {
    return <String, String>{'Authorization': 'Bearer $accessToken'};
  }

  DriveBackupFile _driveFileFromJson(Map<String, dynamic> json) {
    return DriveBackupFile(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? backupFileName).toString(),
      createdTime: _parseDateTime(json['createdTime']),
      modifiedTime: _parseDateTime(json['modifiedTime']),
    );
  }

  DriveBackupFile _applyBackupMetadata(DriveBackupFile file, String rawJson) {
    try {
      final Map<String, dynamic> decoded =
          jsonDecode(rawJson) as Map<String, dynamic>;
      final Map<String, dynamic> metadata =
          decoded['cloudBackupMetadata'] is Map
          ? Map<String, dynamic>.from(decoded['cloudBackupMetadata'] as Map)
          : <String, dynamic>{};
      return file.copyWith(
        rawJson: rawJson,
        backupVersion: _parseInt(
          decoded['backupVersion'] ?? decoded['schemaVersion'],
        ),
        userId: decoded['userId']?.toString(),
        provider: decoded['provider']?.toString(),
        email: decoded['email']?.toString(),
        backupCreatedAt: _parseDateTime(metadata['createdAt']),
        backupUpdatedAt: _parseDateTime(
          metadata['updatedAt'] ?? decoded['exportedAt'],
        ),
        devicePlatform: metadata['devicePlatform']?.toString(),
        appVersion: metadata['appVersion']?.toString(),
      );
    } catch (_) {
      return file.copyWith(rawJson: rawJson);
    }
  }

  DateTime? _parseDateTime(dynamic value) {
    final String raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse((value ?? '').toString());
  }
}
