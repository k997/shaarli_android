import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ConfigService {
  final _storage = const FlutterSecureStorage();

  Future<String?> getJwtToken() async {
    final apiToken = await _storage.read(key: 'shaarli_token');
    if (apiToken == null) {
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

  Future<String?> getApiUrl() async {
    return await _storage.read(key: 'shaarli_url');
  }

  Future<bool> isPrivateByDefault() async {
    final isPrivate = await _storage.read(key: 'is_private');
    return isPrivate == 'true';
  }

  Future<void> saveSettings(String url, String token, bool isPrivate, String tags) async {
    await _storage.write(key: 'shaarli_url', value: url);
    await _storage.write(key: 'shaarli_token', value: token);
    await _storage.write(key: 'is_private', value: isPrivate.toString());
    await _storage.write(key: 'tags', value: tags);
  }

  Future<String?> getTags() async {
    return await _storage.read(key: 'tags');
  }
}
