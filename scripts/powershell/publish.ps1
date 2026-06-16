<#
.SYNOPSIS
    统一的 Flutter Android 打包脚本（PowerShell 版）。

.DESCRIPTION
    自动清理构建缓存并按模式编译 Debug / Release APK。Release 模式会通过
    --dart-define 注入生产环境配置常量（AUTHSERVER / API_URI），由
    lib/config/env_config.dart 在运行时读取。Debug 模式不注入常量，
    退回到代码内硬编码的默认测试环境地址。

.PARAMETER buildMode
    构建模式。取值：
        debug   - 编译测试包，不注入 --dart-define
        release - 编译正式包，必须同时提供后两个 URL 参数

.PARAMETER authServer
    [仅 release 模式必填] OIDC 认证服务器地址，例：https://auth.prod.com

.PARAMETER apiUri
    [仅 release 模式必填] 后端 API 地址，例：https://api.prod.com

.EXAMPLE
    PS> .\scripts\powershell\publish.ps1 debug
    （编译测试包，使用代码默认的测试环境配置）

.EXAMPLE
    PS> .\scripts\powershell\publish.ps1 release https://auth.prod.com https://api.prod.com
    （编译正式包，注入生产环境认证服务器与 API 地址）
#>

# 统一清理 Flutter 构建缓存与依赖
Write-Host "🧹 正在清理旧的编译缓存并获取依赖包..." -ForegroundColor Cyan
flutter clean
flutter pub get

# 抓取第一个位置参数作为构建模式
$buildMode = $args[0]

if ($buildMode -eq "debug") {
    # 🟢 编译调试包分支：不带任何常量注入，自动降级退回到代码内的默认测试环境
    Write-Host "📱 正在编译测试环境调试包 [Debug APK]..." -ForegroundColor Green
    flutter build apk --debug

} elseif ($buildMode -eq "release") {
    # 🟢 编译正式包分支：从位置参数中提取生产环境真实地址
    $authServer = $args[1]
    $apiUri = $args[2]

    # 安全策略防呆校验：如果模式是 release 但漏填了域名参数，直接红字报错阻断
    if ([string]::IsNullOrEmpty($authServer) -or [string]::IsNullOrEmpty($apiUri)) {
        Write-Error "❌ 错误: 打正式包 [release] 模式下，必须提供 AUTHSERVER 和 API_URI 参数！"
        Write-Host "💡 规范用法: .\build.ps1 release https://prod.com https://prod.com" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "🚀 正在注入生产环境常量，编译正式包 [Release APK]..." -ForegroundColor Magenta
    flutter build apk --release `
      --dart-define=AUTHSERVER=$authServer `
      --dart-define=API_URI=$apiUri

} else {
    # 参数错误时的提示指南
    Write-Error "❌ 错误: 未知的构建模式 '$buildMode'。"
    Write-Host "💡 规范用法:" -ForegroundColor Yellow
    Write-Host "  打调试包: .\build.ps1 debug" -ForegroundColor Yellow
    Write-Host "  打正式包: .\build.ps1 release <AUTH_SERVER_URL> <API_URI_URL>" -ForegroundColor Yellow
    exit 1
}

Write-Host "🎉 编译结束！" -ForegroundColor Green
