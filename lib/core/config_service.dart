import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Application settings stored in secure storage.
///
/// A single instance is shared across the app (the underlying secure storage
/// plugin is process-wide anyway).
class ConfigService {
  ConfigService._internal();

  static final ConfigService _instance = ConfigService._internal();

  factory ConfigService() => _instance;

  final _storage = const FlutterSecureStorage();

  /// Returns a freshly signed JWT for API authentication, or null when no
  /// API secret has been configured yet.
  Future<String?> getJwtToken() async {
    final apiToken = await _storage.read(key: 'shaarli_token');
    if (apiToken == null || apiToken.isEmpty) {
      return null;
    }
    return _generateJwtToken(apiToken);
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

  /// Returns the configured server URL without a trailing slash, or null
  /// when it has not been configured yet.
  Future<String?> getApiUrl() async {
    final url = await _storage.read(key: 'shaarli_url');
    if (url == null || url.isEmpty) {
      return null;
    }
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  Future<bool> isPrivateByDefault() async {
    final isPrivate = await _storage.read(key: 'is_private');
    return isPrivate == 'true';
  }

  Future<bool> hasApiSecret() async {
    final token = await _storage.read(key: 'shaarli_token');
    return token != null && token.isNotEmpty;
  }

  /// Saves settings. An empty [token] keeps the previously stored secret so
  /// users don't have to re-enter it to change unrelated settings.
  Future<void> saveSettings(String url, String token, bool isPrivate, String tags) async {
    await _storage.write(key: 'shaarli_url', value: url.trim());
    if (token.trim().isNotEmpty) {
      await _storage.write(key: 'shaarli_token', value: token.trim());
    }
    await _storage.write(key: 'is_private', value: isPrivate.toString());
    await _storage.write(key: 'tags', value: tags);
  }

  Future<String?> getTags() async {
    return await _storage.read(key: 'tags');
  }
}
