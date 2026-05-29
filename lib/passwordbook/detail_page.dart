import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'passwordbook_api.dart';
import 'models.dart';

class PasswordBookDetailPage extends StatefulWidget {
  final String bookId;
  final String bookName;

  const PasswordBookDetailPage({
    super.key,
    required this.bookId,
    required this.bookName,
  });

  @override
  State<PasswordBookDetailPage> createState() => _PasswordBookDetailPageState();
}

class _PasswordBookDetailPageState extends State<PasswordBookDetailPage> {
  PasswordBook? _detailData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  /// 异步请求完整的密码本及嵌套密码项列表
  Future<void> _fetchDetail() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await PasswordBookApiClient.viewPasswordBook(widget.bookId);
      if (mounted) {
        setState(() {
          _detailData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  /// 快捷功能：点击一键复制密码到手机剪贴板
  void _copyToClipboard(String password, String title) {
    Clipboard.setData(ClipboardData(text: password));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 【$title】的密码已成功复制到剪贴板'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bookName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchDetail,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _fetchDetail, child: const Text('重试')),
            ],
          ),
        ),
      )
          : _detailData!.passwordEntries.isEmpty
          ? const Center(
        child: Text('该密码本下暂无任何密码条目', style: TextStyle(color: Colors.grey)),
      )
          : ListView.builder(
        itemCount: _detailData!.passwordEntries.length,
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        itemBuilder: (context, index) {
          final entry = _detailData!.passwordEntries[index];

          // 映射弱密码安全级别弱提示颜色
          Color levelColor = Colors.grey;
          String levelLabel = '常规';
          if (entry.weakLevel == WeakLevel.veryWeak.value) {
            levelColor = Colors.red;
            levelLabel = '极弱密码';
          } else if (entry.weakLevel == WeakLevel.strong.value || entry.weakLevel == WeakLevel.veryStrong.value) {
            levelColor = Colors.green;
            levelLabel = '高强密码';
          }

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: levelColor.withOpacity(0.1),
                child: Icon(Icons.vpn_key_outlined, color: levelColor),
              ),
              title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(entry.hasUsername ? '账号: ${entry.username ?? "—"}' : '仅限匿名凭证'),
              children: [
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (entry.remark != null && entry.remark!.isNotEmpty) ...[
                        Text('备注描述: ${entry.remark}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('当前密码: ', style: TextStyle(fontWeight: FontWeight.bold)),
                              // 对当前密码字段进行隐藏混淆展示，或直接明文显示
                              Text(
                                entry.currentPassword ?? '******',
                                style: const TextStyle(fontFamily: 'monospace', color: Colors.deepPurple, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          if (entry.currentPassword != null)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              ),
                              onPressed: () => _copyToClipboard(entry.currentPassword!, entry.title),
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('复制'),
                            ),
                        ],
                      ),
                    ],
                  ),
                )
              ],
            ),
          );
        },
      ),
      // 底部常驻按钮，方便日后追加密码
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : () {
              // TODO: 触发新建密码条目的表单
            },
            icon: const Icon(Icons.add),
            label: const Text('在该密码本下新增密码项', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
