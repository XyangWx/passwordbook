import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';
import '../config/env_config.dart';

/// 认证状态与配置核心管理中心（全局单一事实来源）
class AuthService {
  static OidcUserManager? _userManager;

  /// 🟢 核心抽象：全局唯一的配置与初始化出口，只在这里定义一次！
  static Future<OidcUserManager> getManager() async {
    if (_userManager != null) return _userManager!;

    final store = OidcDefaultStore();
    final clientAuth = OidcClientAuthentication.none(clientId: EnvConfig.applicationId);

    final platformOptions = OidcPlatformSpecificOptions(
      android: const OidcPlatformSpecificOptions_AppAuth_Android(),
      ios: const OidcPlatformSpecificOptions_AppAuth_IosMacos(),
      macos: const OidcPlatformSpecificOptions_AppAuth_IosMacos(),
    );

    // 🌟 全应用所有的 OIDC 核心配置，未来只需要修改这一个地方：
    final settings = OidcUserManagerSettings(
      redirectUri: Uri.parse('com.mksword.passwordbook://callback'),
      postLogoutRedirectUri: Uri.parse('com.mksword.passwordbook://logout-callback'),
      options: platformOptions,
      scope: const ['openid', 'profile', 'email', 'offline_access', 'XYPortal'], // 完美对齐复数 scopes；offline_access 用于获取 refresh_token 实现静默刷新
    );

    _userManager = OidcUserManager.lazy(
      discoveryDocumentUri: Uri.parse('${EnvConfig.authServer}/.well-known/openid-configuration'),
      clientCredentials: clientAuth,
      store: store,
      settings: settings,
    );

    await _userManager!.init();
    return _userManager!;
  }

  /// 检查是否已登录
  static Future<bool> isLoggedIn() async {
    try {
      final manager = await getManager();
      final hasUser = manager.currentUser != null;
      final isExpired = hasUser && manager.currentUser!.token.isAccessTokenExpired();
      return hasUser && !isExpired;
    } catch (_) {
      return false;
    }
  }

  /// 获取当前的 access_token
  static Future<String?> getAccessToken() async {
    try {
      final manager = await getManager();
      return manager.currentUser?.token.accessToken;
    } catch (_) {
      return null;
    }
  }

  /// 兼容性占位
  static Future<void> saveAccessToken(String token) async {}
  static Future<void> clearAccessToken() async {}
}
