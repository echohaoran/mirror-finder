# Mirror Finder

面向 macOS 与常见 Linux 发行版的交互式环境初始化脚本。它可安装 Node.js、Python、Docker（含 Compose）、Podman（含 Compose provider）、OpenCode、Hermes Agent 和 FlClash，并可按需配置包管理器、npm、pip、Docker/Podman 镜像与 IPv4 地址。

所有换源功能都会先请求镜像的轻量元数据接口，按实测延迟排序并展示最快的最多 5 个中国大陆镜像。选择镜像后，脚本会再次确认，才会写入配置。

## 使用

```bash
git clone git@github.com:echohaoran/mirror-finder.git
cd mirror-finder
chmod +x scripts/install.sh
./scripts/install.sh
```

也可以从任一代码托管来源用一条命令直接执行最新版：

GitHub：

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/echohaoran/mirror-finder/main/scripts/install.sh)"
```

Gitee：

```bash
bash -c "$(curl -fsSL https://gitee.com/echohaoran/mirror-finder/raw/main/scripts/install.sh)"
```

CNB：

```bash
bash -c "$(curl -fsSL https://cnb.cool/echohaoran/mirror-finder/-/git/raw/main/scripts/install.sh)"
```

该命令会下载并执行脚本，同时保留终端输入供菜单使用；如需在执行前审阅内容，请使用上方的克隆方式。

也可只执行一项，例如 `./scripts/install.sh 2` 安装 Node.js、npm 与 npx。

支持 macOS（Homebrew）以及 Debian/Ubuntu、Fedora/RHEL/Rocky/AlmaLinux、Arch Linux。Windows 请在 WSL 中运行。

## 安全说明

- 写入镜像配置前会测速、要求选择并二次确认；系统级配置会备份到 `~/.mirror-finder/backups/`。
- Docker、OpenCode 与 Hermes Agent 的官方安装脚本会先下载到临时文件再执行。
- Docker 镜像由测速结果选择；Docker Desktop 的配置需在其 Settings 页面粘贴。
- 镜像服务可用性与适用地区会变化；如无法更新，请恢复备份并改用官方源。

Docker 与 Podman 共用同一套 Docker Hub 镜像测速候选池；两者的配置格式不同。规则见 [Docker 镜像候选池](docs/docker-mirrors.md)。

## 固定 IP 与 DHCP

菜单第 11 项会自动找到默认路由网卡，要求输入 IPv4 地址、子网掩码和网关，并识别
macOS 网络服务、NetworkManager、Netplan、systemd-networkd 或传统 ifcfg 配置。写入
前会备份并提示网络可能中断；应用后会重新启用网卡或网络服务。第 12 项会恢复该网卡
的 DHCP。请避免在未设置带外访问的远程 SSH 主机上执行这两项操作。

## 参考

- [Docker 安装文档](https://docs.docker.com/engine/install/)
- [OpenCode 下载](https://dev.opencode.ai/download)
- [Hermes Agent 安装文档](https://hermes-agent.nousresearch.com/docs/)
- [FlClash Releases](https://github.com/chen08209/FlClash/releases)
