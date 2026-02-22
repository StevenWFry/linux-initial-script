# Linux Initial Setup Script

A post-install setup script for Linux that installs and configures a full suite of CLI tools, fonts, and GUI apps. Designed to get a fresh system productive quickly on either bare metal or a VM.

## Supported Distributions

| Distribution | Package Manager |
|---|---|
| Pop!\_OS | apt |
| Debian / Ubuntu and derivatives | apt |
| Fedora / RHEL derivatives | dnf |
| Arch Linux and derivatives (Manjaro, EndeavourOS, etc.) | pacman |

## Repository Contents

| File | Description |
|---|---|
| `setup.sh` | Main setup script |
| `zshrc.template` | Pre-configured `~/.zshrc` applied automatically on fresh installs |

## Usage

```bash
git clone https://github.com/StevenWFry/linux-initial-script.git
cd linux-initial-script
chmod +x setup.sh
./setup.sh
```

> Run as your regular user — the script will prompt for `sudo` when needed. Do **not** run as root.

## What It Does

The script walks through each step interactively and checks for existing installs before doing anything, making it safe to re-run.

### Prompts (asked before any installing begins)

- **Hostname** — optionally rename the machine
- **VirtualBox Guest Additions deps** — auto-detected if running in a VM; can be skipped or forced on bare metal
- **Git name / email** — pre-filled with existing values if already configured
- **Nerd Fonts** — choose from a numbered menu of popular fonts
- **Default shell** — optionally switch to zsh

### Installed Tools

#### Shell
| Tool | Description |
|---|---|
| zsh | Z Shell |
| Oh My Zsh | zsh framework and plugin manager |
| zsh-autosuggestions | Fish-like command suggestions as you type |
| zsh-syntax-highlighting | Real-time syntax colouring in the prompt |

The following built-in Oh My Zsh plugins are also enabled:

| Plugin | What it adds |
|---|---|
| `git` | Short aliases for common git commands (`gst`, `gco`, `gp`, etc.) |
| `sudo` | Press <kbd>Esc</kbd> twice to prepend `sudo` to the current command |
| `history` | `h` alias and helpers for searching command history |
| `colored-man-pages` | Colourises `man` pages for easier reading |

#### Core Utilities
| Tool | Description |
|---|---|
| curl / wget | Download tools |
| jq | JSON processor |
| xclip | Clipboard access from the terminal |

#### Modern CLI Replacements
| Tool | Replaces | Notes |
|---|---|---|
| eza | ls | Colourful, icon-aware directory listing |
| bat | cat | Syntax highlighting and Git integration |
| ripgrep (`rg`) | grep | Fast recursive search |
| fd | find | Simpler, faster file finder |
| duf | df | Modern disk usage/free display |
| ncdu | du | Interactive disk usage explorer |
| btop | top/htop | Resource monitor with a polished TUI |
| zoxide | cd | Smarter directory jumping with frecency |
| fzf | — | Fuzzy finder for files, history, and more |

#### Developer Tools
| Tool | Description |
|---|---|
| git | Version control (installed + configured) |
| delta | Syntax-highlighted git diffs |
| gh | Official GitHub CLI |
| neovim | Modal text editor |

#### Shell History
| Tool | Description |
|---|---|
| atuin | Encrypted, searchable shell history with sync |

#### System Info & Docs
| Tool | Description |
|---|---|
| fastfetch | Fast system info display |
| tldr | Simplified man pages with practical examples |

#### Fonts
| Font | Notes |
|---|---|
| JetBrainsMono | Great for coding |
| FiraCode | Popular ligature font |
| Hack | Clean and readable |
| CascadiaCode | Microsoft's coding font |
| Meslo | Popular for terminal prompts (used by Powerlevel10k) |
| UbuntuMono | Ubuntu's monospace font |
| RobotoMono | Google's monospace font |
| SourceCodePro | Adobe's coding font |
| NerdFontsSymbolsOnly | Just the icon glyphs, pairs with any font |

All fonts are installed to `~/.local/share/fonts/` and the font cache is refreshed automatically.

#### GUI Applications
| App | Method | Description |
|---|---|---|
| Flameshot | native package | Screenshot and annotation tool |
| VLC | native package | Media player (Fedora: via RPM Fusion) |
| Obsidian | Flatpak | Markdown-based note-taking |
| Bitwarden | Flatpak | Password manager |

Flatpak and the Flathub remote are configured automatically if not already present.

#### VM Support (VirtualBox)
When running inside a VirtualBox VM the script offers to install the kernel headers and build tools needed to compile Guest Additions:

| Distro | Packages |
|---|---|
| Pop!\_OS / Debian | `build-essential dkms linux-headers-$(uname -r) perl bzip2` |
| Fedora | `kernel-devel kernel-headers gcc make perl bzip2 elfutils-libelf-devel` |
| Arch | `base-devel linux-headers dkms` |

On Arch and Fedora it also offers to install the full guest utilities package directly. On Pop!\_OS and Debian it prints the command to run the ISO-based installer after reboot.

## Notes

- On Debian/Ubuntu, `bat` is installed as `batcat` and `fd` as `fdfind`. The script creates `~/.local/bin/bat` and `~/.local/bin/fd` symlinks automatically.
- `atuin` on Debian/Ubuntu is installed via the official install script to `~/.atuin/bin/`. A new terminal session is needed for it to appear in `$PATH`.
- Fedora requires RPM Fusion for VLC — the script enables the free and nonfree repos automatically if they are not already active.
- The script keeps `sudo` alive in the background for its entire run so you are not prompted repeatedly for a password.
- On a fresh Oh My Zsh install the script replaces the OMZ-generated `~/.zshrc` with `zshrc.template` from this repo, which comes pre-configured with all plugins, aliases, and evals. On an existing install the script patches the existing file instead.
- `zsh-autosuggestions` and `zsh-syntax-highlighting` are cloned into `~/.oh-my-zsh/custom/plugins/` and added to the `plugins=(...)` array in `~/.zshrc` automatically. `zsh-syntax-highlighting` is always placed last in the list as required.
- The following aliases are appended to `~/.zshrc` (idempotent — safe to re-run):

  | Alias | Command |
  |---|---|
  | `cat` | `bat --paging=never` (falls back to `batcat` on Debian/Ubuntu) |
  | `catp` | `bat` (bat with paging enabled) |
  | `ls` | `eza --icons --group-directories-first` |
  | `ll` | `eza -lh --icons --group-directories-first --git` |
  | `la` | `eza -lah --icons --group-directories-first --git` |
  | `lt` | `eza --tree --icons --level=2` |
  | `l` | `eza -1 --icons` |
