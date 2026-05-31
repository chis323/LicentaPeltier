import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/constants.dart';
import '../../models/daily_stat.dart';
import '../../models/profile.dart';
import '../../models/profile_summary.dart';
import '../auth/auth_storage.dart';

class ApiService {
  final AuthStorage _authStorage;

  ApiService({AuthStorage? authStorage})
      : _authStorage = authStorage ?? AuthStorage();

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse("$baseUrl$path").replace(queryParameters: query);
  }

  Future<Map<String, String>> _headers({bool json = false}) async {
    final token = await _authStorage.getToken();
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> login(String username, String password) async {
    final res = await http.post(
      _uri('/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Login failed: ${res.statusCode} ${res.body}');
    }

    final obj = jsonDecode(res.body) as Map<String, dynamic>;
    final token = obj['token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Login failed: no token returned');
    }

    await _authStorage.saveToken(token);
  }

  Future<void> logout() => _authStorage.clearToken();

  Future<Map<String, dynamic>> _getJson(
    String path, [
    Map<String, String>? query,
  ]) async {
    final res = await http.get(_uri(path, query), headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception("GET $path failed: ${res.statusCode} ${res.body}");
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _sendJson(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    late http.Response res;

    switch (method) {
      case 'POST':
        res = await http.post(
          _uri(path),
          headers: await _headers(json: true),
          body: jsonEncode(body ?? {}),
        );
        break;
      case 'PUT':
        res = await http.put(
          _uri(path),
          headers: await _headers(json: true),
          body: jsonEncode(body ?? {}),
        );
        break;
      case 'DELETE':
        res = await http.delete(_uri(path), headers: await _headers());
        break;
      default:
        throw Exception("Unsupported method: $method");
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("$method $path failed: ${res.statusCode} ${res.body}");
    }

    if (res.body.trim().isEmpty) return {};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStatus() => _getJson("/api/status");

  Future<void> sendCommand(Map<String, dynamic> payload) async {
    await _sendJson("POST", "/api/command", body: payload);
  }

  Future<List<DailyStat>> getDailyHistory({int days = 7}) async {
    final obj = await _getJson("/api/history/daily", {"days": "$days"});
    final list = (obj["days"] as List<dynamic>? ?? []);
    return list
        .map((e) => DailyStat.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ProfileSummary>> listProfiles() async {
    final obj = await _getJson("/api/profiles");
    final list = (obj["profiles"] as List<dynamic>? ?? []);
    return list
        .map((e) => ProfileSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Profile> getProfile(String id) async {
    final obj = await _getJson("/api/profiles/$id");
    return Profile.fromJson(obj);
  }

  Future<Profile> createProfile(String name) async {
    final obj = await _sendJson("POST", "/api/profiles", body: {"name": name});
    return Profile.fromJson(obj);
  }

  Future<Profile> saveProfile(Profile p) async {
    final obj =
        await _sendJson("PUT", "/api/profiles/${p.id}", body: p.toJson());
    return Profile.fromJson(obj);
  }

  Future<void> setProfileEnabled(String id, bool enabled) async {
    await _sendJson(
      "POST",
      "/api/profiles/$id/enable",
      body: {"enabled": enabled},
    );
  }

  Future<void> deleteProfile(String id) async {
    await _sendJson("DELETE", "/api/profiles/$id");
  }
}
