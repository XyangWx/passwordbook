import 'dart:async';
import 'package:flutter/material.dart';
import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';
import '../config/env_config.dart';
import 'package:passwordbook/main.dart'; // 引入 main.dart 以识别 HomePage 类

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

// 🟢 移除了 WidgetsBindingObserver，不再需要监听不稳定的生命周期时间差
class _LoginPageState extends State<LoginPage> {
  OidcUserManager? _oidcUserManager;
  StreamSubscription? _userSubscription; // 状态流订阅器
  bool _isInitializing = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initOidc();
  }

  @override
  void dispose() {
    _userSubscription?.cancel(); // 释放流订阅，防止内存泄漏
    super.dispose();
  }

  Future<void> _initOidc() async {
    try {
      final store = OidcDefaultStore();
      final clientAuth = OidcClientAuthentication.none(
        clientId: EnvConfig.applicationId,
      );

      final platformOptions = OidcPlatformSpecificOptions(
        android: const OidcPlatformSpecificOptions_AppAuth_Android(),
        ios: const OidcPlatformSpecificOptions_AppAuth_IosMacos(),
        macos: const OidcPlatformSpecificOptions_AppAuth_IosMacos(),
      );

      final settings = OidcUserManagerSettings(
        redirectUri: Uri.parse('com.mksword.passwordbook://callback'),
        options: platformOptions,
      );

      if (mounted) {
        final manager = OidcUserManager.lazy(
          discoveryDocumentUri: Uri.parse('${EnvConfig.authServer}/.well-known/openid-configuration'),
          clientCredentials: clientAuth,
          store: store,
          settings: settings,
        );

        setState(() {
          _oidcUserManager = manager;
        });

        // 1. 初始化管理器
        await _oidcUserManager!.init();

        // 🟢 【启动自检阀】：如果本地本来就已经有有效用户，直接放行
        if (_oidcUserManager!.currentUser != null) {
          print('🔑 [OIDC] 启动检测：本地存在有效缓存 Token，执行直接放行');
          _navigateToMain();
          return;
        }

        // 🟢 【监听流】：一旦浏览器跳回，无论网络花费 200 毫秒还是 2 秒钟，
        // 只要 Token 换取成功的瞬间，立刻精准执行跳转，绝不抢跑
        _userSubscription = _oidcUserManager!.userChanges().listen((user) {
          if (user != null && _isLoading) {
            print('🎉 [OIDC] 浏览器回调成功，捕获到新 Token: ${user.token.accessToken}');
            _navigateToMain();
          }
        });

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

  // 🟢 统一的路由出口
  void _navigateToMain() {
    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const HomePage(),
      ),
          (route) => false,
    );
  }

  Future<void> _login() async {
    if (_isLoading || _oidcUserManager == null) return;

    setState(() => _isLoading = true);

    try {
      print('🚀 [OIDC] 正在拉起授权窗...');

      // 🟢 【核心逻辑收拢】：在 Flutter 3.45.0 下，当用户成功登录并回跳时，
      // 如果网速慢，这一行会保持 await 等待，直到 Token 彻底置换完才会走完。
      // 如果用户中途点了取消或返回，底层会立刻抛出异常并进入下面的 catch 块！
      await _oidcUserManager!.loginAuthorizationCodeFlow();

    } catch (e) {
      // 🟢 如果用户在浏览器里点了“取消”或直接返回，异常会百分之百在这里被抓到
      print('❌ [OIDC] 登录中途取消或异常: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录已取消，请重新尝试')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isBtnDisabled = _isInitializing || _isLoading || _oidcUserManager == null;

    return Scaffold(
      appBar: AppBar(title: const Text('登录')),
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
