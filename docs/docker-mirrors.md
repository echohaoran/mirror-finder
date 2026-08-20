# Docker 镜像候选池

`scripts/install.sh` 与 `scripts/install.ps1` 对每个候选的 `/v2/` 接口执行 HTTPS 连通性与延迟测试，
只展示返回成功、重定向或 Registry 标准 `401` 响应的地址；因此失效源不会被提供
给用户选择。

当前候选来自 2026 年 8 月查阅的资料快照：

- DaoCloud：`https://docker.m.daocloud.io`
- 1Panel：`https://docker.1panel.live`
- 1MS：`https://docker.1ms.run`
- VVVV Proxy：`https://proxy.vvvv.ee`
- Docker Proxy：`https://dockerproxy.net`、`https://dockerproxy.link`
- 简行镜像、轩辕镜像、容器镜像管理中心与 HubFast。

腾讯云镜像地址仅支持其内网访问，厚浪镜像要求注册令牌；两者不进入通用候选池。
阿里云的个人专属地址同样不适用于无需输入的公共脚本。社区镜像状态变化很快，测速
只说明 Registry 接口当下可访问，不保证所有镜像仓库均可拉取。

Docker 写入 `/etc/docker/daemon.json` 的 `registry-mirrors`，Podman 写入
`/etc/containers/registries.conf.d/99-mirror-finder-dockerhub.conf`，将
`docker.io` 映射为选择的镜像。macOS 的 Podman 配置会写入 Podman machine 内的
同一路径。Windows 的 Docker 与 Podman 均运行在用户选择的 WSL 发行版中，配置写入
该发行版内的上述 Linux 路径。

来源：

- [腾讯云开发者文章](https://cloud.tencent.com/developer/article/2485043)
- [dongyubin/DockerHub 可用镜像汇总](https://github.com/dongyubin/DockerHub)
- [知乎文章](https://zhuanlan.zhihu.com/p/2053445738546435250)
