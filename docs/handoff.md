# Handoff

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
- `main` was pushed successfully to Gitee. CNB remote configuration is present,
  but the initial push is pending a CNB access token in the local credential
  helper.
- Startup banner now includes the repository URL, blog URL, and EchoHaoRan
  authorship notice.
