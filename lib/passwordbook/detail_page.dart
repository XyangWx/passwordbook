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
  // 🟢 1. 在类头部声明一个 Map 存储器（用来记录哪个 entryId 的眼睛被点开了）
  final Map<String, bool> _obscureMap = {};

  // 🟢 2. 辅助方法：获取当前卡片的显隐状态（默认隐藏为 true）
  bool _getObscureStatus(String entryId) {
    return _obscureMap[entryId] ?? true;
  }

  // 🟢 3. 辅助方法：切换状态
  void _toggleObscureStatus(String entryId) {
    _obscureMap[entryId] = !(_obscureMap[entryId] ?? true);
  }

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
                      if (entry.isDeleted) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: const Text('⚠️ 已删除', style: TextStyle(color: Colors.red, fontSize: 12)),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: _isLoading ? null : () async {
                            try {
                              await PasswordBookApiClient.restorePasswordEntry(widget.bookId, entry.id);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('密码项已恢复')),
                                );
                                _fetchDetail();
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('恢复失败: $e')),
                                );
                              }
                            }
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.restore, size: 16, color: Colors.green),
                              SizedBox(width: 4),
                              Text('恢复', style: TextStyle(fontSize: 13, color: Colors.green)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (!entry.isDeleted) ...[
                        TextButton(
                          onPressed: _isLoading ? null : () async {
                            try {
                              await PasswordBookApiClient.deletePasswordEntry(widget.bookId, entry.id);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('密码项已删除')),
                                );
                                _fetchDetail();
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('删除失败: $e')),
                                );
                              }
                            }
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_outline, size: 16, color: Colors.orange),
                              SizedBox(width: 4),
                              Text('删除', style: TextStyle(fontSize: 13, color: Colors.orange)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (entry.remark != null && entry.remark!.isNotEmpty) ...[
                        Text('备注描述: ${entry.remark}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 12),
                      ],

                      // 🟢 彻底修复横向溢出（RenderFlex overflowed）的版本
                      StatefulBuilder(
                        builder: (BuildContext context, StateSetter setCardState) {
                          final isObscured = _getObscureStatus(entry.id);

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // 🟢 1. 核心修正：用 Expanded 把密码区包裹起来，强行限制其最大宽度为屏幕剩余空间
                              Expanded(
                                child: Row(
                                  children: [
                                    const Text('当前密码: ', style: TextStyle(fontWeight: FontWeight.bold)),

                                    // 🟢 2. 核心修正：用 Flexible 包裹密码文本，使其在变成明文过长时自动缩进或截断
                                    Flexible(
                                      child: Text(
                                        isObscured
                                            ? '••••••'
                                            : (entry.currentPassword ?? '暂无密码'),
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          color: Colors.deepPurple,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                        overflow: TextOverflow.ellipsis, // 🟢 如果明文实在太长，末尾自动显示“...”防止挤爆布局
                                      ),
                                    ),
                                    const SizedBox(width: 4),

                                    // 小眼睛按钮
                                    if (entry.currentPassword != null)
                                      IconButton(
                                        padding: EdgeInsets.zero, // 紧凑排版
                                        constraints: const BoxConstraints(), // 移除默认大边距
                                        icon: Icon(
                                          isObscured ? Icons.visibility_off : Icons.visibility,
                                          size: 18,
                                          color: Colors.grey,
                                        ),
                                        onPressed: () {
                                          setCardState(() {
                                            _toggleObscureStatus(entry.id);
                                          });
                                        },
                                        tooltip: isObscured ? '显示密码' : '隐藏密码',
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12), // 留出安全的横向间距

                              // 右侧复制按钮（现在有了左侧 Expanded 撑开，它会被稳稳固定在屏幕右侧）
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
                          );
                        },
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

  // 🟢 新增控制变量：控制密码文本是否处于模糊隐藏状态（默认隐藏）
  bool _obscurePassword = true;

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
          // 💡 联动优化：生成新密码后，自动切换为明文显示，方便用户立刻看到生成的密码
          _obscurePassword = false;
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. 🟢 升级后的密码专用输入框容器
                  Expanded(
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword, // 🟢 动态绑定明暗文隐藏状态
                      keyboardType: TextInputType.visiblePassword, // 优化系统键盘适配
                      decoration: InputDecoration(
                        labelText: '密码 *',
                        hintText: '请输入密码',
                        // 🟢 在输入框内部右侧添加“小眼睛”点击切换按钮
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                          tooltip: _obscurePassword ? '显示明文' : '隐藏密码',
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '密码为必填项';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  // 2. 刷新生成随机密码的独立按钮
                  IconButton(
                    onPressed: _isGenerating ? null : _generatePassword,
                    icon: _isGenerating
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh, color: Colors.deepPurple),
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

