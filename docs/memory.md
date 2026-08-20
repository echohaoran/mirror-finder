# Project memory

## Asset distribution

- Canonical asset base: `https://cnb.cool/echohaoran/mirror-finder/-/git/raw/main/assets`.
- Fixed resources live under `assets/`; runtime uses CNB first and official upstream only as fallback.
- Do not commit multi-hundred-megabyte Codex desktop packages to ordinary Git while the branch is also pushed to GitHub/Gitee. Use the reserved CNB large-object paths in `assets/manifest.json`.
- Production Linux Docker installation must use the project-maintained stable-repository installer, not Docker's convenience script. macOS Docker Desktop is development-only.

- Entry point: `scripts/install.sh`.
- The script uses Bash and has no required third-party runtime.
- System source configuration is intentionally opt-in, with timestamped backups.
- Package-manager, npm, pip, and Docker mirror choices are based on a fresh,
  bounded latency test of China-mainland candidates; no mirror is hard-coded as
  the selected default.
- FlClash is resolved from its upstream GitHub latest-release API for the current
  OS and CPU architecture.
- Validation completed: `bash -n scripts/install.sh`, a menu exit smoke test, and
  a read-only FlClash release-asset lookup.
- npm mirror probing was smoke-tested and correctly displayed the reachable
  results before cancellation; no npm configuration was modified.
- Docker's public candidate set is documented in `docs/docker-mirrors.md` and is
  filtered dynamically through a `/v2/` probe before selection.
- Docker's latest smoke test displayed a ranked top five from ten candidates and
  was cancelled before any Docker configuration changed.
- Network configuration uses the default-route interface only and requires a
  confirmation because applying or restoring DHCP restarts its network path.
- Static-IP input and cancellation were smoke-tested on macOS: the script found
  `en0`/Wi-Fi, validated the supplied address values, and made no configuration
  change after confirmation was declined.
- Startup branding is rendered by `print_banner` using only `printf`.
- Docker installs include the Compose plugin; Podman installs include
  `podman-compose`, which supplies the external provider used by `podman compose`.
- The expanded 14-item menu passed a no-op smoke test.
- Direct launch URL: `https://raw.githubusercontent.com/echohaoran/mirror-finder/main/scripts/install.sh`.
- Do not document the launcher as `curl URL | bash`: that pipelines script text
  into stdin. Prompts use `/dev/tty`, and the documented command uses `bash -c`.
- Pipe-launch regression test passed in a PTY: the script accepted a terminal
  menu selection and exited normally.
- Distribution remotes: `gitee` is `git@gitee.com:echohaoran/mirror-finder.git`;
  `cnb` is `https://cnb.cool/echohaoran/mirror-finder.git`.
- Gitee and CNB `main` are initialized as GitHub mirrors. Future CNB pushes use
  HTTPS token authentication with username `cnb`.
- README's installation-menu preview is stored in `docs/images/installer-menu.png`.
- The startup banner links to the project repository and `echohaoran.top`.
- Media-tool setup lives in the single `scripts/install.sh` entry point: items
  15-18 cover Homebrew, FFmpeg, Ego Lite, and environment inspection.
- Windows uses `scripts/install.ps1` with the same 18 menu numbers. Items 15-18
  are Chocolatey, FFmpeg, Playwright + Chrome, and environment inspection.
