import 'dart:convert';
import 'dart:io';

Map<String, dynamic> loadJsonFixture(String path) {
  final String content = File(path).readAsStringSync();
  return jsonDecode(content) as Map<String, dynamic>;
}
