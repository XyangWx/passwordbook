import 'package:dio/dio.dart';
import '../config/env_config.dart';
import '../auth/auth_service.dart';
import 'models.dart';

/// 密码本 API 客户端
class PasswordBookApiClient {
  static final _dio = Dio(BaseOptions(
    baseUrl: EnvConfig.apiUri,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// GET /api/password-book 获取密码本列表
  static Future<List<PasswordBook>> getPasswordBooks() async {
    final accessToken = await AuthService.getAccessToken();
    if (accessToken == null) {
      throw Exception('用户未登录或访问令牌无效');
    }

    final response = await _dio.get(
      '/api/password-book',
      options: Options(headers: {
        'Authorization': 'Bearer $accessToken',
      }),
    );

    final result = PasswordBookListResponse.fromJson(response.data);
    return result.items;
  }
}