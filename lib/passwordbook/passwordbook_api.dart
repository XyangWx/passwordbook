import 'package:dio/dio.dart';
import '../config/env_config.dart';
import '../auth/auth_service.dart';
import 'models.dart';

/// 密码本 API 客户端
class PasswordBookApiClient {
  // 🟢 1. 构造一个全局唯一的 Dio 实例，并为其注入动态拦截器
  static final Dio _dio = () {
    final dio = Dio(BaseOptions(
      baseUrl: EnvConfig.apiUri,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      // 允许标准的 200~300 以及 401（便于自定义异常判定）
      validateStatus: (status) => status != null && status < 500,
    ));

    // 🟢 2. 核心：添加 OIDC 身份验证自动注入拦截器
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // 从连通的 AuthService 中提取实时有效的 accessToken
        final accessToken = await AuthService.getAccessToken();

        if (accessToken != null) {
          // 🛠️ 修正 401：除了注入 Bearer 令牌外，根据 ABP 规范追加常规跨域身份验证上下文
          options.headers['Authorization'] = 'Bearer $accessToken';
          options.headers['X-Requested-With'] = 'XMLHttpRequest';
          options.headers['Accept'] = 'application/json';
        }

        return handler.next(options); // 放行请求
      },
      onResponse: (response, handler) {
        // 🟢 3. 增强安全判定：如果拦截器在中间层抓到了 401 状态码，可以统一做强退或提示
        if (response.statusCode == 401) {
          print('❌ [API 异常] 访问令牌已被服务器判定失效 (401)，可能由于 Session 被远端清理');
          // 可在此处执行回调，例如通知前端跳转回登录页
        }
        return handler.next(response);
      },
    ));

    return dio;
  }();

  /// GET /api/password-book 获取密码本列表
  static Future<List<PasswordBook>> getPasswordBooks() async {
    try {
      // 🟢 现在的请求不再需要手动去写 headers 注入，拦截器在底层会自动静默打满凭证
      final response = await _dio.get('/api/password-book');

      // 显式校验状态码
      if (response.statusCode == 401) {
        throw Exception('用户未登录或访问令牌已过期，请重新登录 (401)');
      }

      if (response.statusCode != 200) {
        throw Exception('服务器请求失败，状态码: ${response.statusCode}');
      }

      final result = PasswordBookListResponse.fromJson(response.data);
      return result.items;
    } on DioException catch (e) {
      throw Exception('网络请求发生异常: ${e.message}');
    }
  }

  /// 🟢 POST /api/password-book 创建新密码本
  static Future<void> createPasswordBook(NewPasswordBookRequest request) async {
    try {
      // 拦截器在底层会自动静默注入 Token 和 ABP 跨域头上下文
      final response = await _dio.post(
        '/api/password-book',
        data: request.toJson(),
      );

      // ABP 框架标准规范：创建成功通常返回 200 或 201 状态码
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('创建密码本失败，服务器状态码: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('网络请求发生异常: ${e.message}');
    }
  }
}
