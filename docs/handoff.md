# Handoff

## 2026-08-20 categorized menus

- Bash and PowerShell menus show one option per line.
- Items are grouped into system environment, HARNESS tools, package managers, and networking without changing item numbers.

## 2026-08-20 MiMoCode

- Pi Agent remains menu item 19 at the current 0.73.1 release.
- Menu item 24 installs official Xiaomi MiMoCode 0.1.13 from a CNB-first npm entry tarball.
- npm resolves only the current platform optional binary through the configured registry.

## 2026-08-20 Claude Code CLI

- Menu item 23 installs Claude Code CLI from mirrored native installers using the stable channel.
- Windows ensures Git is present first; both environment checks include `claude`.
- Platform binaries remain dynamically resolved and checksum-verified by Anthropic's installer.

## 2026-08-20 Git installer

- Menu item 22 installs Git through the native package manager on Bash platforms and Chocolatey on Windows.
- Environment checks now include Git.

## 2026-08-20 CNB-first asset layer

- Added `assets/manifest.json`, seven mirrored bootstrap scripts, and Pi Agent 0.73.1.
- Bash and PowerShell prefer CNB assets and fall back to official upstream URLs.
- Menu items 19–21 install Pi Agent, Codex CLI, and the Codex/ChatGPT desktop app.
- Desktop packages are 365–647 MB each; CNB target paths are reserved pending large-object storage.
- Package ecosystems remain on measured mainland-China mirrors rather than being vendored into Git.
- Docker no longer uses `get.docker.com`; the mirrored project installer configures Docker's stable package repository and installs Engine, CLI, containerd, Buildx, Compose, and rootless extras where available.

## Current state

The interactive installer is implemented at `scripts/install.sh`. Mirror actions
now test China-mainland candidates, display up to five reachable results in
latency order, then require selection and confirmation before configuration.

## Decisions

- Bash is the single runtime to keep bootstrap requirements minimal.
- Source-changing steps are opt-in and backed up before modification.
- Native Windows is not supported in this release; WSL is supported as Linux.
- Fedora uses separate mirror repository IDs, then disables the stock `fedora`
  and `updates` IDs to avoid duplicate repositories.
- Candidate health probes are metadata requests with an 8-second cap per mirror.
- The npm probe path was smoke-tested on macOS with cancellation before any
  configuration write.
- Docker candidates were refreshed from the three user-supplied articles. The
  script excludes sources requiring private-network access, a token, or a
  per-user address.
- Docker probe smoke test completed with ten candidates: it ranked and displayed
  the fastest five, then exited at user cancellation without a configuration write.
- Static IPv4 and DHCP-recovery menu paths now detect the default route and
  support macOS, NetworkManager, Netplan, systemd-networkd, and ifcfg.
- Docker install now verifies Docker Compose; Podman install and Podman mirror
  configuration were added as menu items 8 and 9.
- Menu smoke test after the Podman change passed without triggering an install or
  a configuration write.
- README now provides the GitHub Raw one-line launch command for the latest
  installer, alongside the clone-and-review workflow.
- macOS route-to-service detection was verified in the development environment
  (default interface `en0`, Wi-Fi service); no network settings were changed.
- The launcher now renders an `ECHO-HAORAN` ASCII banner via `printf` before
  system detection.
- Fixed pipe-launch interaction: prompts now read `/dev/tty` where available;
  README uses `bash -c "$(curl ...)"` so stdin remains the terminal.
- A PTY smoke test confirmed `cat scripts/install.sh | bash` reaches the menu and
  accepts `0` from the terminal without executing an action.
- Repository mirrors: Gitee uses SSH; CNB uses HTTPS and requires a CNB access
  token for write operations. README includes the raw-file one-line launcher for
  GitHub, Gitee, and CNB.
- `main` was pushed successfully to Gitee and CNB. Future CNB pushes require a
  CNB access token in the local credential helper.
- README embeds the current installer-menu screenshot from
  `docs/images/installer-menu.png`.
- Startup banner now includes the repository URL, blog URL, and EchoHaoRan
  authorship notice.
- The former `setup-media-tools.sh` workflow is integrated into the main entry
  point as Homebrew bootstrap, FFmpeg installation, Apple Silicon Ego Lite
  download, and a read-only media-tool environment check (items 15-18).
- Native Windows has a PowerShell 5.1+ entry point at `scripts/install.ps1`. It
  retains menu items 1-18, uses Chocolatey instead of Homebrew, uses Windows
  NetTCPIP cmdlets for addressing, installs Docker/Compose and Podman inside a
  selected WSL distribution, resolves FlClash from official GitHub releases,
  and replaces Ego Lite with Playwright plus Chrome.
