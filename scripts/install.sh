#!/usr/bin/env bash
# mirror-finder: interactive bootstrapper for macOS and common Linux systems.
set -Eeuo pipefail

APP_NAME="mirror-finder"
EGO_DMG_URL="https://cdn.ego.app/setup/macos/arm64/egolite.dmg"
BACKUP_DIR="${HOME}/.${APP_NAME}/backups/$(date +%Y%m%d-%H%M%S)"
OS_ID=""
OS_LIKE=""
PKG=""
CANDIDATE_NAMES=()
CANDIDATE_BASES=()
CANDIDATE_PROBES=()
RESULT_NAMES=()
RESULT_BASES=()

print_banner() {
  printf '\n'
  printf '  ███████  ██████ ██   ██  ██████          ██   ██  █████   ██████  ██████    █████  ███    ██\n'
  printf '  ██      ██      ██   ██ ██    ██         ██   ██ ██   ██ ██    ██ ██   ██  ██   ██ ████   ██\n'
  printf '  █████   ██      ███████ ██    ██         ███████ ███████ ██    ██ ██████   ███████ ██ ██  ██\n'
  printf '  ██      ██      ██   ██ ██    ██         ██   ██ ██   ██ ██    ██ ██   ██  ██   ██ ██  ██ ██\n'
  printf '  ███████  ██████ ██   ██  ██████   █████  ██   ██ ██   ██  ██████  ██   ██  ██   ██ ██   ████\n'
  printf '\n'
  printf '\n'
  printf '本脚本来自"https://github.com/echohaoran/mirror-finder"\n'
  printf '博客地址"https://echohaoran.top"\n'
  printf '由EchoHaoRan进行编写\n'
}
info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "需要命令：$1"; }
read_interactive() {
  local prompt="$1" variable="$2"
  if [[ -r /dev/tty ]]; then
    read -r -p "$prompt" "$variable" </dev/tty
  else
    read -r -p "$prompt" "$variable"
  fi
}
confirm() { local answer; read_interactive "$1 [y/N] " answer; [[ "$answer" =~ ^[Yy]$ ]]; }
sudo_cmd() { if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi; }
backup() {
  local source="$1" target
  [[ -e "$source" ]] || return 0
  target="$BACKUP_DIR${source}"
  mkdir -p "$(dirname "$target")"
  cp -a "$source" "$target"
  info "已备份 $source"
}
download_and_run() {
  local url="$1" tmp
  tmp="$(mktemp)"
  curl -fL --retry 3 --proto '=https' --tlsv1.2 "$url" -o "$tmp"
  bash "$tmp"
  rm -f "$tmp"
}

load_homebrew_path() {
  command -v brew >/dev/null 2>&1 && return 0
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

install_homebrew() {
  [[ "$OS_ID" == "macos" ]] || die "Homebrew 自动安装仅支持 macOS。"
  load_homebrew_path
  if command -v brew >/dev/null 2>&1; then
    info "Homebrew 已安装：$(brew --version | head -n 1)"
    return 0
  fi
  warn "将从 Homebrew 官方 GitHub 地址下载并执行安装器。"
  confirm "继续安装 Homebrew 吗？" || return 0
  download_and_run "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
  load_homebrew_path
  command -v brew >/dev/null 2>&1 || die "安装器已运行，但当前 Shell 仍找不到 brew；请按安装器提示配置 PATH。"
  info "Homebrew 安装成功。"
}

require_homebrew() {
  load_homebrew_path
  if ! command -v brew >/dev/null 2>&1; then
    warn "此操作需要 Homebrew。"
    install_homebrew
  fi
  command -v brew >/dev/null 2>&1 || die "未安装 Homebrew，无法继续。"
}

# Populates mirror candidates for one ecosystem.  The probe is an inexpensive
# public metadata endpoint, rather than a package download.
set_mirror_candidates() {
  local kind="$1" codename="${VERSION_CODENAME:-}" release="${VERSION_ID%%.*}" local_path=""
  CANDIDATE_NAMES=(); CANDIDATE_BASES=(); CANDIDATE_PROBES=()
  case "$kind" in
    apt)
      [[ "$OS_ID" == "ubuntu" ]] && local_path="ubuntu/dists/$codename/Release" || local_path="debian/dists/$codename/Release"
      for entry in \
        "清华大学|https://mirrors.tuna.tsinghua.edu.cn|$local_path" \
        "中国科学技术大学|https://mirrors.ustc.edu.cn|$local_path" \
        "阿里云|https://mirrors.aliyun.com|$local_path" \
        "腾讯云|https://mirrors.cloud.tencent.com|$local_path" \
        "华为云|https://repo.huaweicloud.com|$local_path" \
        "北京外国语大学|https://mirrors.bfsu.edu.cn|$local_path"; do
        CANDIDATE_NAMES+=("${entry%%|*}"); entry="${entry#*|}"
        CANDIDATE_BASES+=("${entry%%|*}"); CANDIDATE_PROBES+=("${entry#*|}")
      done
      ;;
    dnf)
      for entry in \
        "清华大学|https://mirrors.tuna.tsinghua.edu.cn/fedora|releases/$release/Everything/x86_64/os/repodata/repomd.xml" \
        "中国科学技术大学|https://mirrors.ustc.edu.cn/fedora|releases/$release/Everything/x86_64/os/repodata/repomd.xml" \
        "阿里云|https://mirrors.aliyun.com/fedora|releases/$release/Everything/x86_64/os/repodata/repomd.xml" \
        "腾讯云|https://mirrors.cloud.tencent.com/fedora|releases/$release/Everything/x86_64/os/repodata/repomd.xml" \
        "华为云|https://repo.huaweicloud.com/fedora|releases/$release/Everything/x86_64/os/repodata/repomd.xml"; do
        CANDIDATE_NAMES+=("${entry%%|*}"); entry="${entry#*|}"
        CANDIDATE_BASES+=("${entry%%|*}"); CANDIDATE_PROBES+=("${entry#*|}")
      done
      ;;
    pacman)
      for entry in \
        "清华大学|https://mirrors.tuna.tsinghua.edu.cn/archlinux|core/os/x86_64/core.db" \
        "中国科学技术大学|https://mirrors.ustc.edu.cn/archlinux|core/os/x86_64/core.db" \
        "上海交通大学|https://mirrors.sjtug.sjtu.edu.cn/archlinux|core/os/x86_64/core.db" \
        "腾讯云|https://mirrors.cloud.tencent.com/archlinux|core/os/x86_64/core.db" \
        "华为云|https://repo.huaweicloud.com/archlinux|core/os/x86_64/core.db"; do
        CANDIDATE_NAMES+=("${entry%%|*}"); entry="${entry#*|}"
        CANDIDATE_BASES+=("${entry%%|*}"); CANDIDATE_PROBES+=("${entry#*|}")
      done
      ;;
    brew)
      for entry in \
        "清华大学|https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles|api/formula.jws.json" \
        "中科大|https://mirrors.ustc.edu.cn/homebrew-bottles|api/formula.jws.json" \
        "阿里云|https://mirrors.aliyun.com/homebrew-bottles|api/formula.jws.json" \
        "腾讯云|https://mirrors.cloud.tencent.com/homebrew-bottles|api/formula.jws.json" \
        "华为云|https://repo.huaweicloud.com/homebrew-bottles|api/formula.jws.json"; do
        CANDIDATE_NAMES+=("${entry%%|*}"); entry="${entry#*|}"
        CANDIDATE_BASES+=("${entry%%|*}"); CANDIDATE_PROBES+=("${entry#*|}")
      done
      ;;
    npm)
      for entry in \
        "npmmirror|https://registry.npmmirror.com|-/ping" \
        "腾讯云|https://mirrors.cloud.tencent.com/npm|-/ping" \
        "阿里云|https://mirrors.aliyun.com/npm|-/ping" \
        "华为云|https://repo.huaweicloud.com/repository/npm|-/ping" \
        "中科大|https://npmreg.proxy.ustclug.org|-/ping"; do
        CANDIDATE_NAMES+=("${entry%%|*}"); entry="${entry#*|}"
        CANDIDATE_BASES+=("${entry%%|*}"); CANDIDATE_PROBES+=("${entry#*|}")
      done
      ;;
    pip)
      for entry in \
        "清华大学|https://pypi.tuna.tsinghua.edu.cn/simple|" \
        "中国科学技术大学|https://pypi.mirrors.ustc.edu.cn/simple|" \
        "阿里云|https://mirrors.aliyun.com/pypi/simple|" \
        "腾讯云|https://mirrors.cloud.tencent.com/pypi/simple|" \
        "华为云|https://repo.huaweicloud.com/repository/pypi/simple|"; do
        CANDIDATE_NAMES+=("${entry%%|*}"); entry="${entry#*|}"
        CANDIDATE_BASES+=("${entry%%|*}"); CANDIDATE_PROBES+=("${entry#*|}")
      done
      ;;
    docker)
      for entry in \
        "DaoCloud|https://docker.m.daocloud.io|v2/" \
        "1Panel|https://docker.1panel.live|v2/" \
        "1MS|https://docker.1ms.run|v2/" \
        "VVVV Proxy|https://proxy.vvvv.ee|v2/" \
        "Docker Proxy|https://dockerproxy.net|v2/" \
        "Docker Proxy Link|https://dockerproxy.link|v2/" \
        "简行镜像|https://docker.jiaxin.site|v2/" \
        "轩辕镜像|https://docker.xuanyuan.me|v2/" \
        "容器镜像管理中心|https://registry.cyou|v2/" \
        "HubFast|https://free.hubfast.cn|v2/"; do
        CANDIDATE_NAMES+=("${entry%%|*}"); entry="${entry#*|}"
        CANDIDATE_BASES+=("${entry%%|*}"); CANDIDATE_PROBES+=("${entry#*|}")
      done
      ;;
    *) die "未知镜像类型：$kind" ;;
  esac
}

choose_fast_mirror() {
  local kind="$1" i code elapsed row selected tmp
  set_mirror_candidates "$kind"
  tmp="$(mktemp)"
  info "正在测试 ${#CANDIDATE_NAMES[@]} 个中国大陆镜像的连通性与延迟…"
  for i in "${!CANDIDATE_NAMES[@]}"; do
    row="$(curl -sSL -o /dev/null -w '%{http_code} %{time_total}' --connect-timeout 3 --max-time 8 "${CANDIDATE_BASES[$i]}/${CANDIDATE_PROBES[$i]}" 2>/dev/null || true)"
    code="${row%% *}"; elapsed="${row#* }"
    [[ "$code" =~ ^(2|3|401) ]] && printf '%s\t%s\t%s\n' "$elapsed" "${CANDIDATE_NAMES[$i]}" "${CANDIDATE_BASES[$i]}" >>"$tmp"
  done
  [[ -s "$tmp" ]] || { rm -f "$tmp"; warn "没有可访问的候选镜像，未修改配置。"; return 1; }
  RESULT_NAMES=(); RESULT_BASES=()
  printf '\n最快的镜像（最多 5 个）：\n'
  while IFS=$'\t' read -r elapsed name base; do
    [[ ${#RESULT_BASES[@]} -lt 5 ]] || break
    RESULT_NAMES+=("$name"); RESULT_BASES+=("$base")
    printf '  %d) %-16s %7.3fs  %s\n' "${#RESULT_BASES[@]}" "$name" "$elapsed" "$base"
  done < <(sort -t $'\t' -k1,1n "$tmp")
  read_interactive "请选择镜像编号（0 取消）: " selected
  [[ "$selected" =~ ^[1-5]$ && "$selected" -le "${#RESULT_BASES[@]}" ]] || { rm -f "$tmp"; warn "已取消。"; return 1; }
  SELECTED_MIRROR="${RESULT_BASES[$((selected - 1))]}"
  rm -f "$tmp"
  info "已选择：${RESULT_NAMES[$((selected - 1))]}（${SELECTED_MIRROR}）"
}

detect_system() {
  case "$(uname -s)" in
    Darwin) OS_ID="macos"; PKG="brew"; load_homebrew_path ;;
    Linux)
      [[ -r /etc/os-release ]] || die "无法识别 Linux 发行版（缺少 /etc/os-release）。"
      # shellcheck disable=SC1091
      . /etc/os-release
      OS_ID="$(printf '%s' "$ID" | tr '[:upper:]' '[:lower:]')"; OS_LIKE="${ID_LIKE:-}"
      if command -v apt-get >/dev/null; then PKG="apt"
      elif command -v dnf >/dev/null; then PKG="dnf"
      elif command -v yum >/dev/null; then PKG="yum"
      elif command -v pacman >/dev/null; then PKG="pacman"
      else die "未找到支持的包管理器（apt、dnf、yum、pacman、brew）。"; fi
      ;;
    *) die "仅支持 macOS 和 Linux；Windows 请在 WSL 中运行。" ;;
  esac
  info "检测到：${OS_ID}（包管理器：${PKG}）"
}

install_packages() {
  [[ "$PKG" == "brew" ]] && require_homebrew
  case "$PKG" in
    apt) sudo_cmd apt-get update; sudo_cmd apt-get install -y "$@" ;;
    dnf) sudo_cmd dnf install -y "$@" ;;
    yum) sudo_cmd yum install -y "$@" ;;
    pacman) sudo_cmd pacman -Sy --needed --noconfirm "$@" ;;
    brew) brew install "$@" ;;
  esac
}

configure_apt_mirror() {
  local codename base
  codename="${VERSION_CODENAME:-$(. /etc/os-release; echo "${UBUNTU_CODENAME:-}")}" 
  [[ -n "$codename" ]] || die "无法取得发行版代号。"
  choose_fast_mirror apt || return 0
  base="$SELECTED_MIRROR"
  confirm "确认将 APT 源切换至 ${base} 吗？" || return 0
  backup /etc/apt/sources.list
  backup /etc/apt/sources.list.d
  if [[ "$OS_ID" == "ubuntu" ]]; then
    sudo_cmd mkdir -p /etc/apt/sources.list.d
    sudo_cmd tee /etc/apt/sources.list >/dev/null <<EOF
deb $base/ubuntu/ $codename main restricted universe multiverse
deb $base/ubuntu/ $codename-updates main restricted universe multiverse
deb $base/ubuntu/ $codename-backports main restricted universe multiverse
deb $base/ubuntu/ $codename-security main restricted universe multiverse
EOF
  elif [[ "$OS_ID" == "debian" ]]; then
    sudo_cmd tee /etc/apt/sources.list >/dev/null <<EOF
deb $base/debian/ $codename main contrib non-free non-free-firmware
deb $base/debian/ $codename-updates main contrib non-free non-free-firmware
deb $base/debian-security $codename-security main contrib non-free non-free-firmware
EOF
  else die "目前仅为 Debian/Ubuntu 自动生成 APT 源；当前为 $OS_ID。"; fi
  sudo_cmd rm -f /etc/apt/sources.list.d/ubuntu.sources
  sudo_cmd apt-get update
}

configure_dnf_mirror() {
  local release="${VERSION_ID%%.*}" base=""
  case "$OS_ID" in
    fedora) choose_fast_mirror dnf || return 0; base="$SELECTED_MIRROR"; confirm "确认将 DNF 源切换至 ${base} 吗？" || return 0 ;;
    rocky|almalinux) die "当前发行版尚未提供可自动测速的镜像模板。" ;;
    *) die "当前发行版没有内置 DNF/YUM 镜像模板，请保留官方源或自行修改仓库文件。" ;;
  esac
  backup /etc/yum.repos.d
  sudo_cmd mkdir -p /etc/yum.repos.d
  if [[ "$OS_ID" == "fedora" ]]; then
    sudo_cmd tee /etc/yum.repos.d/mirror-finder.repo >/dev/null <<EOF
[mirror-finder-fedora]
name=Fedora - $release - Everything
baseurl=$base/releases/\$releasever/Everything/\$basearch/os/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch
[mirror-finder-updates]
name=Fedora - $release - Updates
baseurl=$base/updates/\$releasever/Everything/\$basearch/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch
EOF
    sudo_cmd dnf install -y dnf-plugins-core
    sudo_cmd dnf config-manager --set-disabled fedora updates || warn "未能禁用原 Fedora 仓库；请检查 dnf repolist。"
  else
    warn "已备份仓库配置。请根据 $OS_ID 的版本和仓库角色，在 /etc/yum.repos.d 中选择 TUNA 对应模板。"
    return 0
  fi
  sudo_cmd "$PKG" clean all
  sudo_cmd "$PKG" makecache
}

configure_pacman_mirror() {
  local base
  choose_fast_mirror pacman || return 0
  base="$SELECTED_MIRROR"
  confirm "确认将 Pacman 源切换至 ${base} 吗？" || return 0
  backup /etc/pacman.d/mirrorlist
  printf 'Server = %s/$repo/os/$arch\n' "$base" | sudo_cmd tee /etc/pacman.d/mirrorlist >/dev/null
  sudo_cmd pacman -Syy
}

configure_brew_mirror() {
  local profile="${HOME}/.zprofile" base
  choose_fast_mirror brew || return 0
  base="$SELECTED_MIRROR"
  confirm "确认将 Homebrew 源切换至 ${base} 吗？" || return 0
  backup "$profile"
  touch "$profile"
  sed -i.bak '/# mirror-finder Homebrew mirror/,+2d' "$profile"
  cat >>"$profile" <<'EOF'
# mirror-finder Homebrew mirror
export HOMEBREW_API_DOMAIN="MIRROR_FINDER_API_DOMAIN"
export HOMEBREW_BOTTLE_DOMAIN="MIRROR_FINDER_BOTTLE_DOMAIN"
EOF
  sed -i.bak "s|MIRROR_FINDER_API_DOMAIN|$base/api|; s|MIRROR_FINDER_BOTTLE_DOMAIN|$base|" "$profile"
  info "Homebrew 镜像已写入 ~/.zprofile；请执行 source ~/.zprofile 或重开终端。"
}

configure_package_mirror() {
  warn "将先测速并选择镜像；写入系统配置前才会进行确认。备份位置：$BACKUP_DIR"
  case "$PKG" in
    apt) configure_apt_mirror ;;
    dnf|yum) configure_dnf_mirror ;;
    pacman) configure_pacman_mirror ;;
    brew) configure_brew_mirror ;;
  esac
}

install_node() {
  if [[ "$PKG" == "brew" ]]; then install_packages node; else install_packages nodejs npm; fi
  command -v npm >/dev/null && npm --version
  command -v npx >/dev/null || warn "当前 npm 未提供 npx，请升级 npm。"
}
install_ffmpeg() { install_packages ffmpeg; ffmpeg -version | head -n 1; }

install_ego_lite() {
  [[ "$OS_ID" == "macos" ]] || die "Ego Lite 自动下载仅支持 macOS。"
  [[ "$(uname -m)" == "arm64" ]] || die "Ego Lite 下载地址仅适用于 Apple Silicon（arm64）Mac。"
  local download_dir="${HOME}/Downloads" target partial
  target="${download_dir}/egolite.dmg"
  partial="${target}.part"
  mkdir -p "$download_dir"
  info "将下载 Ego Lite ARM64 安装镜像到：$target"
  warn "Ego Lite 可能复用浏览器登录状态，请仅授予必要账号权限。"
  if [[ -e "$target" ]]; then
    confirm "目标文件已存在，是否覆盖？" || return 0
  else
    confirm "继续下载 Ego Lite 吗？" || return 0
  fi
  curl --fail --location --show-error --progress-bar "$EGO_DMG_URL" --output "$partial"
  mv -f "$partial" "$target"
  info "Ego Lite 已下载：$target"
  printf '请打开 DMG 完成应用安装，然后按 Ego Lite 文档安装 ego-browser Skill。\n'
}

check_environment() {
  local machine_arch processor_name tool
  load_homebrew_path
  machine_arch="$(uname -m)"
  case "$machine_arch" in
    arm64) processor_name="Apple Silicon/ARM64" ;;
    x86_64) processor_name="Intel/AMD64" ;;
    *) processor_name="未知架构" ;;
  esac
  printf '\n系统信息：\n  系统：%s\n  处理器：%s（%s）\n\n组件状态：\n' "$(uname -s)" "$processor_name" "$machine_arch"
  for tool in brew node npm ffmpeg ego-browser; do
    if command -v "$tool" >/dev/null 2>&1; then
      printf '  ✅ %-12s %s\n' "$tool" "$(command -v "$tool")"
    else
      printf '  ❌ %-12s 未安装或不在 PATH 中\n' "$tool"
    fi
  done
  printf '\n'
}
configure_npm() {
  choose_fast_mirror npm || return 0
  confirm "确认写入 ${SELECTED_MIRROR} 为 npm/npx 源吗？" || return 0
  npm config set registry "$SELECTED_MIRROR"
  npm config set disturl "https://npmmirror.com/mirrors/node"
  info "npm/npx 已使用 ${SELECTED_MIRROR}。"
}
install_python() {
  case "$PKG" in
    apt) install_packages python3 python3-pip python3-venv ;;
    dnf|yum) install_packages python3 python3-pip ;;
    pacman) install_packages python python-pip ;;
    brew) install_packages python ;;
  esac
  python3 --version
}
configure_pip() {
  choose_fast_mirror pip || return 0
  confirm "确认写入 ${SELECTED_MIRROR} 为 pip 源吗？" || return 0
  python3 -m pip config set global.index-url "$SELECTED_MIRROR"
  info "pip 已使用 ${SELECTED_MIRROR}。"
}

install_docker() {
  if [[ "$OS_ID" == "macos" ]]; then
    brew install --cask docker
    info "Docker Desktop（含 Docker Compose）已安装；首次请从“应用程序”启动并接受许可。"
  else
    warn "将使用 Docker 官方 convenience script（适用于开发环境，生产环境请使用 Docker 官方仓库步骤）。"
    confirm "继续安装 Docker Engine 吗？" || return 0
    download_and_run "https://get.docker.com"
    if ! docker compose version >/dev/null 2>&1; then
      info "正在补装 Docker Compose 插件…"
      case "$PKG" in
        apt|dnf|yum) install_packages docker-compose-plugin ;;
        pacman) install_packages docker-compose ;;
      esac
    fi
    sudo_cmd usermod -aG docker "$USER" || true
    info "已将 $USER 加入 docker 组；重新登录后生效。"
  fi
  docker compose version || warn "未检测到 Docker Compose；请重开终端后执行 docker compose version 检查。"
}

configure_docker_mirror() {
  local mirror config
  choose_fast_mirror docker || return 0
  mirror="$SELECTED_MIRROR"
  confirm "确认写入 ${mirror} 为 Docker registry mirror 吗？" || return 0
  if [[ "$OS_ID" == "macos" ]]; then
    info "Docker Desktop：打开 Settings → Docker Engine，将下列内容合并并点击 Apply："
    printf '{\n  "registry-mirrors": ["%s"]\n}\n' "$mirror"
    return 0
  fi
  config=/etc/docker/daemon.json
  backup "$config"
  sudo_cmd mkdir -p /etc/docker
  printf '{\n  "registry-mirrors": ["%s"]\n}\n' "$mirror" | sudo_cmd tee "$config" >/dev/null
  sudo_cmd systemctl daemon-reload
  sudo_cmd systemctl restart docker
}

install_podman() {
  case "$PKG" in
    apt|dnf|yum|pacman) install_packages podman podman-compose ;;
    brew)
      brew install podman podman-compose
      if ! podman machine inspect >/dev/null 2>&1; then podman machine init; fi
      podman machine start || true
      ;;
  esac
  podman --version
  podman compose version || podman-compose --version || warn "未检测到 Podman Compose provider。"
}

configure_podman_mirror() {
  local mirror host config vm_backup
  choose_fast_mirror docker || return 0
  mirror="$SELECTED_MIRROR"
  host="${mirror#https://}"; host="${host%/}"
  confirm "确认写入 ${mirror} 为 Podman 的 Docker Hub 镜像源吗？" || return 0
  if [[ "$OS_ID" == "macos" ]]; then
    need podman
    podman machine inspect >/dev/null 2>&1 || die "请先安装并启动 Podman machine。"
    vm_backup="/etc/containers/registries.conf.d/99-mirror-finder-dockerhub.conf.bak-$(date +%Y%m%d-%H%M%S)"
    printf '[[registry]]\nprefix = "docker.io"\nlocation = "docker.io"\n\n[[registry.mirror]]\nlocation = "%s"\n' "$host" \
      | podman machine ssh "sudo mkdir -p /etc/containers/registries.conf.d; test ! -e /etc/containers/registries.conf.d/99-mirror-finder-dockerhub.conf || sudo cp /etc/containers/registries.conf.d/99-mirror-finder-dockerhub.conf $vm_backup; sudo tee /etc/containers/registries.conf.d/99-mirror-finder-dockerhub.conf >/dev/null"
    info "已配置 Podman machine；原配置（如存在）备份在 machine 的 $vm_backup。"
  else
    config=/etc/containers/registries.conf.d/99-mirror-finder-dockerhub.conf
    backup "$config"
    sudo_cmd mkdir -p /etc/containers/registries.conf.d
    sudo_cmd tee "$config" >/dev/null <<EOF
[[registry]]
prefix = "docker.io"
location = "docker.io"

[[registry.mirror]]
location = "$host"
EOF
    info "Podman 已配置 Docker Hub 镜像源；后续 podman pull 会自动读取。"
  fi
}

default_interface() {
  if [[ "$OS_ID" == "macos" ]]; then
    route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}'
  else
    ip route show default 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i == "dev") {print $(i+1); exit}}'
  fi
}

valid_ipv4() {
  local ip="$1" octet count=0
  [[ "$ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || return 1
  local old_ifs="$IFS"; IFS=.
  for octet in $ip; do
    [[ "$octet" -le 255 ]] || { IFS="$old_ifs"; return 1; }
    count=$((count + 1))
  done
  IFS="$old_ifs"
  [[ "$count" -eq 4 ]]
}

mask_to_prefix() {
  case "$1" in
    255.255.255.255) echo 32 ;; 255.255.255.254) echo 31 ;; 255.255.255.252) echo 30 ;;
    255.255.255.248) echo 29 ;; 255.255.255.240) echo 28 ;; 255.255.255.224) echo 27 ;;
    255.255.255.192) echo 26 ;; 255.255.255.128) echo 25 ;; 255.255.255.0) echo 24 ;;
    255.255.254.0) echo 23 ;; 255.255.252.0) echo 22 ;; 255.255.248.0) echo 21 ;;
    255.255.240.0) echo 20 ;; 255.255.224.0) echo 19 ;; 255.255.192.0) echo 18 ;;
    255.255.128.0) echo 17 ;; 255.255.0.0) echo 16 ;; 255.254.0.0) echo 15 ;;
    255.252.0.0) echo 14 ;; 255.248.0.0) echo 13 ;; 255.240.0.0) echo 12 ;;
    255.224.0.0) echo 11 ;; 255.192.0.0) echo 10 ;; 255.128.0.0) echo 9 ;;
    255.0.0.0) echo 8 ;; 254.0.0.0) echo 7 ;; 252.0.0.0) echo 6 ;;
    248.0.0.0) echo 5 ;; 240.0.0.0) echo 4 ;; 224.0.0.0) echo 3 ;;
    192.0.0.0) echo 2 ;; 128.0.0.0) echo 1 ;; 0.0.0.0) echo 0 ;;
    *) return 1 ;;
  esac
}

macos_network_service() {
  local iface="$1"
  networksetup -listallhardwareports | awk -v dev="$iface" '
    /^Hardware Port: / {sub(/^Hardware Port: /, ""); port=$0}
    /^Device: / && $2 == dev {print port; exit}'
}

detect_network_backend() {
  NETWORK_IFACE="$(default_interface)"
  [[ -n "$NETWORK_IFACE" ]] || die "未找到默认路由对应的网卡。"
  if [[ "$OS_ID" == "macos" ]]; then
    NETWORK_BACKEND="macos"
    NETWORK_SERVICE="$(macos_network_service "$NETWORK_IFACE")"
    [[ -n "$NETWORK_SERVICE" ]] || die "无法将网卡 $NETWORK_IFACE 映射到 macOS 网络服务。"
  elif command -v nmcli >/dev/null 2>&1 && nmcli -t -f GENERAL.CONNECTION device show "$NETWORK_IFACE" 2>/dev/null | grep -qv ':--$'; then
    NETWORK_BACKEND="networkmanager"
    NETWORK_SERVICE="$(nmcli -g GENERAL.CONNECTION device show "$NETWORK_IFACE")"
  elif command -v netplan >/dev/null 2>&1 && [[ -d /etc/netplan ]]; then
    NETWORK_BACKEND="netplan"
    NETWORK_SERVICE="/etc/netplan/99-mirror-finder-${NETWORK_IFACE}.yaml"
  elif [[ -d /etc/systemd/network ]] && systemctl is-active --quiet systemd-networkd; then
    NETWORK_BACKEND="networkd"
    NETWORK_SERVICE="/etc/systemd/network/05-mirror-finder-${NETWORK_IFACE}.network"
  elif [[ -f "/etc/sysconfig/network-scripts/ifcfg-${NETWORK_IFACE}" ]]; then
    NETWORK_BACKEND="ifcfg"
    NETWORK_SERVICE="/etc/sysconfig/network-scripts/ifcfg-${NETWORK_IFACE}"
  else
    die "无法识别 $NETWORK_IFACE 的网络配置后端；支持 NetworkManager、Netplan、systemd-networkd、ifcfg 与 macOS。"
  fi
  info "网络：${NETWORK_IFACE}；配置后端：${NETWORK_BACKEND}；目标：${NETWORK_SERVICE}"
}

apply_static_ip() {
  local ip="$1" mask="$2" gateway="$3" prefix renderer
  prefix="$(mask_to_prefix "$mask")" || die "掩码必须是连续的 IPv4 子网掩码。"
  case "$NETWORK_BACKEND" in
    macos)
      networksetup -setmanual "$NETWORK_SERVICE" "$ip" "$mask" "$gateway"
      sudo_cmd ifconfig "$NETWORK_IFACE" down
      sudo_cmd ifconfig "$NETWORK_IFACE" up
      ;;
    networkmanager)
      nmcli connection modify "$NETWORK_SERVICE" ipv4.method manual ipv4.addresses "$ip/$prefix" ipv4.gateway "$gateway"
      nmcli connection up "$NETWORK_SERVICE"
      ;;
    netplan)
      backup /etc/netplan
      renderer="$(grep -RhsE '^[[:space:]]*renderer:' /etc/netplan 2>/dev/null | head -n1 | awk '{print $2}')"
      renderer="${renderer:-networkd}"
      sudo_cmd tee "$NETWORK_SERVICE" >/dev/null <<EOF
network:
  version: 2
  renderer: $renderer
  ethernets:
    $NETWORK_IFACE:
      dhcp4: false
      addresses: [$ip/$prefix]
      routes:
        - to: default
          via: $gateway
EOF
      sudo_cmd netplan apply
      ;;
    networkd)
      backup /etc/systemd/network
      sudo_cmd tee "$NETWORK_SERVICE" >/dev/null <<EOF
[Match]
Name=$NETWORK_IFACE

[Network]
DHCP=no
Address=$ip/$prefix
Gateway=$gateway
EOF
      sudo_cmd systemctl restart systemd-networkd
      ;;
    ifcfg)
      backup "$NETWORK_SERVICE"
      sudo_cmd sed -i '/^\(BOOTPROTO\|IPADDR\|NETMASK\|PREFIX\|GATEWAY\)=/d' "$NETWORK_SERVICE"
      sudo_cmd tee -a "$NETWORK_SERVICE" >/dev/null <<EOF
BOOTPROTO=none
IPADDR=$ip
NETMASK=$mask
GATEWAY=$gateway
ONBOOT=yes
EOF
      if systemctl is-active --quiet NetworkManager; then sudo_cmd systemctl restart NetworkManager; else sudo_cmd systemctl restart network; fi
      ;;
  esac
}

configure_static_ip() {
  local ip mask gateway
  detect_network_backend
  read_interactive "固定 IPv4 地址: " ip
  read_interactive "子网掩码（例如 255.255.255.0）: " mask
  read_interactive "默认网关: " gateway
  valid_ipv4 "$ip" || die "IP 地址格式无效。"
  valid_ipv4 "$gateway" || die "网关地址格式无效。"
  mask_to_prefix "$mask" >/dev/null || die "子网掩码格式无效。"
  warn "应用后将重启 ${NETWORK_IFACE}，当前网络连接可能中断。"
  [[ -n "${SSH_CONNECTION:-}" ]] && warn "检测到 SSH 会话；继续操作可能使当前会话断开。"
  confirm "确认配置 ${ip} / ${mask}，网关 ${gateway} 吗？" || return 0
  apply_static_ip "$ip" "$mask" "$gateway"
  info "固定 IP 已配置并已重新应用网络。"
}

restore_dhcp() {
  detect_network_backend
  warn "将恢复 $NETWORK_IFACE 的 DHCP，并重新应用网络。"
  [[ -n "${SSH_CONNECTION:-}" ]] && warn "检测到 SSH 会话；继续操作可能使当前会话断开。"
  confirm "确认恢复 DHCP 吗？" || return 0
  case "$NETWORK_BACKEND" in
    macos) networksetup -setdhcp "$NETWORK_SERVICE"; sudo_cmd ifconfig "$NETWORK_IFACE" down; sudo_cmd ifconfig "$NETWORK_IFACE" up ;;
    networkmanager) nmcli connection modify "$NETWORK_SERVICE" ipv4.method auto ipv4.addresses "" ipv4.gateway ""; nmcli connection up "$NETWORK_SERVICE" ;;
    netplan) backup "$NETWORK_SERVICE"; sudo_cmd rm -f "$NETWORK_SERVICE"; sudo_cmd netplan apply ;;
    networkd) backup "$NETWORK_SERVICE"; sudo_cmd rm -f "$NETWORK_SERVICE"; sudo_cmd systemctl restart systemd-networkd ;;
    ifcfg)
      backup "$NETWORK_SERVICE"
      sudo_cmd sed -i '/^\(BOOTPROTO\|IPADDR\|NETMASK\|PREFIX\|GATEWAY\)=/d' "$NETWORK_SERVICE"
      printf 'BOOTPROTO=dhcp\nONBOOT=yes\n' | sudo_cmd tee -a "$NETWORK_SERVICE" >/dev/null
      if systemctl is-active --quiet NetworkManager; then sudo_cmd systemctl restart NetworkManager; else sudo_cmd systemctl restart network; fi
      ;;
  esac
  info "DHCP 已恢复并已重新应用网络。"
}

install_opencode() { download_and_run "https://opencode.ai/install"; command -v opencode >/dev/null && opencode --version || warn "安装完成后请重开终端以加载 PATH。"; }
install_hermes() { download_and_run "https://hermes-agent.nousresearch.com/install.sh"; command -v hermes >/dev/null && hermes --version || warn "安装完成后请重开终端以加载 PATH。"; }

install_flclash() {
  local arch asset os_pattern url tmp
  case "$(uname -m)" in x86_64|amd64) arch="amd64" ;; arm64|aarch64) arch="arm64" ;; *) die "FlClash 不支持的架构：$(uname -m)" ;; esac
  need curl
  [[ "$OS_ID" == "macos" ]] && os_pattern="macos" || os_pattern="linux"
  asset="$(curl -fsSL https://api.github.com/repos/chen08209/FlClash/releases/latest | grep -o 'https://[^" ]*' | grep -E "FlClash-[^/]*-${os_pattern}-${arch}.*" | head -n1 || true)"
  if [[ -z "$asset" ]]; then
    warn "未找到当前平台的自动安装包，请访问：https://github.com/chen08209/FlClash/releases/latest"
    return 0
  fi
  url="$asset"; tmp="$(mktemp -d)"
  curl -fL --retry 3 "$url" -o "$tmp/FlClash${url##*.}"
  case "$url" in
    *.deb) sudo_cmd dpkg -i "$tmp"/* || sudo_cmd apt-get -f install -y ;;
    *.rpm) sudo_cmd rpm -Uvh "$tmp"/* ;;
    *.AppImage) install -Dm755 "$tmp"/* "${HOME}/.local/bin/FlClash"; info "已安装到 ~/.local/bin/FlClash" ;;
    *.dmg) hdiutil attach "$tmp"/* -nobrowse; sudo_cmd cp -R /Volumes/FlClash/FlClash.app /Applications/; hdiutil detach /Volumes/FlClash ;;
    *) warn "下载完成：${tmp}；请手动安装。"; return 0 ;;
  esac
  rm -rf "$tmp"
}

run_item() {
  case "$1" in
    1) configure_package_mirror ;; 2) install_node ;; 3) configure_npm ;; 4) install_python ;; 5) configure_pip ;;
    6) install_docker ;; 7) configure_docker_mirror ;; 8) install_podman ;; 9) configure_podman_mirror ;;
    10) install_opencode ;; 11) install_hermes ;; 12) install_flclash ;;
    13) configure_static_ip ;; 14) restore_dhcp ;;
    15) install_homebrew ;; 16) install_ffmpeg ;; 17) install_ego_lite ;; 18) check_environment ;;
    *) die "无效选项：$1" ;;
  esac
}

main() {
  print_banner
  need curl; detect_system
  if [[ $# -gt 0 ]]; then run_item "$1"; return; fi
  while true; do
    cat <<'EOF'

1) 更换包管理器源       2) 安装 Node.js/npm/npx
3) 更换 npm/npx 源      4) 安装 Python（含 Compose）
5) 更换 Python(pip) 源  6) 安装 Docker
7) 更换 Docker 源       8) 安装 Podman（含 Compose）
9) 更换 Podman 源      10) 安装 OpenCode
11) 安装 Hermes Agent  12) 安装 FlClash
13) 配置固定 IP        14) 恢复 DHCP
15) 安装 Homebrew      16) 安装 FFmpeg
17) 下载 Ego Lite      18) 检查媒体工具环境
0) 退出
EOF
    read_interactive "请选择：" choice
    [[ "$choice" == "0" ]] && break
    run_item "$choice"
  done
}
main "$@"
