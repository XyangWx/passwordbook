import 'dart:async';
import 'package:flutter/material.dart';
import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';
import '../config/env_config.dart';
import 'package:passwordbook/main.dart'; // 🟢 成功引入 main.dart 以识别 HomePage 类

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
    WidgetsBinding.instance.addObserver(this); // 注册生命周期监听
    _initOidc();
  }

  @override
  void dispose() {
    _userSubscription?.cancel(); // 释放流订阅，防止内存泄漏
    WidgetsBinding.instance.removeObserver(this); // 移除生命周期监听
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 🟢 【取消/失败守卫】：当用户在浏览器内未登录，直接按返回键切换回 App 时触发
    if (state == AppLifecycleState.resumed && _isLoading) {
      // 延迟给底层的本地异步写磁盘动作留出缓冲
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && _oidcUserManager?.currentUser == null) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('登录已取消，请重新尝试')),
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
        // 🛠️ 严格的双斜杠格式，必须与 Android 端配置百分之百匹配
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

        // 1. 初始化管理器：会尝试从本地默认 Store 中恢复可能存在的历史 Session
        await _oidcUserManager!.init();

        // 🟢 【安全阀 1】：启动自检。如果发现本地本来就已经有合法的未过期用户，
        // 说明根本不需要再登录，直接原地销毁登录页并进入 HomePage
        if (_oidcUserManager!.currentUser != null) {
          print('🔑 [OIDC] 启动检测：本地存在有效缓存 Token，执行直接放行');
          _navigateToMain();
          return;
        }

        // 🟢 【安全阀 2】：配置成功重定向流。只有当本地无有效用户、且用户主动点击了登录（_isLoading == true）、
        // 并且浏览器成功跳回、换取 Access Token 完毕后，这里才会精准开闸放行。
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

  // 🟢 统一的路由出口：彻底销毁当前登录栈，进入主界面 HomePage
  void _navigateToMain() {
    if (!mounted) return;
    setState(() => _isLoading = false);

    // 销毁当前的登录页，并强行把主界面 HomePage 压入栈底作为全新的根路由，防止用户按返回键退回登录页
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const HomePage(), // 🟢 完美契合您 main.dart 里的常量构造函数
      ),
          (route) => false,
    );
  }

  Future<void> _login() async {
    if (_isLoading || _oidcUserManager == null) return;

    setState(() => _isLoading = true);

    try {
      print('🚀 [OIDC] 正在生成安全参数并拉起授权窗...');

      // 触发完整的授权码模式，拉起 Chrome Custom Tabs
      await _oidcUserManager!.loginAuthorizationCodeFlow();

    } catch (e) {
      print('❌ [OIDC] 拉起授权界面发生异常: $e');
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
