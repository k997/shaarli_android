import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:shaarli_android/core/config_service.dart';
import 'package:shaarli_android/models/shaarli_link.dart';

/// Exception carrying a user-presentable message.
class ShaarliException implements Exception {
  final String message;

  const ShaarliException(this.message);

  @override
  String toString() => message;
}

class ShaarliApi {
  static const _timeout = Duration(seconds: 15);

  final ConfigService _configService;
  final _log = Logger('ShaarliApi');

  ShaarliApi(this._configService);

  Future<List<ShaarliLink>> getLinks({
    int limit = 10,
    int offset = 0,
    String? search,
    String? searchTags,
    String? visibility,
  }) async {
    final uri = await _buildUri('api/v1/links', {
      'limit': '$limit',
      'offset': '$offset',
      if (search != null && search.isNotEmpty) 'searchterm': search,
      if (searchTags != null && searchTags.isNotEmpty) 'searchtags': searchTags,
      if (visibility != null && visibility.isNotEmpty) 'visibility': visibility,
    });

    final response = await _send(() async => http.get(uri, headers: await _authHeaders()));
    if (response.statusCode != 200) {
      throw _httpException(response, 'Failed to load links');
    }

    try {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data.map((json) => ShaarliLink.fromJson(json)).toList();
    } on FormatException catch (e, stackTrace) {
      _log.severe('Invalid JSON from server', e, stackTrace);
      throw const ShaarliException('The server returned an invalid response.');
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
    final uri = await _buildUri('api/v1/links/$id');
    return _send(
      () async => http.put(
        uri,
        headers: await _jsonHeaders(),
        body: jsonEncode(_linkBody(url, title, description, tags, isPrivate)),
      ),
    );
  }

  Future<http.Response> postLink(
    String url,
    String title,
    String description,
    List<String> tags,
    bool isPrivate,
  ) async {
    final uri = await _buildUri('api/v1/links');
    return _send(
      () async => http.post(
        uri,
        headers: await _jsonHeaders(),
        body: jsonEncode(_linkBody(url, title, description, tags, isPrivate)),
      ),
    );
  }

  Future<http.Response> deleteLink(int id) async {
    final uri = await _buildUri('api/v1/links/$id');
    return _send(() async => http.delete(uri, headers: await _authHeaders()));
  }

  Map<String, dynamic> _linkBody(
    String url,
    String title,
    String description,
    List<String> tags,
    bool isPrivate,
  ) {
    return {
      'url': url,
      'title': title,
      'description': description,
      'tags': tags,
      'private': isPrivate,
    };
  }

  /// Builds a request URI against the configured server, encoding all
  /// query parameters properly.
  Future<Uri> _buildUri(String path, [Map<String, String>? queryParameters]) async {
    final base = await _configService.getApiUrl();
    if (base == null) {
      throw _notConfigured();
    }
    var uri = Uri.parse('$base/$path');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParameters);
    }
    return uri;
  }

  Future<String> _requireJwt() async {
    final jwt = await _configService.getJwtToken();
    if (jwt == null) {
      throw _notConfigured();
    }
    return jwt;
  }

  Future<Map<String, String>> _authHeaders() async {
    return {'Authorization': 'Bearer ${await _requireJwt()}'};
  }

  Future<Map<String, String>> _jsonHeaders() async {
    return {
      'Authorization': 'Bearer ${await _requireJwt()}',
      'Content-Type': 'application/json',
    };
  }

  ShaarliException _notConfigured() {
    return const ShaarliException(
      'Shaarli is not configured. Set the server URL and API secret in Settings.',
    );
  }

  /// Runs an HTTP request with a timeout, converting network failures into
  /// [ShaarliException]s with user-presentable messages.
  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on SocketException catch (e, stackTrace) {
      _log.warning('Network error: $e', e, stackTrace);
      throw ShaarliException(_networkErrorMessage(e.toString()));
    } on HandshakeException catch (e, stackTrace) {
      _log.warning('TLS error: $e', e, stackTrace);
      throw const ShaarliException(
        'Secure connection failed. Check the server URL and its TLS certificate.',
      );
    } on TimeoutException {
      throw const ShaarliException(
        'The request timed out. Check your connection and server URL.',
      );
    } on http.ClientException catch (e, stackTrace) {
      _log.warning('HTTP client error: $e', e, stackTrace);
      throw const ShaarliException('Could not reach the server.');
    }
  }

  String _networkErrorMessage(String error) {
    if (error.contains('CLEARTEXT')) {
      return 'Cleartext HTTP is blocked by Android. Use an HTTPS server URL.';
    }
    return 'Could not reach the server. Check your connection and server URL.';
  }

  ShaarliException _httpException(http.Response response, String action) {
    _log.severe('$action failed: ${response.statusCode} ${response.body}');
    switch (response.statusCode) {
      case 401:
      case 403:
        return ShaarliException(
          'Authentication failed (HTTP ${response.statusCode}). Check your API secret.',
        );
      case 404:
        return const ShaarliException(
          'Shaarli API not found (HTTP 404). Check the server URL.',
        );
      default:
        return ShaarliException('$action failed (HTTP ${response.statusCode}).');
    }
  }
}
