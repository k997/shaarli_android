import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'dart:convert';
import 'package:share_handler/share_handler.dart';
import 'package:html/parser.dart' as html_parser;

class ShareHandler {
  final _storage = const FlutterSecureStorage();

  Future<bool> handleShare(SharedMedia media) async {
    final text = media.content ?? '';
    final url = _extractUrl(text);
    if (url == null) {
      return false;
    }

    String title = _extractTitle(text, url);
    String description = '';

    if (title.isEmpty) {
      final fetchedData = await _fetchTitleAndDescription(url);
      title = fetchedData['title'] ?? '';
      description = fetchedData['description'] ?? '';
    }

    final shaarliUrl = await _storage.read(key: 'shaarli_url');
    final token = await _storage.read(key: 'shaarli_token');
    final isPrivateStr = await _storage.read(key: 'is_private');
    final isPrivate = isPrivateStr == 'true';

    if (shaarliUrl == null || token == null) {
      return false;
    }

    final jwt = _generateJwtToken(token);
    final response = await _postLink(shaarliUrl, jwt, url, title, description, isPrivate);

    return response.statusCode == 201;
  }

  String? _extractUrl(String text) {
    final urlRegex = RegExp(r'https?://[\w-]+(\.[\w-]+)+([\w.,@?^=%&:/~+#-]*[\w@?^=%&/~+#-])?');
    final match = urlRegex.firstMatch(text);
    return match?.group(0);
  }

  String _extractTitle(String text, String url) {
    final title = text.replaceAll(url, '').trim();
    return title.isNotEmpty ? title : '';
  }

  Future<Map<String, String>> _fetchTitleAndDescription(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final title = document.querySelector('title')?.text ?? '';
        final description = document.querySelector('meta[name="description"]')?.attributes['content'] ?? '';
        return {'title': title, 'description': description};
      }
    } catch (e) {
      // Handle exceptions
    }
    return {'title': '', 'description': ''};
  }

  String _generateJwtToken(String apiSecret) {
    final jwt = JWT(
      {
        'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      },
      header: {
        'typ': 'JWT',
        'alg': 'HS512',
      },
    );
    final token = jwt.sign(SecretKey(apiSecret), algorithm: JWTAlgorithm.HS512);
    return token;
  }

  Future<http.Response> _postLink(String shaarliUrl, String jwt, String link, String title, String description, bool isPrivate) async {
    final response = await http.post(
      Uri.parse('$shaarliUrl/api/v1/links'),
      headers: {
        'Authorization': 'Bearer $jwt',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'url': link,
        'title': title,
        'description': description,
        'tags': ['from_android'],
        'private': isPrivate,
      }),
    );
    return response;
  }
}