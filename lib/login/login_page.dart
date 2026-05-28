import 'dart:async';
import 'package:flutter/material.dart';
import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';
import '../config/env_config.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with WidgetsBindingObserver {
  OidcUserManager? _oidcUserManager;
  StreamSubscription? _userSubscription; // 用于状态流订阅器
  bool _isInitializing = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initOidc();
  }

  @override
  void dispose() {
    _userSubscription?.cancel(); // 释放流，防止内存泄漏
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 如果回到前台后过了半秒，currentUser 依然是空，说明用户在浏览器点了取消或者没登录直接回来了
    if (state == AppLifecycleState.resumed && _isLoading) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _oidcUserManager?.currentUser == null) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('登录已取消')),
          );
        }
      });
    }
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
        // 严格的双斜杠格式，匹配 Android 拦截器
        redirectUri: Uri.parse('com.mksword.passwordbook://callback'),
        options: platformOptions,
      );

      if (mounted) {
        final manager = OidcUserManager.lazy(
          discoveryDocumentUri: Uri.parse(
              '${EnvConfig.authServer}/.well-known/openid-configuration'),
          clientCredentials: clientAuth,
          store: store,
          settings: settings,
        );

        setState(() {
          _oidcUserManager = manager;
        });

        await _oidcUserManager!.init();

        // 🟢 核心修正：使用官方标准的 userChanges() 流监听
        // 当原生拦截器拿到凭证、写入 currentUser 的那一瞬间，这个流会立刻感知，彻底解开前端卡死
        _userSubscription = _oidcUserManager!.userChanges().listen((user) {
          if (user != null && _isLoading) {
            print('🎉 [OIDC 状态流成功捕捉] 用户已成功上线: ${user.uid}');
            if (mounted) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('登录成功')),
              );
              // TODO: 在这里直接进行页面跳转闭环
              // Navigator.pushReplacementNamed(context, '/home');
            }
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

  Future<void> _login() async {
    if (_isLoading || _oidcUserManager == null) return;

    setState(() => _isLoading = true);

    try {
      // 🟢 核心策略：触发此方法拉起浏览器，不需要 await 它的返回结果。
      // 因为在 Flutter 3.45.0 原生生命周期切换时，部分设备上单行的 Future 会丢失，
      // 我们依靠上面 initState 里的 userChanges() 广播流来安全地处理成功回调。
      _oidcUserManager!.loginAuthorizationCodeFlow();

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拉起登录异常: $e')),
        );
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
