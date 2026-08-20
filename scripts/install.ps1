#Requires -Version 5.1
<#
.SYNOPSIS
  Mirror Finder interactive bootstrapper for Windows 10/11.
.DESCRIPTION
  Run from an elevated PowerShell session for package installation and network
  configuration. Every configuration write is confirmed and backed up where
  practical. Pass a menu number to run a single item, for example:
  .\scripts\install.ps1 18
#>

[CmdletBinding()]
param(
    [ValidateRange(1, 23)]
    [int]$Item
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$script:AppName = 'mirror-finder'
$script:BackupRoot = Join-Path $HOME ('.{0}\backups\{1}' -f $script:AppName, (Get-Date -Format 'yyyyMMdd-HHmmss'))
$script:SelectedMirror = $null
$script:CnbAssetBase = if ($env:MIRROR_FINDER_ASSET_BASE) { $env:MIRROR_FINDER_ASSET_BASE.TrimEnd('/') } else { 'https://cnb.cool/echohaoran/mirror-finder/-/git/raw/main/assets' }

function Write-Info([string]$Message) { Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-WarningMessage([string]$Message) { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Stop-WithError([string]$Message) { throw $Message }

function Show-Banner {
    Write-Host ''
    Write-Host 'MIRROR FINDER - Windows / PowerShell' -ForegroundColor Cyan
    Write-Host 'https://github.com/echohaoran/mirror-finder'
    Write-Host 'https://echohaoran.top'
    Write-Host ''
}

function Confirm-Action([string]$Prompt) {
    return (Read-Host "$Prompt [y/N]") -match '^[Yy]$'
}

function Test-Command([string]$Name) {
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Stop-WithError '此操作需要管理员权限。请右键 PowerShell，选择“以管理员身份运行”。'
    }
}

function Backup-Path([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $driveSafe = $Path -replace ':', ''
    $target = Join-Path $script:BackupRoot $driveSafe.TrimStart('\')
    $parent = Split-Path -Parent $target
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    Copy-Item -LiteralPath $Path -Destination $target -Recurse -Force
    Write-Info "已备份 $Path 到 $target"
}

function Save-TextBackup([string]$Name, [string[]]$Content) {
    New-Item -ItemType Directory -Force -Path $script:BackupRoot | Out-Null
    $target = Join-Path $script:BackupRoot $Name
    $Content | Set-Content -LiteralPath $target -Encoding UTF8
    Write-Info "已备份到 $target"
}

function Get-MirroredAsset([string]$Path, [string]$Upstream, [string]$Destination) {
    $cnbUrl = "$script:CnbAssetBase/$Path"
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $cnbUrl -OutFile $Destination
        Write-Info "资源来自 CNB：$Path"
    } catch {
        Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
        Write-WarningMessage "CNB 资源暂不可用，回退官方上游：$Upstream"
        Invoke-WebRequest -UseBasicParsing -Uri $Upstream -OutFile $Destination
    }
}

function Get-HttpLatency([string]$Url) {
    try {
        $watch = [Diagnostics.Stopwatch]::StartNew()
        Invoke-WebRequest -UseBasicParsing -Method Head -Uri $Url -TimeoutSec 8 | Out-Null
        $watch.Stop()
        return $watch.Elapsed.TotalSeconds
    } catch {
        if ($_.Exception.Response -and ([int]$_.Exception.Response.StatusCode) -eq 401) {
            $watch.Stop()
            return $watch.Elapsed.TotalSeconds
        }
        try {
            $watch = [Diagnostics.Stopwatch]::StartNew()
            Invoke-WebRequest -UseBasicParsing -Method Get -Uri $Url -TimeoutSec 8 | Out-Null
            $watch.Stop()
            return $watch.Elapsed.TotalSeconds
        } catch {
            if ($_.Exception.Response -and ([int]$_.Exception.Response.StatusCode) -eq 401) {
                $watch.Stop()
                return $watch.Elapsed.TotalSeconds
            }
            return $null
        }
    }
}

function Select-FastMirror([string]$Kind) {
    $candidates = switch ($Kind) {
        'npm' {
            @(
                @{ Name = 'npmmirror'; Url = 'https://registry.npmmirror.com'; Probe = '/-/ping' },
                @{ Name = '腾讯云'; Url = 'https://mirrors.cloud.tencent.com/npm'; Probe = '/-/ping' },
                @{ Name = '阿里云'; Url = 'https://mirrors.aliyun.com/npm'; Probe = '/-/ping' },
                @{ Name = '华为云'; Url = 'https://repo.huaweicloud.com/repository/npm'; Probe = '/-/ping' }
            )
        }
        'pip' {
            @(
                @{ Name = '清华大学'; Url = 'https://pypi.tuna.tsinghua.edu.cn/simple'; Probe = '/' },
                @{ Name = '中国科学技术大学'; Url = 'https://pypi.mirrors.ustc.edu.cn/simple'; Probe = '/' },
                @{ Name = '阿里云'; Url = 'https://mirrors.aliyun.com/pypi/simple'; Probe = '/' },
                @{ Name = '腾讯云'; Url = 'https://mirrors.cloud.tencent.com/pypi/simple'; Probe = '/' },
                @{ Name = '华为云'; Url = 'https://repo.huaweicloud.com/repository/pypi/simple'; Probe = '/' }
            )
        }
        'docker' {
            @(
                @{ Name = 'DaoCloud'; Url = 'https://docker.m.daocloud.io'; Probe = '/v2/' },
                @{ Name = '1Panel'; Url = 'https://docker.1panel.live'; Probe = '/v2/' },
                @{ Name = '1MS'; Url = 'https://docker.1ms.run'; Probe = '/v2/' },
                @{ Name = 'Docker Proxy'; Url = 'https://dockerproxy.net'; Probe = '/v2/' },
                @{ Name = 'HubFast'; Url = 'https://free.hubfast.cn'; Probe = '/v2/' }
            )
        }
        default { Stop-WithError "未知镜像类型：$Kind" }
    }

    Write-Info "正在测试 $($candidates.Count) 个镜像的连通性与延迟..."
    $reachable = @()
    foreach ($candidate in $candidates) {
        $seconds = Get-HttpLatency ($candidate.Url.TrimEnd('/') + $candidate.Probe)
        if ($null -ne $seconds) {
            $reachable += [PSCustomObject]@{ Name = $candidate.Name; Url = $candidate.Url; Seconds = $seconds }
        }
    }
    $reachable = @($reachable | Sort-Object Seconds | Select-Object -First 5)
    if ($reachable.Count -eq 0) { Write-WarningMessage '没有可访问的候选镜像，未修改配置。'; return $false }
    for ($index = 0; $index -lt $reachable.Count; $index++) {
        Write-Host ('  {0}) {1,-16} {2,7:N3}s  {3}' -f ($index + 1), $reachable[$index].Name, $reachable[$index].Seconds, $reachable[$index].Url)
    }
    $selection = Read-Host '请选择镜像编号（0 取消）'
    $number = 0
    if (-not [int]::TryParse($selection, [ref]$number) -or $number -lt 1 -or $number -gt $reachable.Count) {
        Write-WarningMessage '已取消。'
        return $false
    }
    $script:SelectedMirror = $reachable[$number - 1].Url
    Write-Info "已选择：$script:SelectedMirror"
    return $true
}

function Install-Chocolatey {
    if (Test-Command 'choco') { Write-Info "Chocolatey 已安装：$(choco --version)"; return }
    Assert-Administrator
    Write-WarningMessage '将从 Chocolatey 官方地址下载并执行 PowerShell 安装器。'
    if (-not (Confirm-Action '继续安装 Chocolatey？')) { return }
    $installer = Join-Path ([IO.Path]::GetTempPath()) ('chocolatey-install-{0}.ps1' -f [guid]::NewGuid())
    try {
        Get-MirroredAsset 'installers/chocolatey-install.ps1' 'https://community.chocolatey.org/install.ps1' $installer
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
        if (-not (Test-Command 'choco')) { Stop-WithError 'Chocolatey 安装器已运行，但当前会话仍找不到 choco。请重开 PowerShell。' }
    } finally { Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue }
}

function Require-Chocolatey { if (-not (Test-Command 'choco')) { Install-Chocolatey }; if (-not (Test-Command 'choco')) { Stop-WithError '需要 Chocolatey 才能继续。' } }

function Install-ChocoPackage([string[]]$Packages) {
    Assert-Administrator
    Require-Chocolatey
    & choco install @Packages -y
    if ($LASTEXITCODE -notin 0, 1641, 3010) { Stop-WithError "Chocolatey 安装失败，退出码：$LASTEXITCODE" }
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Configure-ChocolateySource {
    Assert-Administrator
    Require-Chocolatey
    Save-TextBackup 'chocolatey-sources.txt' (& choco source list --limit-output)
    $sourceUrl = Read-Host 'Chocolatey 源地址（留空使用官方源 https://community.chocolatey.org/api/v2/）'
    if ([string]::IsNullOrWhiteSpace($sourceUrl)) { $sourceUrl = 'https://community.chocolatey.org/api/v2/' }
    if ($null -eq (Get-HttpLatency $sourceUrl)) { Stop-WithError "无法访问 Chocolatey 源：$sourceUrl" }
    if (-not (Confirm-Action "确认将 Chocolatey 主源设置为 $sourceUrl 吗？")) { return }
    & choco source remove --name mirror-finder --yes 2>$null | Out-Null
    & choco source add --name mirror-finder --source $sourceUrl --priority 1 --yes
    if ($LASTEXITCODE -ne 0) { Stop-WithError 'Chocolatey 源配置失败。' }
    Write-Info 'Chocolatey 源已配置；原源列表已备份。'
}

function Install-Node { Install-ChocoPackage @('nodejs-lts'); node --version; npm --version }
function Configure-Npm { if (-not (Test-Command 'npm')) { Stop-WithError '请先安装 Node.js。' }; if (Select-FastMirror 'npm') { if (Confirm-Action "确认写入 $script:SelectedMirror 为 npm 源吗？") { npm config set registry $script:SelectedMirror } } }
function Install-Python { Install-ChocoPackage @('python'); python --version; python -m pip --version }
function Configure-Pip { if (-not (Test-Command 'python')) { Stop-WithError '请先安装 Python。' }; if (Select-FastMirror 'pip') { if (Confirm-Action "确认写入 $script:SelectedMirror 为 pip 源吗？") { python -m pip config set global.index-url $script:SelectedMirror } } }

function Get-WslDistribution {
    if (-not (Test-Command 'wsl.exe')) { Stop-WithError '当前 Windows 不支持 wsl.exe，请先安装适用的 Windows 更新。' }
    $distributions = @(wsl.exe --list --quiet 2>$null | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($distributions.Count -eq 0) {
        Assert-Administrator
        if (-not (Confirm-Action '未找到 WSL 发行版，是否安装 WSL 2 与 Ubuntu？安装后可能需要重启 Windows。')) { Stop-WithError '需要 WSL 发行版才能继续。' }
        wsl.exe --install --distribution Ubuntu
        if ($LASTEXITCODE -ne 0) { Stop-WithError "WSL/Ubuntu 安装失败，退出码：$LASTEXITCODE" }
        Stop-WithError 'WSL/Ubuntu 安装已启动。请按系统提示重启并完成 Ubuntu 首次初始化，然后重新运行此菜单项。'
    }
    if ($distributions.Count -eq 1) { return $distributions[0] }
    Write-Host '可用 WSL 发行版：'
    for ($index = 0; $index -lt $distributions.Count; $index++) { Write-Host "  $($index + 1)) $($distributions[$index])" }
    $selection = Read-Host '请选择发行版编号'
    $number = 0
    if (-not [int]::TryParse($selection, [ref]$number) -or $number -lt 1 -or $number -gt $distributions.Count) { Stop-WithError 'WSL 发行版选择无效。' }
    return $distributions[$number - 1]
}

function Invoke-Wsl([string]$Distribution, [string]$Command, [switch]$Root) {
    $arguments = @('--distribution', $Distribution)
    if ($Root) { $arguments += @('--user', 'root') }
    $arguments += @('--', 'bash', '-lc', $Command)
    & wsl.exe @arguments
    if ($LASTEXITCODE -ne 0) { Stop-WithError "WSL 命令执行失败，退出码：$LASTEXITCODE" }
}

function Install-Docker {
    $distribution = Get-WslDistribution
    Write-WarningMessage "将在 WSL $distribution 中移除冲突包，配置 Docker stable 仓库，并安装 Engine、CLI、containerd、Buildx 与 Compose。"
    if (-not (Confirm-Action '继续安装完整的生产型 WSL Docker Engine 吗？')) { return }
    $dockerInstaller = "$script:CnbAssetBase/installers/docker-install.sh"
    $dockerInstallerHash = '32637cfe8de8c2d2a29a2b6435051829a56dd93f2dfe3c825c0315bb54163119'
    $bootstrap = "if ! command -v curl >/dev/null; then if command -v apt-get >/dev/null; then apt-get update && apt-get install -y curl ca-certificates; elif command -v dnf >/dev/null; then dnf install -y curl ca-certificates; elif command -v pacman >/dev/null; then pacman -Sy --needed --noconfirm curl ca-certificates; else exit 1; fi; fi; tmp=`$(mktemp); curl -fsSL '$dockerInstaller' -o `"`$tmp`"; echo '$dockerInstallerHash  ' `"`$tmp`" | sha256sum --check --status; sh `"`$tmp`"; rm -f `"`$tmp`""
    Invoke-Wsl $distribution $bootstrap -Root
    $linuxUser = (& wsl.exe --distribution $distribution -- bash -lc 'id -un').Trim()
    if ($LASTEXITCODE -eq 0 -and $linuxUser) { Invoke-Wsl $distribution "usermod -aG docker '$linuxUser'" -Root }
    Invoke-Wsl $distribution 'service docker start >/dev/null 2>&1 || systemctl start docker >/dev/null 2>&1 || true' -Root
    Invoke-Wsl $distribution 'docker --version && docker buildx version && docker compose version'
    Write-Info "Docker Engine 已安装到 WSL：$distribution。重新进入 WSL 后 docker 组权限生效。"
}

function Configure-DockerMirror {
    if (-not (Select-FastMirror 'docker')) { return }
    $distribution = Get-WslDistribution
    if (-not (Confirm-Action "确认在 WSL $distribution 中写入 $script:SelectedMirror 为 Docker registry mirror 吗？")) { return }
    $json = @{ 'registry-mirrors' = @($script:SelectedMirror) } | ConvertTo-Json -Compress
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
    $command = "mkdir -p /etc/docker; test ! -e /etc/docker/daemon.json || cp /etc/docker/daemon.json /etc/docker/daemon.json.mirror-finder-$(Get-Date -Format 'yyyyMMddHHmmss').bak; echo '$encoded' | base64 -d > /etc/docker/daemon.json; service docker restart >/dev/null 2>&1 || systemctl restart docker"
    Invoke-Wsl $distribution $command -Root
    Write-Info "WSL $distribution 的 Docker 镜像已配置。"
}

function Get-GitHubReleaseAsset([string]$Repository, [string]$Pattern) {
    $headers = @{ 'User-Agent' = 'mirror-finder' }
    $release = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/$Repository/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -match $Pattern } | Select-Object -First 1
    if ($null -eq $asset) { Stop-WithError "未在 $Repository 最新版本找到匹配 Windows 安装包：$Pattern" }
    return $asset.browser_download_url
}

function Install-Podman {
    $distribution = Get-WslDistribution
    if (-not (Confirm-Action "确认在 WSL $distribution 中安装 Podman 与 Compose provider 吗？")) { return }
    $command = 'if command -v apt-get >/dev/null; then apt-get update && apt-get install -y podman podman-compose; elif command -v dnf >/dev/null; then dnf install -y podman podman-compose; elif command -v pacman >/dev/null; then pacman -Sy --needed --noconfirm podman podman-compose; else echo "不支持的 WSL 包管理器" >&2; exit 1; fi'
    Invoke-Wsl $distribution $command -Root
    Invoke-Wsl $distribution 'podman --version; (podman compose version || podman-compose --version)'
    Write-Info "Podman 已安装到 WSL：$distribution。"
}

function Configure-PodmanMirror {
    if (-not (Select-FastMirror 'docker')) { return }
    $distribution = Get-WslDistribution
    if (-not (Confirm-Action "确认在 WSL $distribution 中配置 $script:SelectedMirror 为 Podman 镜像吗？")) { return }
    $hostName = $script:SelectedMirror -replace '^https?://', '' -replace '/$', ''
    $content = "[[registry]]`nprefix = `"docker.io`"`nlocation = `"docker.io`"`n`n[[registry.mirror]]`nlocation = `"$hostName`"`n"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($content))
    $command = "mkdir -p /etc/containers/registries.conf.d; test ! -e /etc/containers/registries.conf.d/99-mirror-finder-dockerhub.conf || cp /etc/containers/registries.conf.d/99-mirror-finder-dockerhub.conf /etc/containers/registries.conf.d/99-mirror-finder-dockerhub.conf.$(Get-Date -Format 'yyyyMMddHHmmss').bak; echo '$encoded' | base64 -d > /etc/containers/registries.conf.d/99-mirror-finder-dockerhub.conf"
    Invoke-Wsl $distribution $command -Root
    Write-Info "WSL $distribution 的 Podman 镜像已配置。"
}

function Install-OpenCode { Install-ChocoPackage @('opencode'); if (Test-Command 'opencode') { opencode --version } }

function Install-Hermes {
    Write-WarningMessage '将从 Hermes Agent 官方地址下载并执行 Windows PowerShell 安装器。'
    if (-not (Confirm-Action '继续安装 Hermes Agent？')) { return }
    $installer = Join-Path ([IO.Path]::GetTempPath()) ('hermes-install-{0}.ps1' -f [guid]::NewGuid())
    try {
        Get-MirroredAsset 'installers/hermes-install.ps1' 'https://hermes-agent.nousresearch.com/install.ps1' $installer
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer
        if ($LASTEXITCODE -ne 0) { Stop-WithError "Hermes 安装失败，退出码：$LASTEXITCODE" }
    } finally { Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue }
}

function Install-FlClash {
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'amd64|x64' }
    $url = Get-GitHubReleaseAsset 'chen08209/FlClash' "windows.*($arch).*(\.exe|\.msi)$"
    $extension = [IO.Path]::GetExtension(([Uri]$url).AbsolutePath)
    $installer = Join-Path ([IO.Path]::GetTempPath()) ("FlClash-{0}{1}" -f [guid]::NewGuid(), $extension)
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $installer
        if (-not (Confirm-Action "已从 FlClash 官方 GitHub 下载，继续运行 $url 吗？")) { return }
        $process = Start-Process -FilePath $installer -Wait -PassThru
        if ($process.ExitCode -notin 0, 1641, 3010) { Stop-WithError "FlClash 安装失败，退出码：$($process.ExitCode)" }
    } finally { Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue }
}

function Get-DefaultInterface {
    $route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -AddressFamily IPv4 | Sort-Object RouteMetric, InterfaceMetric | Select-Object -First 1
    if ($null -eq $route) { Stop-WithError '未找到 IPv4 默认路由。' }
    return $route
}

function Test-IPv4Address([string]$Address) {
    $parsed = $null
    return [Net.IPAddress]::TryParse($Address, [ref]$parsed) -and $parsed.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork
}

function Configure-StaticIp {
    Assert-Administrator
    $route = Get-DefaultInterface
    $adapter = Get-NetAdapter -InterfaceIndex $route.InterfaceIndex
    $ip = Read-Host '固定 IPv4 地址'
    $prefixText = Read-Host '前缀长度（例如 24）'
    $gateway = Read-Host '默认网关'
    $prefix = 0
    if (-not (Test-IPv4Address $ip) -or -not [int]::TryParse($prefixText, [ref]$prefix) -or $prefix -lt 1 -or $prefix -gt 32 -or -not (Test-IPv4Address $gateway)) {
        Stop-WithError 'IPv4 地址、前缀长度或网关格式无效。'
    }
    $snapshot = @{
        Adapter = @($adapter | Select-Object Name, InterfaceDescription, InterfaceIndex, MacAddress)
        IP = @(Get-NetIPAddress -InterfaceIndex $route.InterfaceIndex -AddressFamily IPv4)
        Route = @(Get-NetRoute -InterfaceIndex $route.InterfaceIndex -AddressFamily IPv4)
        DNS = @(Get-DnsClientServerAddress -InterfaceIndex $route.InterfaceIndex -AddressFamily IPv4)
    } | ConvertTo-Json -Depth 6
    Save-TextBackup "network-$($route.InterfaceIndex).json" @($snapshot)
    Write-WarningMessage "应用后将重置网卡 $($adapter.Name) 的 IPv4 配置，当前网络可能中断。"
    if (-not (Confirm-Action "确认配置 $ip/$prefix，网关 $gateway 吗？")) { return }
    Set-NetIPInterface -InterfaceIndex $route.InterfaceIndex -AddressFamily IPv4 -Dhcp Disabled
    Get-NetIPAddress -InterfaceIndex $route.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false
    New-NetIPAddress -InterfaceIndex $route.InterfaceIndex -IPAddress $ip -PrefixLength $prefix -DefaultGateway $gateway | Out-Null
    Write-Info '固定 IPv4 已配置。'
}

function Restore-Dhcp {
    Assert-Administrator
    $route = Get-DefaultInterface
    $adapter = Get-NetAdapter -InterfaceIndex $route.InterfaceIndex
    Write-WarningMessage "将恢复网卡 $($adapter.Name) 的 DHCP，当前网络可能中断。"
    if (-not (Confirm-Action '确认恢复 DHCP 吗？')) { return }
    Set-NetIPInterface -InterfaceIndex $route.InterfaceIndex -AddressFamily IPv4 -Dhcp Enabled
    Set-DnsClientServerAddress -InterfaceIndex $route.InterfaceIndex -ResetServerAddresses
    Get-NetIPAddress -InterfaceIndex $route.InterfaceIndex -AddressFamily IPv4 -PrefixOrigin Manual -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false
    ipconfig.exe /renew $adapter.InterfaceAlias
    Write-Info 'DHCP 已恢复。'
}

function Install-FFmpeg { Install-ChocoPackage @('ffmpeg'); ffmpeg -version | Select-Object -First 1 }
function Install-Git { Install-ChocoPackage @('git'); git --version }

function Install-PlaywrightChrome {
    if (-not (Test-Command 'npm')) { Write-Info '未检测到 Node.js，先安装 Node.js LTS。'; Install-Node }
    if (-not (Confirm-Action '确认全局安装 Playwright 并下载 Playwright 管理的 Google Chrome 吗？')) { return }
    npm install --global playwright
    if ($LASTEXITCODE -ne 0) { Stop-WithError 'Playwright npm 安装失败。' }
    npx playwright install chrome
    if ($LASTEXITCODE -ne 0) { Stop-WithError 'Chrome 下载或安装失败。' }
    Write-Info 'Playwright + Chrome 安装完成。'
}

function Install-PiAgent {
    if (-not (Test-Command 'npm')) { Write-Info '未检测到 Node.js，先安装 Node.js LTS。'; Install-Node }
    if (-not (Confirm-Action '确认安装 Pi Agent？')) { return }
    $package = Join-Path ([IO.Path]::GetTempPath()) ('pi-coding-agent-{0}.tgz' -f [guid]::NewGuid())
    try {
        Get-MirroredAsset 'packages/pi-coding-agent-0.73.1.tgz' 'https://registry.npmjs.org/@mariozechner/pi-coding-agent/-/pi-coding-agent-0.73.1.tgz' $package
        npm install --global $package
        if ($LASTEXITCODE -ne 0) { Stop-WithError 'Pi Agent 安装失败。' }
    } finally { Remove-Item -LiteralPath $package -Force -ErrorAction SilentlyContinue }
}

function Install-CodexCli {
    if (-not (Test-Command 'npm')) { Write-Info '未检测到 Node.js，先安装 Node.js LTS。'; Install-Node }
    if (-not (Confirm-Action '确认通过当前 npm 国内镜像安装 Codex CLI？')) { return }
    npm install --global '@openai/codex'
    if ($LASTEXITCODE -ne 0) { Stop-WithError 'Codex CLI 安装失败。' }
    codex --version
}

function Install-CodexDesktop {
    if (-not (Confirm-Action '确认下载并运行 Codex/ChatGPT Windows 桌面客户端安装器？')) { return }
    $installer = Join-Path ([IO.Path]::GetTempPath()) ('ChatGPT-Installer-{0}.exe' -f [guid]::NewGuid())
    try {
        Get-MirroredAsset 'desktop/ChatGPT-Installer.exe' 'https://get.microsoft.com/installer/download/9PLM9XGG6VKS?cid=website_cta_psi' $installer
        $process = Start-Process -FilePath $installer -Wait -PassThru
        if ($process.ExitCode -notin 0, 1641, 3010) { Stop-WithError "桌面客户端安装器退出码：$($process.ExitCode)" }
    } finally { Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue }
}

function Install-ClaudeCode {
    if (-not (Test-Command 'git')) { Write-Info 'Claude Code Windows 版需要 Git，先安装 Git。'; Install-Git }
    if (-not (Confirm-Action '确认安装 Claude Code CLI stable 渠道？')) { return }
    $installer = Join-Path ([IO.Path]::GetTempPath()) ('claude-code-install-{0}.ps1' -f [guid]::NewGuid())
    try {
        Get-MirroredAsset 'installers/claude-code-install.ps1' 'https://claude.ai/install.ps1' $installer
        & $installer stable
        if ($LASTEXITCODE -ne 0) { Stop-WithError "Claude Code 安装失败，退出码：$LASTEXITCODE" }
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
        if (Test-Command 'claude') { claude --version } else { Write-WarningMessage 'Claude Code 已安装；请重开 PowerShell 后运行 claude 登录。' }
    } finally { Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue }
}

function Test-ChromeInstalled {
    $paths = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
    )
    return $null -ne ($paths | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1)
}

function Check-Environment {
    Write-Host "`n系统：$([Environment]::OSVersion.VersionString)"
    Write-Host "PowerShell：$($PSVersionTable.PSVersion)"
    Write-Host "架构：$env:PROCESSOR_ARCHITECTURE`n"
    foreach ($tool in @('git', 'choco', 'node', 'npm', 'python', 'pip', 'ffmpeg', 'opencode', 'hermes', 'claude', 'playwright')) {
        $command = Get-Command $tool -ErrorAction SilentlyContinue
        if ($command) { Write-Host ('  OK  {0,-12} {1}' -f $tool, $command.Source) -ForegroundColor Green }
        else { Write-Host ('  --  {0,-12} 未安装或不在 PATH 中' -f $tool) -ForegroundColor DarkYellow }
    }
    if (Test-ChromeInstalled) { Write-Host '  OK  chrome       已安装' -ForegroundColor Green }
    else { Write-Host '  --  chrome       未在常见路径找到' -ForegroundColor DarkYellow }
    if (Test-Command 'wsl.exe') {
        $distributions = @(wsl.exe --list --quiet 2>$null | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        foreach ($distribution in $distributions) {
            $containerTools = (& wsl.exe --distribution $distribution -- bash -lc 'for tool in docker podman; do if command -v "$tool" >/dev/null; then printf "%s=OK " "$tool"; else printf "%s=-- " "$tool"; fi; done' 2>$null) -join ''
            Write-Host ('  WSL {0,-14} {1}' -f $distribution, $containerTools.Trim())
        }
    }
    Write-Host ''
}

function Invoke-MenuItem([int]$Number) {
    switch ($Number) {
        1 { Configure-ChocolateySource }
        2 { Install-Node }
        3 { Configure-Npm }
        4 { Install-Python }
        5 { Configure-Pip }
        6 { Install-Docker }
        7 { Configure-DockerMirror }
        8 { Install-Podman }
        9 { Configure-PodmanMirror }
        10 { Install-OpenCode }
        11 { Install-Hermes }
        12 { Install-FlClash }
        13 { Configure-StaticIp }
        14 { Restore-Dhcp }
        15 { Install-Chocolatey }
        16 { Install-FFmpeg }
        17 { Install-PlaywrightChrome }
        18 { Check-Environment }
        19 { Install-PiAgent }
        20 { Install-CodexCli }
        21 { Install-CodexDesktop }
        22 { Install-Git }
        23 { Install-ClaudeCode }
        default { Stop-WithError "无效选项：$Number" }
    }
}

function Show-Menu {
    $menu = @'
1) 配置 Chocolatey 源    2) 安装 Node.js/npm/npx
3) 更换 npm/npx 源       4) 安装 Python
5) 更换 Python(pip) 源   6) 在 WSL 安装 Docker
7) 配置 WSL Docker 镜像  8) 在 WSL 安装 Podman
9) 配置 Podman 镜像     10) 安装 OpenCode
11) 安装 Hermes Agent   12) 安装 FlClash
13) 配置固定 IP         14) 恢复 DHCP
15) 安装 Chocolatey     16) 安装 FFmpeg
17) 安装 Playwright+Chrome
18) 检查开发与媒体工具环境
19) 安装 Pi Agent        20) 安装 Codex CLI
21) 安装 Codex 桌面客户端
22) 安装 Git             23) 安装 Claude Code CLI
0) 退出
'@
    Write-Host $menu
}

if ($env:OS -ne 'Windows_NT') { Stop-WithError '此脚本仅支持 Windows 10/11。' }
Show-Banner
if ($PSBoundParameters.ContainsKey('Item')) { Invoke-MenuItem $Item; return }
while ($true) {
    Show-Menu
    $choice = Read-Host '请选择'
    if ($choice -eq '0') { break }
    $number = 0
    if ([int]::TryParse($choice, [ref]$number)) { Invoke-MenuItem $number }
    else { Write-WarningMessage "无效选项：$choice" }
}
