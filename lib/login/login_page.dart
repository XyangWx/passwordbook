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
      final store = OidcDefaultStore();
      final clientAuth = OidcClientAuthentication.none(
        clientId: EnvConfig.applicationId,
      );

      // 🌟 核心修正 1：严格对齐官方规范，将 ios 和 macos 拆分为两个独立的具名参数进行配置
      final platformOptions = OidcPlatformSpecificOptions(
        android: const OidcPlatformSpecificOptions_AppAuth_Android(),
        ios: const OidcPlatformSpecificOptions_AppAuth_IosMacos(),
        macos: const OidcPlatformSpecificOptions_AppAuth_IosMacos(),
      );

      final settings = OidcUserManagerSettings(
        redirectUri: Uri.parse('com.mksword.passwordbook:/callback'),
        options: platformOptions,
      );

      if (mounted) {
        setState(() {
          _oidcUserManager = OidcUserManager.lazy(
            discoveryDocumentUri: Uri.parse(
                '${EnvConfig.authServer}/.well-known/openid-configuration'),
            clientCredentials: clientAuth,
            store: store,
            settings: settings,
          );
        });

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
    if (_isLoading || _oidcUserManager == null) return;

    setState(() => _isLoading = true);

    try {
      // 🌟 核心修正 2：严格依照底层函数签名，通过 extraParameters 将 PKCE (S256) 传输字段直接带入
      await _oidcUserManager!.loginAuthorizationCodeFlow(
        extraParameters: const {
          OidcConstants_AuthParameters.codeChallengeMethod:
          OidcConstants_AuthorizeRequest_CodeChallengeMethod.s256,
        },
      );

      if (!mounted) return;

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
