import 'dart:async';
import 'package:flutter/material.dart';
import 'package:oidc/oidc.dart';
import 'package:passwordbook/main.dart';
import '../auth/auth_service.dart'; // 引入重构后的服务

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  OidcUserManager? _oidcUserManager;
  StreamSubscription? _userSubscription;
  bool _isInitializing = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initOidcPage();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  /// 🟢 瘦身后极简的初始化
  Future<void> _initOidcPage() async {
    try {
      // 🌟 直接调取抽象好的全局单例，杜绝重复配置
      final manager = await AuthService.getManager();

      setState(() {
        _oidcUserManager = manager;
      });

      // 启动自检
      if (_oidcUserManager!.currentUser != null) {
        _navigateToMain();
        return;
      }

      // 绑定成功回跳流
      _userSubscription = _oidcUserManager!.userChanges().listen((user) {
        if (user != null && _isLoading) {
          print('🎉 [OIDC] 回调成功，捕获到新 Token');
          _navigateToMain();
        }
      });

      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInitializing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('认证管理器加载失败: $e')),
        );
      }
    }
  }

  void _navigateToMain() {
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
    );
  }

  Future<void> _login() async {
    if (_isLoading || _oidcUserManager == null) return;
    setState(() => _isLoading = true);
    try {
      await _oidcUserManager!.loginAuthorizationCodeFlow();
    } catch (e) {
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
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('登录'),
        ),
      ),
    );
  }
}
