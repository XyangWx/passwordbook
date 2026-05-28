import 'dart:async';
import 'dart:convert'; // 引入 Dart 自带的 JSON 与 Base64 编解码器
import 'package:flutter/material.dart';
import 'package:oidc/oidc.dart'; // 引入 OIDC 核心库以获取用户信息
import 'package:oidc_default_store/oidc_default_store.dart';
import 'auth/auth_service.dart';
import 'login/login_page.dart';
import 'config/env_config.dart'; // 引入环境配置

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Password Book',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const AuthCheckPage(),
    );
  }
}

/// 认证检查页面，启动时检查access_token
class AuthCheckPage extends StatefulWidget {
  const AuthCheckPage({super.key});

  @override
  State<AuthCheckPage> createState() => _AuthCheckPageState();
}

class _AuthCheckPageState extends State<AuthCheckPage> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!mounted) return;

    if (!isLoggedIn) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// 首页（已登录用户）
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  OidcUserManager? _oidcUserManager;
  StreamSubscription? _userSubscription; // 🟢 新增：用于监听注销时用户下线的流
  String _displayName = '加载中...';
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  @override
  void dispose() {
    _userSubscription?.cancel(); // 释放订阅
    super.dispose();
  }

  /// 加载 OIDC 里的用户信息（Surname + Name）
  Future<void> _loadUserInfo() async {
    try {
      final store = OidcDefaultStore();
      final clientAuth = OidcClientAuthentication.none(clientId: EnvConfig.applicationId);

      final platformOptions = OidcPlatformSpecificOptions(
        android: const OidcPlatformSpecificOptions_AppAuth_Android(),
        ios: const OidcPlatformSpecificOptions_AppAuth_IosMacos(),
        macos: const OidcPlatformSpecificOptions_AppAuth_IosMacos(),
      );

      final settings = OidcUserManagerSettings(
        redirectUri: Uri.parse('com.mksword.passwordbook://callback'),
        // 🟢 修正：在此处补齐注销重定向本地端点（必须登记在 ABP 后台控制台）
        postLogoutRedirectUri: Uri.parse('com.mksword.passwordbook://logout-callback'),
        options: platformOptions,
      );

      final manager = OidcUserManager.lazy(
        discoveryDocumentUri: Uri.parse('${EnvConfig.authServer}/.well-known/openid-configuration'),
        clientCredentials: clientAuth,
        store: store,
        settings: settings,
      );

      setState(() {
        _oidcUserManager = manager;
      });

      await _oidcUserManager!.init();

      // 🟢 【注销路由守卫流】：当 Chrome 浏览器完成 endsession 并成功回调跳回 App 时，
      // 这里的全局流会立刻发现用户对象变为 null，从而在微秒级瞬间安全地将应用切换回登录页。
      _userSubscription = _oidcUserManager!.userChanges().listen((user) {
        if (user == null && _isLoggingOut) {
          print('👋 [OIDC] 检测到用户成功下线，执行页面回切闭环...');
          if (mounted) {
            setState(() => _isLoggingOut = false);
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
            );
          }
        }
      });

      if (_oidcUserManager!.currentUser != null) {
        Map<String, dynamic> claims = {};
        try {
          final rawAccessToken = _oidcUserManager!.currentUser!.token.accessToken;
          if (rawAccessToken != null) {
            final parts = rawAccessToken.split('.');
            if (parts.length >= 2) {
              String normalizedSource = base64Url.normalize(parts[1]);
              final String payloadString = utf8.decode(base64Url.decode(normalizedSource));
              claims = json.decode(payloadString) as Map<String, dynamic>;
            }
          }
        } catch (_) {
          claims = _oidcUserManager!.currentUser!.userInfo;
        }

        final surname = claims['family_name'] ?? claims['surname'] ?? '';
        final name = claims['given_name'] ?? claims['name'] ?? '';
        String finalName = '$surname$name'.trim();

        if (finalName.isEmpty) {
          finalName = claims['unique_name'] ?? claims['preferred_username'] ?? 'User';
        }

        if (mounted) {
          setState(() {
            _displayName = finalName;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _displayName = '未识别用户');
      }
    }
  }

  /// 执行注销（Logout）动作
  Future<void> _handleLogout() async {
    if (_oidcUserManager == null || _isLoggingOut) return;

    setState(() => _isLoggingOut = true);

    try {
      print('🚀 [OIDC] 正在拉起浏览器执行 EndSession 注销...');

      // 🟢 核心策略：触发此方法让浏览器执行远端注销，不需要 await 它的 Future 返回。
      // 注销成功并触发 com.mksword.passwordbook://logout-callback 回跳时，
      // 我们依靠上面 initState 里的 userChanges() 广播流来安全完成向 LoginPage 的过渡。
      _oidcUserManager!.logout();

    } catch (e) {
      print('❌ [OIDC] 注销发生异常: $e');
      if (mounted) {
        setState(() => _isLoggingOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('注销失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Password Book'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Row(
                children: [
                  const Icon(Icons.account_circle, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    _displayName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: const Center(
        child: Text(
          '欢迎来到密码本主页',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
      persistentFooterButtons: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            onPressed: _isLoggingOut ? null : _handleLogout,
            icon: _isLoggingOut
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                : const Icon(Icons.logout),
            label: Text(_isLoggingOut ? '正在注销...' : '注销登录', style: const TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}
