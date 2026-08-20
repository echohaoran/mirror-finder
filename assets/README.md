# 资源镜像

本目录保存安装器能够稳定引用的小型引导脚本与固定版本安装包。运行时统一优先访问
`https://cnb.cool/echohaoran/mirror-finder/-/git/raw/main/assets/`；CNB 不可用时才回退到
清单中的官方上游地址。

`manifest.json` 记录来源和 SHA-256。同步资源后必须重新计算哈希并审阅脚本差异，不能
无条件覆盖后直接发布。

`installers/docker-install.sh` 不是 Docker 的 convenience script。它按 Docker stable
软件仓库流程安装完整的 Engine、CLI、containerd、Buildx、Compose，并交由系统包管理器
持续接收升级和安全更新；安装前会移除与官方软件包冲突的发行版包。

Codex/ChatGPT 桌面端单个平台包约 365–647 MB，不适合直接放进同时推送 GitHub、Gitee
的普通 Git 历史。清单已经保留 CNB 目标路径；在 CNB 配置大文件/对象存储后，可把文件
上传到对应 `desktop/` 路径，安装脚本会自动优先命中，未命中时回退官方地址。

npm、pip、Chocolatey、APT/DNF/Pacman、Homebrew bottles 和容器镜像属于持续更新的包
生态，不复制整个仓库；脚本继续测速并选择中国大陆镜像。Pi Agent 的入口 tarball 已固定
到本目录，但其 npm 依赖仍由用户配置的 npm 镜像解析。
