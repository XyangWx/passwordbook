import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:oidc/oidc.dart';
import 'auth/auth_service.dart';
import 'login/login_page.dart';
// 🟢 完美对齐您的真实文件路径
import 'passwordbook/passwordbook_api.dart';
import 'passwordbook/models.dart';
import 'passwordbook/create_page.dart';
import 'passwordbook/detail_page.dart';

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

  // 🟢 完美对齐：点击底部按钮时，直接拉起全新独立的新建大表单页面
  void _createNewPasswordBook() async {
    // 1. 动态跳转到我们刚刚编写的、包含所有完整策略字段的独立大页面
    final bool? isNeedRefresh = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const CreatePasswordBookPage(), // 👈 记得在 main.dart 顶部 import 'passwordbook/create_page.dart';
      ),
    );

    // 2. 🟢 联动闭环：如果从创建页成功提交并返回（传回了 true），主页立刻自动重新抓取接口刷新 ListView！
    if (isNeedRefresh == true) {
      await _fetchPasswordBooks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 密码本创建成功，列表已同步刷新！')),
        );
      }
    }
  }

  /// 🟢 1. 弹出条目操作菜单（包含查看与删除）
  void _showPasswordBookMenu(PasswordBook book) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)), // 圆角美化
      ),
      builder: (BuildContext bc) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min, // 紧凑包裹内容
            children: [
              // 提示区头部
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  '密码本：${book.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ),
              const Divider(height: 1),

              // 🟢 完美对齐：点击查看密码本，直接切入包含全套密码列表的详情页
              ListTile(
                leading: const Icon(Icons.visibility, color: Colors.deepPurple),
                title: const Text('查看密码本'),
                onTap: () {
                  Navigator.pop(bc); // 关闭底部菜单栏

                  // 顺畅拉起独立的密码列表详情页，传入当前点击的 book 属性
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PasswordBookDetailPage(
                        bookId: book.id,
                        bookName: book.name,
                      ),
                    ),
                  );
                },
              ),

              // 菜单项二：删除密码本
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('删除密码本', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(bc); // 先关闭菜单栏
                  _confirmDeletePasswordBook(book); // 唤起二次确认，防止误删
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 🟢 2. 安全策略：删除前的二次确认弹窗
  void _confirmDeletePasswordBook(PasswordBook book) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('安全警告'),
            ],
          ),
          content: Text('您确定要彻底删除密码本【${book.name}】吗？删除后其名下的所有密码项都将丢失，此操作不可撤销！'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(dialogContext); // 关闭确认弹窗
                await _deletePasswordBook(book); // 驱动执行远端删除
              },
              child: const Text('确认删除'),
            ),
          ],
        );
      },
    );
  }

  /// 🟢 3. 驱动远端物理删除并同步本地刷新
  Future<void> _deletePasswordBook(PasswordBook book) async {
    setState(() => _isLoadingList = true); // 开启全屏加载动画

    try {
      // 🌟 核心打通：调用刚生成的真实删除 API 接口，Dio 拦截器会自动在底层追加 Token
      await PasswordBookApiClient.deletePasswordBook(book.id);

      // 联动刷新：删除成功后，原地触发 fetch 方法向 ABP 重刷 ListView 列表
      await _fetchPasswordBooks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🎉 密码本【${book.name}】已成功移除！')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingList = false); // 发生异常时恢复列表显示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 删除失败: $e'), backgroundColor: Colors.red),
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
      // 🟢 替换原有的 body: const Center(...) 块
      body: _isLoadingList
          ? const Center(child: CircularProgressIndicator())
          : _listError != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_listError!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchPasswordBooks,
              child: const Text('重试'),
            )
          ],
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
                title: Text(book.name),
                subtitle: Text(book.description ?? '暂无描述'),
                trailing: const Icon(Icons.chevron_right),
                // 🟢 核心修改：点击密码本条目时，弹出包含两个菜单项的底部面板
                onTap: () {
                  _showPasswordBookMenu(book);
                },
              ),
            );

          },
        ),
      ),
      // 🟢 底部常驻按钮：新建密码本按钮
      // 🟢 挂载在 Scaffold 括号内部，与 appBar、body 平级
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
