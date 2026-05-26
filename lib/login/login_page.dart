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
  // 1. 将 Client 提升为 State 的成员变量，保证全局唯一
  OidcClient? _oidcClient;
  bool _isInitializing = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initOidcClient();
  }

  // 2. 在页面加载时单次初始化配置，避免点击登录时重复拉取 Discovery 报文
  Future<void> _initOidcClient() async {
    try {
      // 异步创建官方推荐的安全本地存储
      final secureStore = await OidcDefaultStore.create();

      final settings = OidcClientSettings(
        discoveryUri: Uri.parse(
            '${EnvConfig.authServer}/.well-known/openid-configuration'),
        clientId: EnvConfig.applicationId,
        redirectUri: Uri.parse('com.mksword.passwordbook:/callback'),
      );

      if (mounted) {
        setState(() {
          _oidcClient = OidcClient(settings, store: secureStore);
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInitializing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('认证客户端初始化失败: $e')),
        );
      }
    }
  }

  Future<void> _login() async {
    // 3. 严格的防抖拦截：加载中或未初始化完毕时直接返回
    if (_isLoading || _oidcClient == null) return;

    setState(() => _isLoading = true);

    try {
      // 使用已经初始化完毕的全局单例 client
      final result = await _oidcClient!.authorizeWithRedirect(
        redirectUri: Uri.parse('com.mksword.passwordbook:/callback'),
      );

      if (!mounted) return;

      if (result.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登录失败: ${result.error}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录成功')),
        );
        // TODO: 登录成功后，可以通过 _oidcClient!.currentResponse 拿到并保存 Token 状态
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
    // 4. UI 根据初始化状态及加载状态进行更细致的隔离
    final bool isBtnDisabled = _isInitializing || _isLoading || _oidcClient == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('登录'),
      ),
      body: Center(
        child: _isInitializing
            ? const CircularProgressIndicator() // 客户端未准备好时展示整体加载
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