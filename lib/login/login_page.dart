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
      // 1. 在 0.14.x 版本中，直接同步实例化 OidcDefaultStore
      final OidcStore secureStore = OidcDefaultStore();

      // 2. 0.14.x 使用 OidcProviderMetadata.get 方法异步拉取发现文档
      final metadata = await OidcProviderMetadata.get(
        Uri.parse('${EnvConfig.authServer}/.well-known/openid-configuration'),
      );

      if (mounted) {
        setState(() {
          // 3. 严格契合 0.14.x 的命名参数：接收 metadata 字段
          _oidcUserManager = OidcUserManager.lazy(
            metadata: metadata,
            store: secureStore,
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
      // 4. 执行标准 Code 授权流
      final result = await _oidcUserManager!.loginAuthorizationCodeFlow(
        originalUri: Uri.parse('com.mksword.passwordbook:/callback'),
      );

      if (!mounted) return;

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录已被取消')),
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