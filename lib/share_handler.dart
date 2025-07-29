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
    
    final shaarliUrl = await _storage.read(key: 'shaarli_url');
    final token = await _storage.read(key: 'shaarli_token');
    final isPrivateStr = await _storage.read(key: 'is_private');
    final isPrivate = isPrivateStr == 'true';

    if (shaarliUrl == null || token == null) {
      return false;
    }
    
    final jwt = generateJwtToken(token);

    if (url == null) {
      // If no URL is found, treat it as a note.
      final response = await postLink(shaarliUrl, jwt, '', text, '', [], isPrivate, isNote: true);
      return response.statusCode == 201;
    }

    String title = _extractTitle(text, url);
    String description = '';

    if (title.isEmpty) {
      final fetchedData = await fetchTitleAndDescription(url);
      title = fetchedData['title'] ?? '';
      description = fetchedData['description'] ?? '';
    }

    final response = await postLink(shaarliUrl, jwt, url, title, description, ['from_android'], isPrivate);

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

  Future<Map<String, String>> fetchTitleAndDescription(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        // Explicitly decode the body as UTF-8 to handle encoding issues.
        final decodedBody = utf8.decode(response.bodyBytes, allowMalformed: true);
        final document = html_parser.parse(decodedBody);
        final title = document.querySelector('title')?.text ?? '';
        final description = document.querySelector('meta[name="description"]')?.attributes['content'] ?? '';
        return {'title': title, 'description': description};
      }
    } catch (e) {
      // Handle exceptions
    }
    return {'title': '', 'description': ''};
  }

  String generateJwtToken(String apiSecret) {
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

  Future<http.Response> postLink(String shaarliUrl, String jwt, String link, String title, String description, List<String> tags, bool isPrivate, {bool isNote = false}) async {
    final Map<String, dynamic> body = {
      'title': title,
      'description': description,
      'tags': tags,
      'private': isPrivate,
    };

    if (!isNote) {
      body['url'] = link;
    } else if (link.isNotEmpty) {
       body['url'] = link;
    }

    final response = await http.post(
      Uri.parse('$shaarliUrl/api/v1/links'),
      headers: {
        'Authorization': 'Bearer $jwt',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    return response;
  }
}
