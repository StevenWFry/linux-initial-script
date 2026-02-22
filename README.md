# Linux Initial Setup Scripts

Two post-install setup scripts for Linux — pick the one that suits your style.

## Supported Distributions

| Distribution | Package Manager |
|---|---|
| Pop!\_OS | apt |
| Debian / Ubuntu and derivatives | apt |
| Fedora / RHEL derivatives | dnf |
| Arch Linux and derivatives (Manjaro, EndeavourOS, etc.) | pacman |

---

## Which script should I use?

| | `setup.sh` | `fresh-linux.sh` |
|---|---|---|
| **Style** | Automated — a few upfront questions, then runs unattended | Interactive — gum TUI menus let you pick sections and tools |
| **Logging** | Terminal output | Everything logged to `~/fresh-linux-<timestamp>.log` |
| **Distro detection** | Parses `/etc/os-release` (handles Pop!\_OS, ID\_LIKE fallback) | Checks command presence (`apt` / `dnf` / `pacman`) |
| **Prompt theme** | Powerlevel10k (pre-built config included) | Starship |
| **zshrc** | Applies `zshrc.template` on fresh install | Appends an additions block after confirming |
| **Nerd Fonts** | Multi-font selector, `.tar.xz` from GitHub | JetBrainsMono only (with confirm) |
| **apt edge cases** | Adds GPG repos for eza / gh / delta; downloads .deb for fastfetch | Plain package install (may fail on older distros) |
| **bat / fd on Debian** | Creates `~/.local/bin` shims automatically | Not handled |
| **Git config** | Prompts for `user.name` / `user.email` | Not included |
| **VM support** | Auto-detects VM, installs VirtualBox Guest Additions deps | Not included |
| **Hostname** | Optional rename | Not included |
| **Extras** | — | Docker, mise, LazyVim, UFW firewall, Timeshift, dotfiles via stow, terminal emulator picker, multiplexer picker (tmux / zellij), yq, xh, dust, DBeaver, Insomnia, Bottles |

---

## Repository Contents

| File | Description |
|---|---|
| `setup.sh` | Automated setup script |
| `fresh-linux.sh` | Interactive TUI-driven setup script |
| `zshrc.template` | Pre-configured `~/.zshrc` applied by `setup.sh` on fresh installs |
| `p10k.zsh` | Powerlevel10k prompt config copied to `~/.p10k.zsh` by `setup.sh` |

---

## `setup.sh` — Automated

```bash
git clone https://github.com/StevenWFry/linux-initial-script.git
cd linux-initial-script
chmod +x setup.sh
./setup.sh
```

> Run as your regular user — the script will prompt for `sudo` when needed. Do **not** run as root.

The script checks for existing installs before doing anything, making it safe to re-run.

### Prompts (asked before installing begins)

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
| Powerlevel10k | Fast, highly customisable zsh prompt |
| zsh-autosuggestions | Fish-like command suggestions as you type |
| zsh-syntax-highlighting | Real-time syntax colouring in the prompt |

Built-in Oh My Zsh plugins enabled: `git`, `sudo`, `history`, `colored-man-pages`

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
| atuin | Encrypted, searchable shell history |
| fastfetch | Fast system info display |
| tldr | Simplified man pages |

#### Fonts
Choose any combination from the menu — all installed to `~/.local/share/fonts/`:

JetBrainsMono · FiraCode · Hack · CascadiaCode · Meslo · UbuntuMono · RobotoMono · SourceCodePro · NerdFontsSymbolsOnly

#### GUI Applications
| App | Method | Description |
|---|---|---|
| Flameshot | native package | Screenshot and annotation tool |
| VLC | native package | Media player (Fedora: via RPM Fusion) |
| Obsidian | Flatpak | Markdown-based note-taking |
| Bitwarden | Flatpak | Password manager |

#### VM Support (VirtualBox)
Auto-detected. Installs the kernel headers and build tools needed for Guest Additions:

| Distro | Packages |
|---|---|
| Pop!\_OS / Debian | `build-essential dkms linux-headers-$(uname -r) perl bzip2` |
| Fedora | `kernel-devel kernel-headers gcc make perl bzip2 elfutils-libelf-devel` |
| Arch | `base-devel linux-headers dkms` |

### zshrc & Prompt

On a fresh Oh My Zsh install, `zshrc.template` is copied to `~/.zshrc` in place of the OMZ default. On an existing install the file is patched instead. Both paths are idempotent.

Powerlevel10k config (`p10k.zsh`) is copied to `~/.p10k.zsh` automatically — no wizard needed on first login. Run `p10k configure` at any time to regenerate it interactively.

**Prompt layout:**
- Left: distro icon → directory → git status → `❯`
- Right: exit code · execution time · background jobs · python venv · node version · time

**Aliases added to `~/.zshrc`:**

| Alias | Command |
|---|---|
| `cat` | `bat --paging=never` (falls back to `batcat` on Debian/Ubuntu) |
| `catp` | `bat` (with paging) |
| `ls` | `eza --icons --group-directories-first` |
| `ll` | `eza -lh --icons --group-directories-first --git` |
| `la` | `eza -lah --icons --group-directories-first --git` |
| `lt` | `eza --tree --icons --level=2` |
| `l` | `eza -1 --icons` |

### Notes

- On Debian/Ubuntu `bat` is installed as `batcat` and `fd` as `fdfind` — the script creates `~/.local/bin/bat` and `~/.local/bin/fd` symlinks automatically.
- `atuin` on Debian/Ubuntu is installed via the official install script to `~/.atuin/bin/`.
- Fedora: RPM Fusion (free + nonfree) is enabled automatically when installing VLC.
- `sudo` is kept alive in the background for the entire run — you won't be prompted repeatedly.

---

## `fresh-linux.sh` — Interactive

```bash
git clone https://github.com/StevenWFry/linux-initial-script.git
cd linux-initial-script
chmod +x fresh-linux.sh
./fresh-linux.sh
```

Uses [gum](https://github.com/charmbracelet/gum) (Charm) for interactive TUI menus. Gum is installed automatically at startup; if it fails the script falls back to plain shell prompts.

All output is tee'd to a timestamped log file at `~/fresh-linux-YYYYMMDD-HHMMSS.log`.

### Sections (user-selectable)

| Section | What it covers |
|---|---|
| **System update** | Full system upgrade via the native package manager |
| **Shell & terminal** | zsh, Oh My Zsh, zsh-autosuggestions, zsh-syntax-highlighting, fzf, zoxide, atuin, Starship prompt, terminal emulator picker, multiplexer picker |
| **Modern CLI tools** | Multi-select picker: eza, bat, ripgrep, fd, dust, btop, delta, tldr, duf, jq, yq, xh, fastfetch, lsd |
| **Developer tools** | build tools, gh, rsync, stow, Neovim (optional LazyVim config), Docker, mise |
| **System utilities** | UFW firewall, Timeshift (Debian), Flatpak + Flathub |
| **GUI apps** | Flatpak multi-select: Obsidian, Bitwarden, Flameshot, VLC, Bottles, DBeaver, Insomnia |
| **Dotfiles** | Clone a dotfiles repo and optionally run `stow` to symlink it |

### Terminal & Multiplexer Pickers

**Terminal emulator** — choose one to install: `alacritty` · `kitty` · `wezterm` (via Flatpak on non-Arch)

**Multiplexer** — choose: `tmux` · `zellij` · both · skip

### Developer Extras

- **Docker** — installed via `get.docker.com` (Debian) or native packages; `docker` group added for current user
- **mise** — universal version manager for Node, Python, Ruby, Go, etc.
- **LazyVim** — optionally clones the LazyVim starter config into `~/.config/nvim`
- **UFW** — configured with `deny incoming` / `allow outgoing` / `allow ssh` and enabled

### zshrc

After all installs, the script offers to append a clearly-marked additions block to `~/.zshrc` containing `eval` inits and aliases for whichever tools were installed (starship, zoxide, mise, atuin, eza, bat, ripgrep, fd, btop).
