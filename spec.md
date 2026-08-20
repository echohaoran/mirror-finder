# Mirror Finder specification

## Goal

Provide Bash and PowerShell entry points for installing development tools and
configuring optional package, language, and Docker mirrors, plus IPv4 addressing.

## Supported platforms

- macOS with Homebrew
- Windows 10/11 with PowerShell 5.1+ and Chocolatey
- Debian and Ubuntu (`apt`)
- Fedora/RHEL/Rocky/AlmaLinux (`dnf` or `yum`)
- Arch Linux (`pacman`)

Windows uses `scripts/install.ps1`; WSL may use the Bash entry point.

## Safety requirements

- For every mirror action, test Chinese mainland candidate mirrors first, show up
  to the five lowest-latency reachable results, and require a selection and a
  separate confirmation before changing configuration.
- Back up each modified configuration under `~/.mirror-finder/backups/`.
- Download remote installer scripts to a temporary file before execution.
- Prefer official project installers and GitHub release assets.
- Do not embed credentials, proxy subscriptions, or private registry addresses.
- Before changing addressing, identify the default-route interface and its
  configuration backend, back up the affected configuration, warn about a
  likely network interruption, and require confirmation.

## Menu

1. Test and configure system package-manager mirror
2. Install Node.js, npm, and npx
3. Configure npm/npx registry
4. Install Python
5. Configure pip mirror
6. Install Docker
7. Configure Docker registry mirror
8. Install Podman and a Compose provider
9. Configure Podman Docker Hub mirror
10. Install OpenCode
11. Install Hermes Agent
12. Install FlClash
13. Configure a static IPv4 address (IP, subnet mask, and gateway)
14. Restore DHCP on the default-route interface
15. Install Homebrew on macOS
16. Install FFmpeg
17. Download the Ego Lite DMG on Apple Silicon macOS
18. Check Homebrew, Node.js, npm, FFmpeg, and ego-browser availability

The Windows menu keeps the same numbering. Chocolatey replaces Homebrew; Docker
Engine, Compose, and Podman run inside a selected WSL distribution; native
NetTCPIP cmdlets handle IPv4/DHCP; and item 17 installs Playwright plus its
managed Chrome instead of Ego Lite.

Each menu item can be run independently, repeatedly, and non-interactively by
passing its number as the first argument.
