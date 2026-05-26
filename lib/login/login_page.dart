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
  // 使用官方标准推荐的 OidcUserManager 代替底层 client
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
      // 如果 OidcDefaultStore.create() 报错，说明你本地包的旧版本是直接 new 出来的
      // 这里的工厂方法如果找不到，可以直接 fallback 到 OidcDefaultStore()
      late final OidcPlatformStorage store;
      try {
        store = await OidcDefaultStore.create();
      } catch (_) {
        // 针对部分旧版本兼容
        store = OidcDefaultStore();
      }

      // 使用 OidcProviderMetadata 代替发现文档配置
      final metadata = await OidcProviderMetadata.discover(
        Uri.parse('${EnvConfig.authServer}/.well-known/openid-configuration'),
      );

      if (mounted) {
        setState(() {
          _oidcUserManager = OidcUserManager.lazy(
            discoveryDocument: metadata,
            store: store,
          );
          _isInitializing = false;
        });
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
      // 移动端/桌面端统一推荐使用最稳妥的本地浏览器授权弹窗
      final result = await _oidcUserManager!.loginAuthorizationCodeFlow(
        originalUri: Uri.parse('com.mksword.passwordbook:/callback'),
      );

      if (!mounted) return;

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录已被用户取消')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录成功')),
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