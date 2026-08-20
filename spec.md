# Mirror Finder specification

## Goal

Provide one Bash entry point that detects macOS or a common Linux distribution and
offers an interactive menu for installing development tools and configuring
optional package, language, and Docker mirrors, plus IPv4 addressing.

## Supported platforms

- macOS with Homebrew
- Debian and Ubuntu (`apt`)
- Fedora/RHEL/Rocky/AlmaLinux (`dnf` or `yum`)
- Arch Linux (`pacman`)

Native Windows is intentionally out of scope; use WSL instead.

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

Each menu item can be run independently, repeatedly, and non-interactively by
passing its number as the first argument.
