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
    // 🟢 【失败/取消守卫】：当用户从浏览器没有成功登录，直接点击返回键或关闭按钮回到 App 时触发
    if (state == AppLifecycleState.resumed && _isLoading) {
      // 给底层留出 500 毫秒判定缓冲时间
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _oidcUserManager?.currentUser == null) {
          // 彻底判定为失败/取消：关闭加载动画，将用户安全地留在当前登录界面
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('登录已取消或失败，请重试')),
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
          discoveryDocumentUri: Uri.parse(
              '${EnvConfig.authServer}/.well-known/openid-configuration'),
          clientCredentials: clientAuth,
          store: store,
          settings: settings,
        );

        setState(() {
          _oidcUserManager = manager;
        });

        // 移动端初始化，会自动从本地 store 恢复历史登录状态
        await _oidcUserManager!.init();

        // 🟢 【成功路由守卫流】：全权负责成功拿到 access_token 后的界面跳转逻辑
        // 当原生拦截器拿到 code 并换取 Token 写入 currentUser 的瞬时，该流会立刻感知，彻底避免卡死
        _userSubscription = _oidcUserManager!.userChanges().listen((user) {
          if (user != null && _isLoading) {
            print('🎉 [OIDC] 成功捕捉到 Access Token: ${user.token.accessToken}');

            if (mounted) {
              setState(() => _isLoading = false);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('登录成功，正在跳转...')),
              );

              // 🟢 【关键跳转闭环】：登录成功时销毁当前登录页，切回主界面
              // 方式 A：如果 LoginPage 是通过 Navigator.push 出来的，直接 pop 掉它即可安全返回 main 界面
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                // 方式 B：如果 LoginPage 是根路径或特殊情况，将其替换为您项目的实际主页路由（如 '/main' 或 '/home'）
                Navigator.pushReplacementNamed(context, '/main');
              }
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
      print('🚀 [OIDC] 正在生成安全参数并拉起浏览器授权...');

      // 触发授权码流。此处必须 await 确保前置随机数准备完毕并拉起原生窗口。
      // 成功返回的跳转动作，统一交由上方的 userChanges 监听流进行响应。
      await _oidcUserManager!.loginAuthorizationCodeFlow();

    } catch (e) {
      print('❌ [OIDC] 拉起授权异常: $e');
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
