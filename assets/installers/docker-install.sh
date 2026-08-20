#!/usr/bin/env sh
# Install a complete, production-maintainable Docker Engine from package repositories.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "请以 root 运行此安装器。" >&2; exit 1; }
[ -r /etc/os-release ] || { echo "缺少 /etc/os-release，无法识别发行版。" >&2; exit 1; }
. /etc/os-release

install_apt() {
  vendor="$1"
  codename="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
  [ -n "$codename" ] || { echo "无法识别发行版代号。" >&2; exit 1; }
  for package in docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc; do
    dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'install ok installed' && apt-get remove -y "$package" || true
  done
  apt-get update
  apt-get install -y ca-certificates curl
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/${vendor}/gpg" -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  arch="$(dpkg --print-architecture)"
  cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/${vendor}
Suites: ${codename}
Components: stable
Architectures: ${arch}
Signed-By: /etc/apt/keyrings/docker.asc
EOF
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
}

install_rpm() {
  vendor="$1"
  manager="dnf"; command -v dnf >/dev/null 2>&1 || manager="yum"
  "$manager" remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine podman-docker runc 2>/dev/null || true
  "$manager" install -y dnf-plugins-core ca-certificates curl
  repo="https://download.docker.com/linux/${vendor}/docker-ce.repo"
  "$manager" config-manager addrepo --from-repofile "$repo" 2>/dev/null || "$manager" config-manager --add-repo "$repo"
  "$manager" install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

case "${ID}" in
  ubuntu) install_apt ubuntu ;;
  debian) install_apt debian ;;
  fedora) install_rpm fedora ;;
  rhel) install_rpm rhel ;;
  centos|rocky|almalinux) install_rpm centos ;;
  arch) pacman -Sy --needed --noconfirm docker containerd docker-buildx docker-compose ;;
  *) echo "暂不支持生产型 Docker Engine 安装：${ID}" >&2; exit 1 ;;
esac

if command -v systemctl >/dev/null 2>&1; then
  systemctl enable --now docker
else
  service docker start 2>/dev/null || true
fi
docker --version
docker buildx version
docker compose version
