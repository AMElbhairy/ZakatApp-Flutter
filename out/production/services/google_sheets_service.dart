import 'dart:convert';
import 'package:http/http.dart' as http;

/// Minimal Google Sheets service for basic app-state sync operations.
class GoogleSheetsService {
  GoogleSheetsService({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  /// Create a new spreadsheet and return its id and title.
  /// This calls the Google Sheets API v4 `spreadsheets.create` endpoint.
  Future<Map<String, String>?> createSpreadsheet(String accessToken, {String title = 'ZakatApp Backup'}) async {
    final Uri uri = Uri.parse('https://sheets.googleapis.com/v4/spreadsheets');
    final Map<String, dynamic> body = <String, dynamic>{
      'properties': <String, dynamic>{'title': title},
      'sheets': <Map<String, dynamic>>[
        {'properties': {'title': 'Settings'}},
        {'properties': {'title': 'Transactions'}},
        {'properties': {'title': 'Savings'}},
        {'properties': {'title': 'Investments'}},
        {'properties': {'title': 'RecurringTransactions'}},
        {'properties': {'title': 'FinancialPlans'}},
        {'properties': {'title': 'MarketData'}},
      ],
    };
    final http.Response resp = await _http.post(
      uri,
      headers: <String, String>{
        'authorization': 'Bearer $accessToken',
        'content-type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (resp.statusCode != 200 && resp.statusCode != 201) return null;
    final Map<String, dynamic> json = jsonDecode(resp.body) as Map<String, dynamic>;
    final String? id = json['spreadsheetId']?.toString();
    final String? titleResp = (json['properties']?['title'])?.toString();
    if (id == null) return null;
    return <String, String>{'id': id, 'title': titleResp ?? ''};
  }

  /// Connect by verifying the spreadsheet is accessible.
  Future<bool> connectSpreadsheet(String spreadsheetId, String accessToken) async {
    final Uri uri = Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId?fields=spreadsheetId,properties/title');
    final http.Response resp = await _http.get(uri, headers: <String, String>{'authorization': 'Bearer $accessToken'});
    return resp.statusCode == 200;
  }

  /// Read app state from a spreadsheet. Returns a Map representation of the stored JSON per-tab.
  /// For this phase, expect the app state to be stored as JSON in a single tab `Settings` cell A1, or per-tab JSON.
  Future<Map<String, dynamic>?> readAppState(String spreadsheetId, String accessToken) async {
    // Try to read Settings!A1 first
    final Uri uri = Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/Settings!A1');
    final http.Response resp = await _http.get(uri, headers: <String, String>{'authorization': 'Bearer $accessToken'});
    if (resp.statusCode != 200) return null;
    try {
      final Map<String, dynamic> json = jsonDecode(resp.body) as Map<String, dynamic>;
      final List<dynamic>? values = json['values'] as List<dynamic>?;
      if (values != null && values.isNotEmpty && (values[0] as List).isNotEmpty) {
        final String raw = (values[0] as List)[0]?.toString() ?? '';
        if (raw.trim().isNotEmpty) {
          return jsonDecode(raw) as Map<String, dynamic>?;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Write the full app state JSON into `Settings!A1`.
  Future<bool> writeAppState(String spreadsheetId, Map<String, dynamic> appStateJson, String accessToken) async {
    final Uri uri = Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/Settings!A1?valueInputOption=RAW');
    final String payload = jsonEncode(<String, dynamic>{'values': <List<String>>[<String>[jsonEncode(appStateJson)]]});
    final http.Response resp = await _http.put(
      uri,
      headers: <String, String>{'authorization': 'Bearer $accessToken', 'content-type': 'application/json'},
      body: payload,
    );
    return resp.statusCode == 200;
  }
}
