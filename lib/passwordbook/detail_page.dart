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

  /// 🟢 点击"新增密码项"按钮，弹出创建对话框
  void _showCreatePasswordEntryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CreatePasswordEntryDialog(
        bookId: widget.bookId,
        onSuccess: () {
          _fetchDetail();
        },
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
            onPressed: _isLoading ? null : _showCreatePasswordEntryDialog,
            icon: const Icon(Icons.add),
            label: const Text('在该密码本下新增密码项', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}

/// 🟢 创建密码条目对话框
class _CreatePasswordEntryDialog extends StatefulWidget {
  final String bookId;
  final VoidCallback onSuccess;

  const _CreatePasswordEntryDialog({required this.bookId, required this.onSuccess});

  @override
  State<_CreatePasswordEntryDialog> createState() => _CreatePasswordEntryDialogState();
}

class _CreatePasswordEntryDialogState extends State<_CreatePasswordEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _remarkController = TextEditingController();

  bool _hasUsername = true;
  int _passwordType = 0;
  WeakLevel _weakLevel = WeakLevel.strong;
  bool _isLoading = false;
  bool _isGenerating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _generatePassword() async {
    setState(() => _isGenerating = true);
    try {
      final request = GetRandomPasswordRequest(
        passwordBookId: widget.bookId,
        passwordType: _passwordType == 0 ? AllowedType.numericOnly : AllowedType.general,
        weakLevel: _weakLevel,
      );
      final response = await PasswordBookApiClient.generateRandomPassword(request);
      if (mounted) {
        setState(() {
          _passwordController.text = response.password;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成密码失败: $e')),
        );
      }
    }
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final request = CreatePasswordRequest(
        title: _titleController.text.trim(),
        hasUsername: _hasUsername,
        username: _hasUsername ? _usernameController.text.trim() : null,
        passwordType: _passwordType,
        weakLevel: _weakLevel,
        password: _passwordController.text,
        remark: _remarkController.text.trim().isEmpty ? null : _remarkController.text.trim(),
      );

      await PasswordBookApiClient.createPasswordEntry(widget.bookId, request);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('密码项创建成功')),
        );
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
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
    return AlertDialog(
      title: const Text('新增密码项'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: '标题 *', hintText: '如：QQ邮箱'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '标题为必填项';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('需要用户名/账号'),
                value: _hasUsername,
                onChanged: (value) => setState(() => _hasUsername = value),
                contentPadding: EdgeInsets.zero,
              ),
              if (_hasUsername) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: '用户名/账号', hintText: '请输入用户名'),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: '密码 *', hintText: '请输入密码'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '密码为必填项';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isGenerating ? null : _generatePassword,
                    icon: _isGenerating
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh),
                    tooltip: '生成随机密码',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('密码类型', style: TextStyle(fontSize: 12, color: Colors.grey)),
              DropdownButtonFormField<int>(
                value: _passwordType,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('纯数字')),
                  DropdownMenuItem(value: 1, child: Text('通用复杂')),
                ],
                onChanged: (value) => setState(() => _passwordType = value!),
              ),
              const SizedBox(height: 12),
              const Text('密码强度', style: TextStyle(fontSize: 12, color: Colors.grey)),
              DropdownButtonFormField<WeakLevel>(
                value: _weakLevel,
                items: WeakLevel.values.map((e) => DropdownMenuItem(value: e, child: Text(e.label))).toList(),
                onChanged: (value) => setState(() => _weakLevel = value!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _remarkController,
                decoration: const InputDecoration(labelText: '备注', hintText: '可选'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleCreate,
          child: _isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('创建'),
        ),
      ],
    );
  }
}
