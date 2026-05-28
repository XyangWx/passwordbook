import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';
import '../config/env_config.dart';

/// 🟢 重构并修正语法后的认证状态管理：直接桥接 OIDC 核心状态
class AuthService {
  /// 封装一个内部公用的管理器初始化方法，确保能拿到最新的真实会话
  static Future<OidcUserManager> _getOidcManager() async {
    final store = OidcDefaultStore();
    final clientAuth = OidcClientAuthentication.none(clientId: EnvConfig.applicationId);

    final platformOptions = OidcPlatformSpecificOptions(
      android: const OidcPlatformSpecificOptions_AppAuth_Android(),
      ios: const OidcPlatformSpecificOptions_AppAuth_IosMacos(),
      macos: const OidcPlatformSpecificOptions_AppAuth_IosMacos(),
    );

    final settings = OidcUserManagerSettings(
      redirectUri: Uri.parse('com.mksword.passwordbook://callback'),
      postLogoutRedirectUri: Uri.parse('com.mksword.passwordbook://logout-callback'),
      options: platformOptions,
      scope: ['openid', 'profile', 'email', 'XYPortal']
    );

    final manager = OidcUserManager.lazy(
      discoveryDocumentUri: Uri.parse('${EnvConfig.authServer}/.well-known/openid-configuration'),
      clientCredentials: clientAuth,
      store: store,
      settings: settings,
    );

    await manager.init();
    return manager;
  }

  /// 🟢 检查是否已登录：直接交由 OIDC 判定
  static Future<bool> isLoggedIn() async {
    try {
      final manager = await _getOidcManager();

      // 🛠️ 核心修正：isAccessTokenExpired 是一个方法，必须加上 () 执行！
      // 并且只有当存在用户、且 Access Token 未过期时才判定为合法的 isLoggedIn
      final hasUser = manager.currentUser != null;
      final isExpired = hasUser && manager.currentUser!.token.isAccessTokenExpired(); // 加上圆括号

      return hasUser && !isExpired;
    } catch (_) {
      return false;
    }
  }

  /// 🟢 获取当前的 access_token (供你项目内其他网络请求 Dio/Http 拦截器调用)
  static Future<String?> getAccessToken() async {
    try {
      final manager = await _getOidcManager();
      return manager.currentUser?.token.accessToken;
    } catch (_) {
      return null;
    }
  }

  /// 💡 保留空实现以兼容你项目其余部分的编译：
  /// 因为 package:oidc 的 loginFlow 会自动持久化，不再需要手动干预 save 和 clear
  static Future<void> saveAccessToken(String token) async {}
  static Future<void> clearAccessToken() async {}
}
