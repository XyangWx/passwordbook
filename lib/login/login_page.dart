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
  StreamSubscription? _userSubscription; // 状态流订阅器
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
    _userSubscription?.cancel(); // 释放流
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 🟢 当从浏览器完成授权跳回 App 前台时
    if (state == AppLifecycleState.resumed && _isLoading) {
      // 延迟给底层置换 Token 留出时间
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && _oidcUserManager?.currentUser == null) {
          // 如果回来后依然没有用户上线，说明用户在浏览器按了返回键取消了登录
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

        // 🟢 【核心守卫流】：全权负责成功跳回后的生命周期闭环
        // 浏览器授权成功重定向回来时，只要凭证一写入，这里会立刻捕捉并执行跳转，绝不卡死
        _userSubscription = _oidcUserManager!.userChanges().listen((user) {
          if (user != null && _isLoading) {
            print('🎉 [OIDC] 成功捕获到用户登录凭证！UID: ${user.uid}');
            if (mounted) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('登录成功')),
              );
              // TODO: 在这里执行主页跳转
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
      print('🚀 [OIDC] 开始准备授权码模式前置安全参数...');

      // 🟢 【核心找回】：必须使用 await 恢复完整的授权登录调用链！
      // 这样插件才能正常生成 state, code_challenge，并有条不紊地拉起内置的 Chrome 授权页面。
      await _oidcUserManager!.loginAuthorizationCodeFlow();

      print('📱 [OIDC] 浏览器已成功唤起。正在等待用户在网页完成认证...');

    } catch (e) {
      // 捕获可能在拉起浏览器那一瞬间发生的异常
      print('❌ [OIDC] 拉起授权页面失败: $e');
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
