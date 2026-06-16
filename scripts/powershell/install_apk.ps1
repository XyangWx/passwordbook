<#
.SYNOPSIS
    将指定的 APK 通过 adb 安装到当前连接的 Android 设备/虚拟机。

.DESCRIPTION
    在脚本顶部通过 $androidSdkPath 变量配置 Android SDK 根目录。
    脚本会将 <SDK>/platform-tools 临时加入当前进程的 PATH，
    然后调用 adb install 把传入的 APK 装到当前已连接的 adb 设备。
    PATH 修改仅在当前进程内有效，不影响系统环境。

.PARAMETER apkPath
    [必填] 要安装的 .apk 文件的绝对或相对路径。
    若文件不存在或扩展名不是 .apk，脚本会直接报错退出。

.NOTES
    如需更换 Android SDK 路径，请修改脚本顶部的 $androidSdkPath 变量。
    请确保 SDK 中已存在 platform-tools/adb.exe（Windows）或 adb（Linux/macOS）。
#>

# ============================================================
# 🔧 用户配置区：把下面这一行改成你自己的 Android SDK 根目录
# ============================================================
$androidSdkPath = "C:\Users\YourName\AppData\Local\Android\Sdk"

# ============================================================
# 🛡️ 防呆校验
# ============================================================

# 1. Android SDK 路径必须存在
if ([string]::IsNullOrEmpty($androidSdkPath)) {
    Write-Error "❌ 错误: 脚本顶部的 `$androidSdkPath 未配置，请先填写 Android SDK 根目录。"
    exit 1
}
if (-not (Test-Path -LiteralPath $androidSdkPath)) {
    Write-Error "❌ 错误: Android SDK 路径不存在: $androidSdkPath"
    Write-Host "💡 请修改脚本顶部的 `$androidSdkPath 变量为正确的 SDK 根目录。" -ForegroundColor Yellow
    exit 1
}

# 2. adb 可执行文件必须存在（platform-tools 是 SDK 标准子目录）
$platformTools = Join-Path -Path $androidSdkPath -ChildPath "platform-tools"
$adbExe = Join-Path -Path $platformTools -ChildPath "adb.exe"
if (-not (Test-Path -LiteralPath $adbExe)) {
    Write-Error "❌ 错误: 未在 SDK 中找到 adb.exe: $adbExe"
    Write-Host "💡 请确认 SDK 已通过 Android Studio / sdkmanager 安装了 platform-tools。" -ForegroundColor Yellow
    exit 1
}

# 3. APK 路径参数校验
$apkPath = $args[0]
if ([string]::IsNullOrEmpty($apkPath)) {
    Write-Error "❌ 错误: 缺少 APK 路径参数。"
    Write-Host "💡 规范用法: .\install_apk.ps1 <APK_PATH>" -ForegroundColor Yellow
    Write-Host "  例: .\install_apk.ps1 D:\build\app-release.apk" -ForegroundColor Yellow
    exit 1
}
if (-not (Test-Path -LiteralPath $apkPath)) {
    Write-Error "❌ 错误: APK 路径不存在: $apkPath"
    exit 1
}
if (-not ($apkPath.ToLower().EndsWith(".apk"))) {
    Write-Error "❌ 错误: 指定路径不是 APK 文件: $apkPath"
    Write-Host "💡 请提供扩展名为 .apk 的文件路径。" -ForegroundColor Yellow
    exit 1
}

# ============================================================
# 🚀 把 platform-tools 临时加入当前进程 PATH
# ============================================================
$env:Path = "$platformTools;$env:Path"
Write-Host "🔧 已临时将 platform-tools 加入 PATH: $platformTools" -ForegroundColor Cyan

# ============================================================
# 📱 执行 adb install 到当前已连接设备
# ============================================================
$absoluteApkPath = (Resolve-Path -LiteralPath $apkPath).Path
Write-Host "📦 正在安装 APK 到当前连接的设备: $absoluteApkPath" -ForegroundColor Green
adb install -r "$absoluteApkPath"
$installExitCode = $LASTEXITCODE

if ($installExitCode -eq 0) {
    Write-Host "🎉 安装成功！" -ForegroundColor Green
} else {
    Write-Error "❌ adb install 执行失败，退出码: $installExitCode"
    Write-Host "💡 请确认: 1) 模拟器或设备已启动  2) adb devices 能看到设备  3) USB 调试已授权" -ForegroundColor Yellow
    exit $installExitCode
}
