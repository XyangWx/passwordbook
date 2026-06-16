#!/bin/bash
#
# 统一的 APK 安装脚本（bash 版）。
#
# 在脚本顶部通过 ANDROID_SDK_PATH 变量配置 Android SDK 根目录。
# 脚本会将 <SDK>/platform-tools 临时加入当前进程的 PATH，
# 然后调用 adb install 把传入的 APK 装到当前已连接的 adb 设备。
# PATH 修改仅在当前进程内有效，不影响系统环境。
#
# 用法:
#   ./scripts/bash/install_apk.sh <APK_PATH>
#       例: ./scripts/bash/install_apk.sh /home/user/build/app-release.apk
#
# 参数:
#   $1  [必填] 要安装的 .apk 文件的绝对或相对路径
#
# 注意:
#   - 如需更换 Android SDK 路径，请修改脚本顶部的 ANDROID_SDK_PATH 变量。
#   - 脚本会自动剔除 APK 路径中的 Unicode 双向控制字符（U+200E/F、U+202A–E、
#     U+2066–9），防止从文件管理器"复制路径"按钮粘入的不可见字符导致路径失效。
#   - bash 版面向 Linux / WSL / macOS；Windows 请使用同名的 install_apk.ps1。

# ============================================================
# 🔧 用户配置区：把下面这一行改成你自己的 Android SDK 根目录
# ============================================================
ANDROID_SDK_PATH="/opt/android-sdk"

# ============================================================
# 🛡️ 防呆校验
# ============================================================

# 1. Android SDK 路径必须存在
if [[ -z "$ANDROID_SDK_PATH" ]]; then
    echo "❌ 错误: 脚本顶部的 ANDROID_SDK_PATH 未配置，请先填写 Android SDK 根目录。" >&2
    exit 1
fi
if [[ ! -d "$ANDROID_SDK_PATH" ]]; then
    echo "❌ 错误: Android SDK 路径不存在: $ANDROID_SDK_PATH" >&2
    echo "💡 请修改脚本顶部的 ANDROID_SDK_PATH 变量为正确的 SDK 根目录。" >&2
    exit 1
fi

# 2. adb 可执行文件必须存在（platform-tools 是 SDK 标准子目录）
PLATFORM_TOOLS="$ANDROID_SDK_PATH/platform-tools"
ADB="$PLATFORM_TOOLS/adb"
if [[ ! -x "$ADB" ]]; then
    echo "❌ 错误: 未在 SDK 中找到可执行的 adb: $ADB" >&2
    echo "💡 请确认 SDK 已通过 Android Studio / sdkmanager 安装了 platform-tools。" >&2
    exit 1
fi

# 3. APK 路径参数校验
APK_PATH="$1"
if [[ -z "$APK_PATH" ]]; then
    echo "❌ 错误: 缺少 APK 路径参数。" >&2
    echo "💡 规范用法: \$0 <APK_PATH>" >&2
    echo "  例: \$0 /home/user/build/app-release.apk" >&2
    exit 1
fi

# 3.1 净化路径：剔除 Unicode 双向控制字符（文件管理器"复制路径"会塞这些）
#     范围: LRM/RLM (U+200E/F), LRE/RLE/PDF/LRO/RLO (U+202A–E), LRI/RLI/FSI/PDI (U+2066–9)
ORIGINAL_APK_PATH="$APK_PATH"
# 优先用 python3 精确按 codepoint 范围剔除（最可靠）
if command -v python3 >/dev/null 2>&1; then
    APK_PATH=$(python3 -c "
import re, sys
s = sys.argv[1]
s = re.sub(r'[\\u200E\\u200F\\u202A-\\u202E\\u2066-\u2069]', '', s)
sys.stdout.write(s)
" "$APK_PATH")
else
    # 退化方案：用 perl（绝大多数 Linux/macOS 自带）
    APK_PATH=$(printf '%s' "$APK_PATH" | perl -CSD -pe 's/[\x{200E}\x{200F}\x{202A}-\x{202E}\x{2066}-\x{2069}]//g')
fi
if [[ "$APK_PATH" != "$ORIGINAL_APK_PATH" ]]; then
    echo "🧹 已自动剔除路径中的 Unicode 双向控制字符"
fi

if [[ ! -e "$APK_PATH" ]]; then
    echo "❌ 错误: APK 路径不存在: $APK_PATH" >&2
    exit 1
fi
if [[ ! "$APK_PATH" =~ \.apk$ ]]; then
    echo "❌ 错误: 指定路径不是 APK 文件: $APK_PATH" >&2
    echo "💡 请提供扩展名为 .apk 的文件路径。" >&2
    exit 1
fi

# ============================================================
# 🚀 把 platform-tools 临时加入当前进程 PATH
# ============================================================
export PATH="$PLATFORM_TOOLS:$PATH"
echo "🔧 已临时将 platform-tools 加入 PATH: $PLATFORM_TOOLS"

# ============================================================
# 📱 执行 adb install 到当前已连接设备
# ============================================================
# realpath 解析为绝对路径（与 PowerShell 的 Resolve-Path 等价）
if command -v realpath >/dev/null 2>&1; then
    ABSOLUTE_APK_PATH=$(realpath "$APK_PATH")
else
    # macOS 默认没有 realpath，退化用 cd + pwd
    ABSOLUTE_APK_PATH="$(cd "$(dirname "$APK_PATH")" && pwd)/$(basename "$APK_PATH")"
fi
echo "📦 正在安装 APK 到当前连接的设备: $ABSOLUTE_APK_PATH"
"$ADB" install -r "$ABSOLUTE_APK_PATH"
INSTALL_EXIT_CODE=$?

if [[ $INSTALL_EXIT_CODE -eq 0 ]]; then
    echo "🎉 安装成功！"
else
    echo "❌ adb install 执行失败，退出码: $INSTALL_EXIT_CODE" >&2
    echo "💡 请确认: 1) 模拟器或设备已启动  2) adb devices 能看到设备  3) USB 调试已授权" >&2
    exit $INSTALL_EXIT_CODE
fi
