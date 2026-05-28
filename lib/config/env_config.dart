/// 环境配置
/// 通过 dart define 常量区分开发和正式环境
class EnvConfig {
  /// 授权服务器地址
  static const String authServer = String.fromEnvironment(
    'AUTHSERVER',
    defaultValue: 'https://auth-test.mksword.com',
  );

  /// 应用ID
  static const String applicationId = String.fromEnvironment(
    'APPLICATION_ID',
    defaultValue: 'password_book_app',
  );

  /// API服务器地址
  static const String apiUri = String.fromEnvironment(
    'API_URI',
    defaultValue: 'https://api-test.mksword.com',
  );
}