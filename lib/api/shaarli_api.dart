import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shaarli_android/core/config_service.dart';
import 'package:shaarli_android/models/shaarli_link.dart';

class ShaarliApi {
  final ConfigService _configService;

  ShaarliApi(this._configService);

  Future<List<ShaarliLink>> getLinks({int limit = 10, int offset = 0}) async {
    final shaarliUrl = await _configService.getApiUrl();
    final jwt = await _configService.getJwtToken();

    if (shaarliUrl == null || jwt == null) {
      throw Exception('API URL or token not configured.');
    }

    final response = await http.get(
      Uri.parse('$shaarliUrl/api/v1/links?limit=$limit&offset=$offset'),
      headers: {'Authorization': 'Bearer $jwt'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data.map((json) => ShaarliLink.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load links');
    }
  }

  Future<http.Response> updateLink(
    int id,
    String url,
    String title,
    String description,
    List<String> tags,
    bool isPrivate,
  ) async {
    final shaarliUrl = await _configService.getApiUrl();
    final jwt = await _configService.getJwtToken();
    if (shaarliUrl == null || jwt == null) {
      throw Exception('API URL or token not configured.');
    }
    final Map<String, dynamic> body = {
      'url': url,
      'title': title,
      'description': description,
      'tags': tags,
      'private': isPrivate,
    };

    final response = await http.put(
      Uri.parse('$shaarliUrl/api/v1/links/$id'),
      headers: {
        'Authorization': 'Bearer $jwt',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    return response;
  }

  Future<http.Response> postLink(
    String url,
    String title,
    String description,
    List<String> tags,
    bool isPrivate,
  ) async {
    final shaarliUrl = await _configService.getApiUrl();
    final jwt = await _configService.getJwtToken();
    if (shaarliUrl == null || jwt == null) {
      throw Exception('API URL or token not configured.');
    }
    final Map<String, dynamic> body = {
      'url': url,
      'title': title,
      'description': description,
      'tags': tags,
      'private': isPrivate,
    };

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

  Future<http.Response> deleteLink(int id) async {
    final shaarliUrl = await _configService.getApiUrl();
    final jwt = await _configService.getJwtToken();
    if (shaarliUrl == null || jwt == null) {
      throw Exception('API URL or token not configured.');
    }

    final response = await http.delete(
      Uri.parse('$shaarliUrl/api/v1/links/$id'),
      headers: {
        'Authorization': 'Bearer $jwt',
      },
    );
    return response;
  }
}
