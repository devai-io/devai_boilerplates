import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8080');

class ApiException implements Exception {
  ApiException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}

class PostSummary {
  PostSummary.fromJson(Map<String, dynamic> j)
      : id = '${j['id']}',
        title = j['title'] as String,
        slug = j['slug'] as String,
        excerpt = j['excerpt'] as String,
        publishedAt = j['published_at'] as String;
  final String id, title, slug, excerpt, publishedAt;
}

class Post {
  Post.fromJson(Map<String, dynamic> j)
      : id = '${j['id']}',
        title = j['title'] as String,
        slug = j['slug'] as String,
        body = j['body'] as String,
        published = j['published'] as bool,
        createdAt = j['created_at'] as String;
  final String id, title, slug, body, createdAt;
  final bool published;
}

/// API client + auth state. A [ChangeNotifier] so the UI can react to
/// login/logout; the JWT is held in memory (see README on persistence).
class ApiClient extends ChangeNotifier {
  String? _token;

  bool get authed => _token != null;

  Future<dynamic> _request(String method, String path, {Map<String, Object?>? body}) async {
    final headers = <String, String>{
      if (body != null) 'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
    final uri = Uri.parse('$apiUrl$path');
    final encoded = body == null ? null : jsonEncode(body);

    final http.Response res = switch (method) {
      'GET' => await http.get(uri, headers: headers),
      'POST' => await http.post(uri, headers: headers, body: encoded),
      'PUT' => await http.put(uri, headers: headers, body: encoded),
      'DELETE' => await http.delete(uri, headers: headers),
      _ => throw ArgumentError.value(method),
    };

    if (res.statusCode >= 400) {
      var message = 'HTTP ${res.statusCode}';
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['error'] is String) message = decoded['error'] as String;
      } catch (_) {
        // non-JSON error body; keep the status message
      }
      throw ApiException(res.statusCode, message);
    }
    return res.body.isEmpty ? null : jsonDecode(res.body);
  }

  Map<String, dynamic> _asMap(dynamic value) => (value as Map).cast<String, dynamic>();

  Future<void> login(String email, String password) async {
    final data =
        _asMap(await _request('POST', '/auth/login', body: {'email': email, 'password': password}));
    _token = data['token'] as String;
    notifyListeners();
  }

  void logout() {
    _token = null;
    notifyListeners();
  }

  Future<List<PostSummary>> listPosts() async {
    final data = await _request('GET', '/posts') as List<dynamic>;
    return [for (final item in data) PostSummary.fromJson(_asMap(item))];
  }

  Future<Post> getPost(String slug) async =>
      Post.fromJson(_asMap(await _request('GET', '/posts/${Uri.encodeComponent(slug)}')));

  Future<Post> createPost(String title, String body) async =>
      Post.fromJson(_asMap(await _request('POST', '/posts', body: {'title': title, 'body': body})));

  Future<Post> updatePost(String id, Map<String, Object?> fields) async =>
      Post.fromJson(_asMap(await _request('PUT', '/posts/${Uri.encodeComponent(id)}', body: fields)));

  Future<void> deletePost(String id) async =>
      await _request('DELETE', '/posts/${Uri.encodeComponent(id)}');
}
