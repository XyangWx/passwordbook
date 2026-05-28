import 'dart:async';
import 'dart:convert'; // 引入 Dart 自带的 JSON 与 Base64 编解码器
import 'package:flutter/material.dart';
import 'package:oidc/oidc.dart'; // 引入 OIDC 核心库以获取用户信息
import 'package:oidc_default_store/oidc_default_store.dart';
import 'auth/auth_service.dart';
import 'login/login_page.dart';
import 'config/env_config.dart'; // 引入环境配置
import 'passwordbook/models.dart';
import 'passwordbook/passwordbook_api.dart';

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
  StreamSubscription? _userSubscription; // 用于监听注销时用户下线的流
  String _displayName = '加载中...';
  bool _isLoggingOut = false;
  List<PasswordBook> _passwordBooks = [];
  bool _isLoadingPasswordBooks = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadPasswordBooks();
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

      // 注销路由守卫流：当 Chrome 浏览器完成 endsession 并成功回调跳回 App 时触发
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

  /// 加载密码本列表
  Future<void> _loadPasswordBooks() async {
    setState(() => _isLoadingPasswordBooks = true);
    try {
      final books = await PasswordBookApiClient.getPasswordBooks();
      if (mounted) {
        setState(() => _passwordBooks = books);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取密码本失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingPasswordBooks = false);
      }
    }
  }

  /// 执行注销（Logout）动作
  Future<void> _handleLogout() async {
    if (_oidcUserManager == null || _isLoggingOut) return;

    setState(() => _isLoggingOut = true);

    try {
      print('🚀 [OIDC] 正在拉起浏览器执行 EndSession 注销...');
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
      // 🟢 Header 修改：通过 PopupMenuButton 自定义 child 实现整体触控按钮
      appBar: AppBar(
        title: const Text('Password Book'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            enabled: !_isLoggingOut, // 正在注销过程中禁用菜单
            offset: const Offset(0, 50), // 🟢 设置垂直偏移量，确保菜单恰好贴在 AppBar 下方弹出
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              }
            },
            // 自定义触发器：将头像、名字、下拉小箭头打包装进一个 Material 质感的 InkWell 区域
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_circle, size: 24),
                  const SizedBox(width: 6),
                  Text(
                    _displayName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down, size: 20), // 增加下拉视觉暗示
                ],
              ),
            ),
            // 下拉弹出的菜单项定义
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, size: 18, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      _isLoggingOut ? '正在注销...' : '注销登录',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      // 🟢 移除了底部的 persistentFooterButtons，使页面内容展示区恢复通透
      body: _isLoadingPasswordBooks
          ? const Center(child: CircularProgressIndicator())
          : _passwordBooks.isEmpty
              ? const Center(child: Text('暂无密码本'))
              : ListView.builder(
                  itemCount: _passwordBooks.length,
                  itemBuilder: (context, index) {
                    final book = _passwordBooks[index];
                    return Card(
                      child: ListTile(
                        title: Text(book.name),
                        subtitle: Text(book.description ?? ''),
                        trailing: Text(
                          book.allowedType == 1 ? 'General' : 'NumericOnly',
                        ),
                        onTap: () {
                          // TODO: 查看密码本详情
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: 新建密码本
        },
        icon: const Icon(Icons.add),
        label: const Text('新建密码本'),
      ),
    );
  }
}
