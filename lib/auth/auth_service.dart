import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 认证状态管理
class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _accessTokenKey = 'access_token';

  /// 检查是否已登录
  static Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: _accessTokenKey);
    return token != null && token.isNotEmpty;
  }

  /// 保存access_token
  static Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  /// 获取access_token
  static Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  /// 清除access_token
  static Future<void> clearAccessToken() async {
    await _storage.delete(key: _accessTokenKey);
  }
}