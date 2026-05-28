import 'package:flutter/material.dart';
import '../config/env_config.dart';
import '../auth/auth_service.dart';
import 'models.dart';

/// 密码本页面
class PasswordBookPage extends StatefulWidget {
  const PasswordBookPage({super.key});

  @override
  State<PasswordBookPage> createState() => _PasswordBookPageState();
}

class _PasswordBookPageState extends State<PasswordBookPage> {
  bool _isLoading = false;
  List<PasswordBook> _tableData = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('用户未登录')),
          );
        }
        return;
      }
      // TODO: 调用 API 获取密码本列表
      // final response = await dio.get(
      //   '${EnvConfig.apiUri}/api/password-book',
      //   options: Options(headers: {'Authorization': 'Bearer ${user.accessToken}'}),
      // );
      // _tableData = (response.data['items'] as List)
      //     .map((e) => PasswordBook.fromJson(e))
      //     .toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取数据失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('密码本'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _tableData.length,
              itemBuilder: (context, index) {
                final item = _tableData[index];
                return ListTile(
                  title: Text(item.name),
                  subtitle: Text(item.description ?? ''),
                  trailing: Text(
                    item.allowedType == 1 ? 'General' : 'NumericOnly',
                  ),
                  onTap: () {
                    // TODO: 查看详情
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: 新建密码本
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}