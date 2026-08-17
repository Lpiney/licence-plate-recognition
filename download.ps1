<#
.SYNOPSIS
    使用 aria2 断点续传 + 多线程下载文件（解决翻墙下载不稳定问题）。

.DESCRIPTION
    特性：
      - 断点续传：下到一半断了，重新运行本脚本会接着下
      - 16 线程分块下载
      - 无限自动重试
      - 默认走 Clash 代理 127.0.0.1:7897（可用 -Proxy 参数覆盖）

.EXAMPLE
    # 基本用法（下载到 datasets 目录）
    .\download.ps1 -Url "https://github.com/xxx/yyy/archive/refs/heads/main.zip"

    # 走 GitHub 国内加速镜像（不用代理，国内直连）
    .\download.ps1 -Url "https://github.com/xxx/yyy/archive/refs/heads/main.zip" -Mirror

    # 指定保存目录
    .\download.ps1 -Url "https://..." -OutDir "D:\datasets"

    # 不用代理直连
    .\download.ps1 -Url "https://..." -Proxy $null
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Url,

    [string]$Proxy = "http://127.0.0.1:7897",

    [string]$OutDir = "D:\Github\licence-plate-recognition\datasets",

    [switch]$Mirror
)

$ErrorActionPreference = "Stop"

# 定位 aria2（优先系统 PATH，其次项目内置便携版）
$aria2 = $null
if (Get-Command aria2c -ErrorAction SilentlyContinue) {
    $aria2 = "aria2c"
} else {
    $portable = Get-ChildItem -Path "D:\Github\licence-plate-recognition\tools\aria2" -Recurse -Filter aria2c.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($portable) { $aria2 = $portable.FullName }
}
if (-not $aria2) {
    Write-Error "找不到 aria2c，请下载 aria2 便携版放到 tools\aria2 目录（见 README）"
    exit 1
}

# 创建保存目录
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# 可选：GitHub 国内加速镜像前缀（绕过代理，国内直连更稳）
if ($Mirror) {
    if ($Url -notmatch "^https?://ghfast\.top/|^https?://gh-proxy\.com/") {
        $Url = "https://ghfast.top/$Url"
        Write-Host "使用 GitHub 加速镜像: $Url" -ForegroundColor Cyan
    }
}

# 组装 aria2 参数
$aria2Args = @(
    "-c",                          # 断点续传
    "-x", "16",                    # 每服务器最多 16 连接
    "-s", "16",                    # 分成 16 块
    "-k", "1M",                    # 每块最小 1MB
    "--max-tries=0",               # 无限重试
    "--retry-wait=5",              # 失败后等 5 秒再试
    "--file-allocation=none",      # 不预分配磁盘空间
    "--console-log-level=warn",
    "-d", $OutDir
)

if ($Proxy) {
    $aria2Args += "--all-proxy=$Proxy"
    Write-Host "代理: $Proxy" -ForegroundColor DarkGray
} else {
    Write-Host "直连下载（不使用代理）" -ForegroundColor DarkGray
}

$aria2Args += $Url

Write-Host "开始下载（断点续传，中断后重新运行本脚本即可继续）..." -ForegroundColor Green
& $aria2 $aria2Args

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n下载完成: $OutDir" -ForegroundColor Green
} else {
    Write-Host "`n下载未完成（退出码 $LASTEXITCODE），重新运行本脚本会接着下。" -ForegroundColor Yellow
}
