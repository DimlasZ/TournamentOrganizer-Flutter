import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

class GitHubService {
  static const _owner = 'DimlasZ';
  static const _repo = 'TournamentOrganizer-Flutter';

  static String? getStoredToken() => StorageService.loadGhToken();
  static Future<void> setStoredToken(String token) => StorageService.saveGhToken(token);
  static Future<void> clearStoredToken() => StorageService.clearGhToken();

  static Future<({bool ok, String message})> pushResults(
    String filename,
    String csvContent,
    String token,
  ) async {
    final path = 'results/$filename';
    final url = Uri.parse(
      'https://api.github.com/repos/$_owner/$_repo/contents/$path',
    );
    final headers = {
      'Authorization': 'token $token',
      'Content-Type': 'application/json',
    };

    // Try to get existing file SHA for update
    String? sha;
    try {
      final getRes = await http.get(url, headers: headers);
      if (getRes.statusCode == 200) {
        final data = jsonDecode(getRes.body) as Map<String, dynamic>;
        sha = data['sha'] as String?;
      } else if (getRes.statusCode == 401) {
        await clearStoredToken();
        return (ok: false, message: 'Invalid token — cleared. Please re-enter.');
      }
    } catch (_) {}

    final body = <String, dynamic>{
      'message': 'Upload results: $filename',
      'content': base64Encode(utf8.encode(csvContent)),
      'sha': ?sha,
    };

    try {
      final putRes = await http.put(url, headers: headers, body: jsonEncode(body));
      if (putRes.statusCode == 200 || putRes.statusCode == 201) {
        return (ok: true, message: 'Uploaded successfully!');
      } else if (putRes.statusCode == 401) {
        await clearStoredToken();
        return (ok: false, message: 'Invalid token — cleared. Please re-enter.');
      } else {
        String detail = '';
        try {
          final body = jsonDecode(putRes.body) as Map<String, dynamic>;
          detail = body['message'] as String? ?? '';
        } catch (_) {}
        return (ok: false, message: 'Upload failed (${putRes.statusCode})${detail.isNotEmpty ? ': $detail' : ''}');
      }
    } catch (e) {
      return (ok: false, message: 'Network error: $e');
    }
  }
}
