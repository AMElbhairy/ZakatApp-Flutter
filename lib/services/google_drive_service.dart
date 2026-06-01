import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleDriveService {
  static const String _backupFileName = 'zakatapp_backup.json';
  static const String _baseUrl = 'https://www.googleapis.com/drive/v3/files';
  static const String _uploadUrl = 'https://www.googleapis.com/upload/drive/v3/files';

  Future<String?> _findBackupFileId(String accessToken) async {
    final Uri uri = Uri.parse("$_baseUrl?spaces=appDataFolder&q=name='$_backupFileName'");
    final http.Response response = await http.get(
      uri,
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> files = data['files'] ?? <dynamic>[];
      if (files.isNotEmpty) {
        return files.first['id']?.toString();
      }
    }
    return null;
  }

  Future<bool> backupToDrive(String jsonString, String accessToken) async {
    try {
      final String? existingFileId = await _findBackupFileId(accessToken);

      if (existingFileId != null) {
        // Update existing file
        final Uri updateUri = Uri.parse("$_uploadUrl/$existingFileId?uploadType=media");
        final http.Response updateResponse = await http.patch(
          updateUri,
          headers: <String, String>{
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonString,
        );
        return updateResponse.statusCode == 200;
      } else {
        // Create new file
        final Uri createUri = Uri.parse("$_uploadUrl?uploadType=multipart");
        
        final Map<String, dynamic> metadata = <String, dynamic>{
          'name': _backupFileName,
          'parents': <String>['appDataFolder'],
        };
        
        final String boundary = 'foo_bar_baz';
        final StringBuffer body = StringBuffer();
        
        body.writeln('--$boundary');
        body.writeln('Content-Type: application/json; charset=UTF-8');
        body.writeln();
        body.writeln(jsonEncode(metadata));
        
        body.writeln('--$boundary');
        body.writeln('Content-Type: application/json');
        body.writeln();
        body.writeln(jsonString);
        body.writeln('--$boundary--');

        final http.Response createResponse = await http.post(
          createUri,
          headers: <String, String>{
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'multipart/related; boundary=$boundary',
          },
          body: body.toString(),
        );
        return createResponse.statusCode == 200;
      }
    } catch (e) {
      return false;
    }
  }

  Future<String?> restoreFromDrive(String accessToken) async {
    try {
      final String? fileId = await _findBackupFileId(accessToken);
      if (fileId == null) return null;

      final Uri downloadUri = Uri.parse("$_baseUrl/$fileId?alt=media");
      final http.Response response = await http.get(
        downloadUri,
        headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        return response.body;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
