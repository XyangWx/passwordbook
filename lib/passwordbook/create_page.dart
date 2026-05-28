import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'passwordbook_api.dart';
import 'models.dart';

class CreatePasswordBookPage extends StatefulWidget {
  const CreatePasswordBookPage({super.key});

  @override
  State<CreatePasswordBookPage> createState() => _CreatePasswordBookPageState();
}

class _CreatePasswordBookPageState extends State<CreatePasswordBookPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  // 🟢 完整映射后端所需的所有字段初始状态
  String _name = '';
  String _description = '';
  int _minLength = 8;
  int _maxLength = 20;
  bool _requireUppercase = true;
  bool _requireLowercase = true;
  bool _requireDigit = true;
  bool _requireSpecialChar = true;
  String _specialChars = '@#\$%^&*!';
  AllowedType _allowedType = AllowedType.general;

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isSubmitting = true);

    try {
      // 1. 组装强类型序列化请求体
      final request = NewPasswordBookRequest(
        name: _name,
        description: _description,
        minLength: _minLength,
        maxLength: _maxLength,
        requireUppercase: _requireUppercase,
        requireLowercase: _requireLowercase,
        requireDigit: _requireDigit,
        requireSpecialChar: _requireSpecialChar,
        specialChars: _specialChars,
        allowedType: _allowedType,
      );

      // 2. 发送 POST 请求提交给 ABP 后端
      await PasswordBookApiClient.createPasswordBook(request);

      if (mounted) {
        // 3. 🟢 创建成功：直接返回上一页，并传回 true 告知主页刷新列表
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新建密码本'),
        actions: [
          if (!_isSubmitting)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _submitForm,
            )
        ],
      ),
      body: _isSubmitting
          ? const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [CircularProgressIndicator(), SizedBox(height: 16), Text('正在提交到服务器...')],
      ))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 基础配置 ---
              const Text('基础信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: '密码本名称 *', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? '名称不能为空' : null,
                onSaved: (v) => _name = v!.trim(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: '描述', border: OutlineInputBorder()),
                maxLines: 2,
                onSaved: (v) => _description = v?.trim() ?? '',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AllowedType>(
                value: _allowedType,
                decoration: const InputDecoration(labelText: '允许生成的密码类型', border: OutlineInputBorder()),
                items: AllowedType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type == AllowedType.numericOnly ? '纯数字密码' : '通用复杂密码'),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _allowedType = v;
                      // 联动优化：如果是纯数字，自动调低默认长度约束
                      if (v == AllowedType.numericOnly) {
                        _minLength = 6;
                        _maxLength = 6;
                      } else {
                        _minLength = 8;
                        _maxLength = 20;
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 24),

              // --- 密码长度约束策略 ---
              const Text('长度约束策略', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _minLength.toString(),
                      decoration: const InputDecoration(labelText: '最小长度', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onSaved: (v) => _minLength = int.tryParse(v ?? '') ?? 8,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      initialValue: _maxLength.toString(),
                      decoration: const InputDecoration(labelText: '最大长度', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onSaved: (v) => _maxLength = int.tryParse(v ?? '') ?? 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- 复杂度开关策略（仅在通用复杂密码模式下可见） ---
              if (_allowedType == AllowedType.general) ...[
                const Text('复杂度策略', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('强制包含大写字母 (A-Z)'),
                  value: _requireUppercase,
                  onChanged: (v) => setState(() => _requireUppercase = v),
                ),
                SwitchListTile(
                  title: const Text('强制包含小写字母 (a-z)'),
                  value: _requireLowercase,
                  onChanged: (v) => setState(() => _requireLowercase = v),
                ),
                SwitchListTile(
                  title: const Text('强制包含数字 (0-9)'),
                  value: _requireDigit,
                  onChanged: (v) => setState(() => _requireDigit = v),
                ),
                SwitchListTile(
                  title: const Text('强制包含特殊字符'),
                  value: _requireSpecialChar,
                  onChanged: (v) => setState(() => _requireSpecialChar = v),
                ),
                if (_requireSpecialChar) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _specialChars,
                    decoration: const InputDecoration(labelText: '定制特殊字符池', hintText: '输入允许生成的特殊字符集合', border: OutlineInputBorder()),
                    onSaved: (v) => _specialChars = v ?? '',
                  ),
                ],
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      // 底部常驻保存大按钮
      bottomNavigationBar: _isSubmitting
          ? null
          : Container(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            onPressed: _submitForm,
            child: const Text('保存并创建密码本', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
