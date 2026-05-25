import 'package:flutter/material.dart';
import '../config/env_config.dart';

/// 登录页面
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // TODO: 调用授权
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('授权服务器: ${EnvConfig.authServer}'),
              ),
            );
          },
          child: const Text('登录'),
        ),
      ),
    );
  }
}