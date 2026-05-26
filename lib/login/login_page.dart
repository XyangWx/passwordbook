import 'package:flutter/material.dart';
import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';
import '../config/env_config.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // 1. 符合官方规范：声明顶级 OidcUserManager 会话管理器
  OidcUserManager? _oidcUserManager;
  bool _isInitializing = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initOidc();
  }

  Future<void> _initOidc() async {
    try {
      // 2. 初始化官方配套本地加密持久化存储
      final store = OidcDefaultStore();

      // 3. 遵照官方配置：公共客户端使用 .none 认证模式
      final clientAuth = OidcClientAuthentication.none(
        clientId: EnvConfig.applicationId,
      );

      // 4. 遵照官方配置：通过 settings 控制行为，传入必须的全局重定向路由
      final settings = OidcUserManagerSettings(
        redirectUri: Uri.parse('com.mksword.passwordbook:/callback'),
      );

      if (mounted) {
        setState(() {
          // 5. 调用官方推荐的 .lazy 构造函数，自动拉取并缓存 Discovery 发现文档
          _oidcUserManager = OidcUserManager.lazy(
            discoveryDocumentUri: Uri.parse(
                '${EnvConfig.authServer}/.well-known/openid-configuration'),
            clientCredentials: clientAuth,
            store: store,
            settings: settings,
          );
        });

        // 6. 核心步骤：必须手动触发官方声明的管理器初始化，去处理缓存和路由解析
        await _oidcUserManager!.init();

        if (mounted) {
          setState(() => _isInitializing = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInitializing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('认证管理器初始化失败: $e')),
        );
      }
    }
  }

  Future<void> _login() async {
    // 7. 防抖拦截
    if (_isLoading || _oidcUserManager == null) return;

    setState(() => _isLoading = true);

    try {
      // 8. 调用官方 Usage 规定的标准授权码流方法
      await _oidcUserManager!.loginAuthorizationCodeFlow();

      if (!mounted) return;

      // 9. 登录成功后，可以通过监听 currentUser 流或直接查询状态
      if (_oidcUserManager!.currentUser != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录成功')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未获取到登录凭证')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登录异常: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isBtnDisabled = _isInitializing || _isLoading || _oidcUserManager == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('登录'),
      ),
      body: Center(
        child: _isInitializing
            ? const CircularProgressIndicator()
            : ElevatedButton(
          onPressed: isBtnDisabled ? null : _login,
          child: _isLoading
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('登录'),
        ),
      ),
    );
  }
}
