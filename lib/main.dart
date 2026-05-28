import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:oidc/oidc.dart';
import 'auth/auth_service.dart';
import 'login/login_page.dart';
// 🟢 完美对齐您的真实文件路径
import 'passwordbook/passwordbook_api.dart';
import 'passwordbook/models.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Password Book',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlueAccent)),
      home: const AuthCheckPage(),
    );
  }
}

/// 认证检查页面
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
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/// 首页
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  OidcUserManager? _oidcUserManager;
  StreamSubscription? _userSubscription;
  String _displayName = '加载中...';
  bool _isLoggingOut = false;

  // 🟢 密码本列表及加载状态
  List<PasswordBook> _passwordBooks = [];
  bool _isLoadingList = true;
  String? _listError;

  @override
  void initState() {
    super.initState();
    _loadUserInfoAndData();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  /// 加载用户信息并联动发起列表 API 请求
  Future<void> _loadUserInfoAndData() async {
    try {
      final manager = await AuthService.getManager();
      setState(() {
        _oidcUserManager = manager;
      });

      // 绑定注销回切监听流
      _userSubscription = _oidcUserManager!.userChanges().listen((user) {
        if (user == null && _isLoggingOut) {
          if (mounted) {
            setState(() => _isLoggingOut = false);
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
            );
          }
        }
      });

      // 原生 Base64 击穿解密 accessToken 提取姓名
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

        // 🟢 身份确定在线后，立刻自动抓取后端密码本列表数据
        await _fetchPasswordBooks();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _displayName = '未识别用户';
          _isLoadingList = false;
          _listError = e.toString();
        });
      }
    }
  }

  /// 异步拉取后端密码本列表
  Future<void> _fetchPasswordBooks() async {
    if (!mounted) return;
    setState(() {
      _isLoadingList = true;
      _listError = null;
    });

    try {
      // 🌟 调用你指定路径封装好的 PasswordBookApiClient
      final items = await PasswordBookApiClient.getPasswordBooks();
      if (mounted) {
        setState(() {
          _passwordBooks = items;
          _isLoadingList = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _listError = e.toString().replaceAll('Exception: ', '');
          _isLoadingList = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    if (_oidcUserManager == null || _isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      _oidcUserManager!.logout();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoggingOut = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('注销失败: $e')));
      }
    }
  }

  /// 🟢 点击新建密码本按钮的点击事件
  void _createNewPasswordBook() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('触发新建密码本功能')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Password Book'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            enabled: !_isLoggingOut,
            offset: const Offset(0, 50),
            onSelected: (value) {
              if (value == 'logout') _handleLogout();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_circle, size: 24),
                  const SizedBox(width: 6),
                  Text(_displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down, size: 20),
                ],
              ),
            ),
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, size: 18, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(_isLoggingOut ? '正在注销...' : '注销登录', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      // 🟢 body：条件渲染异步状态，成功时展现 ListView 密码本列表
      body: _isLoadingList
          ? const Center(child: CircularProgressIndicator())
          : _listError != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(_listError!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchPasswordBooks,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              )
            ],
          ),
        ),
      )
          : _passwordBooks.isEmpty
          ? const Center(child: Text('暂无密码本，请点击下方新建', style: TextStyle(color: Colors.grey)))
          : RefreshIndicator(
        onRefresh: _fetchPasswordBooks, // 支持下拉刷新
        child: ListView.builder(
          itemCount: _passwordBooks.length,
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          itemBuilder: (context, index) {
            final book = _passwordBooks[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.lock_outline)),
                title: Text(book.name ?? '未命名密码本'),
                subtitle: Text(book.description ?? '暂无描述'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: 点击跳转到密码本详情
                },
              ),
            );
          },
        ),
      ),
      // 🟢 底部常驻按钮：新建密码本按钮
      persistentFooterButtons: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            onPressed: _isLoadingList ? null : _createNewPasswordBook,
            icon: const Icon(Icons.add),
            label: const Text('新建密码本', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
