#!/bin/bash

# 🟢 统一的强力清理（对齐 3.45.0 构建缓存清理规范）
echo "🧹 正在清理旧的编译缓存..."
flutter clean
flutter pub get

# 1. 检查第一个必填参数：构建模式
BUILD_MODE=$1

if [ "$BUILD_MODE" = "debug" ]; then
  # 🟢 编译调试包分支：不带任何 --dart-define 变量注入，安全退回到代码默认的测试环境
  echo "📱 正在编译测试环境调试包 [Debug APK]..."
  flutter build apk --debug

elif [ "$BUILD_MODE" = "release" ]; then
  # 🟢 编译正式包分支：要求必须提供生产环境的地址参数
  AUTH_SERVER=$2
  API_URI=$3

  # 健壮性防呆校验：如果选了 release 却漏填了域名参数，直接报错阻断，防止打出残缺包
  if [ -z "$AUTH_SERVER" ] || [ -z "$API_URI" ]; then
    echo "❌ 错误: 打正式包 [release] 模式下，必须提供 AUTHSERVER 和 API_URI 参数！"
    echo "💡 正确用法: $0 release https://prod.com https://prod.com"
    exit 1
  fi

  echo "🚀 正在注入生产环境常量，编译正式包 [Release APK]..."
  flutter build apk --release \
    --dart-define=AUTHSERVER="$AUTH_SERVER" \
    --dart-define=API_URI="$API_URI"

else
  # 参数错误时的提示指南
  echo "❌ 错误: 未知构建模式 '$BUILD_MODE'。"
  echo "💡 规范用法:"
  echo "  打调试包: $0 debug"
  echo "  打正式包: $0 release <AUTH_SERVER_URL> <API_URI_URL>"
  exit 1
fi

echo "🎉 编译结束！"
