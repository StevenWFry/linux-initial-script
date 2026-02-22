#!/usr/bin/env bash
# =============================================================================
#  fresh-linux.sh
#  Post-install setup script for Linux enthusiasts
#  Supports: apt (Ubuntu/Pop!_OS/Debian), dnf (Fedora), pacman (Arch)
#  Usage: bash fresh-linux.sh
# =============================================================================

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

LOG_FILE="$HOME/fresh-linux-$(date +%Y%m%d-%H%M%S).log"

# ── Logging ───────────────────────────────────────────────────────────────────
log()  { echo -e "${DIM}[$(date +%H:%M:%S)]${RESET} $*" | tee -a "$LOG_FILE"; }
ok()   { echo -e "${GREEN}✓${RESET} $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}⚠ $*${RESET}" | tee -a "$LOG_FILE"; }
err()  { echo -e "${RED}✗ $*${RESET}" | tee -a "$LOG_FILE"; }
info() { echo -e "${CYAN}→${RESET} $*" | tee -a "$LOG_FILE"; }

# ── Banner ────────────────────────────────────────────────────────────────────
print_banner() {
  echo -e "${CYAN}"
  cat << 'EOF'
  ___               _       _      _
 / __| _ _  ___ __| |_    | |    (_)_ _ _  ___ __
| (__| '_|/ -_|_-< ' \    | |__  | | ' \ || \ \ /
 \___|_|  \___/__/_||_|   |____|_|_|_||_\_,_/_\_\

EOF
  echo -e "${RESET}${DIM}  fresh linux post-install // $(date '+%A, %B %d %Y')${RESET}"
  echo -e "${DIM}  log → $LOG_FILE${RESET}"
  echo ""
}

# ── Detect distro & set package manager ──────────────────────────────────────
detect_distro() {
  if command -v apt &>/dev/null; then
    DISTRO="debian"
    PM_UPDATE="sudo apt update -qq"
    PM_INSTALL="sudo apt install -y"
    PM_UPGRADE="sudo apt upgrade -y"
  elif command -v dnf &>/dev/null; then
    DISTRO="fedora"
    PM_UPDATE="sudo dnf check-update -q || true"
    PM_INSTALL="sudo dnf install -y"
    PM_UPGRADE="sudo dnf upgrade -y"
  elif command -v pacman &>/dev/null; then
    DISTRO="arch"
    PM_UPDATE="sudo pacman -Sy --noconfirm"
    PM_INSTALL="sudo pacman -S --noconfirm --needed"
    PM_UPGRADE="sudo pacman -Su --noconfirm"
  else
    err "Unsupported distro. Only apt/dnf/pacman supported."
    exit 1
  fi

  ok "Detected distro: ${BOLD}$DISTRO${RESET}"
}

# ── Map package names per distro ──────────────────────────────────────────────
# Usage: pkg <apt-name> <dnf-name> <pacman-name>
pkg() {
  case "$DISTRO" in
    debian) echo "$1" ;;
    fedora) echo "$2" ;;
    arch)   echo "$3" ;;
  esac
}

# ── Check if command already exists ──────────────────────────────────────────
is_installed() {
  command -v "$1" &>/dev/null
}

# ── Install a package (with already-installed check) ─────────────────────────
install_pkg() {
  local name="$1"
  local pkg_name="$2"

  if is_installed "$name"; then
    ok "$name already installed — skipping"
    return
  fi

  info "Installing $name..."
  if $PM_INSTALL "$pkg_name" >> "$LOG_FILE" 2>&1; then
    ok "$name installed"
  else
    err "Failed to install $name (check log)"
  fi
}

# ── Install gum (Charm) for TUI menus ────────────────────────────────────────
install_gum() {
  if is_installed gum; then
    ok "gum already installed"
    return
  fi

  info "Installing gum (Charm TUI)..."

  case "$DISTRO" in
    debian)
      sudo mkdir -p /etc/apt/keyrings
      curl -fsSL https://repo.charm.sh/apt/gpg.key \
        | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg >> "$LOG_FILE" 2>&1
      echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" \
        | sudo tee /etc/apt/sources.list.d/charm.list >> "$LOG_FILE" 2>&1
      sudo apt update -qq >> "$LOG_FILE" 2>&1
      sudo apt install -y gum >> "$LOG_FILE" 2>&1
      ;;
    fedora)
      echo '[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key' | sudo tee /etc/yum.repos.d/charm.repo >> "$LOG_FILE" 2>&1
      sudo dnf install -y gum >> "$LOG_FILE" 2>&1
      ;;
    arch)
      sudo pacman -S --noconfirm --needed gum >> "$LOG_FILE" 2>&1
      ;;
  esac

  if is_installed gum; then
    ok "gum installed"
  else
    warn "gum install failed — falling back to basic prompts"
    USE_GUM=false
  fi
}

# ── Prompt helpers (gum or plain fallback) ────────────────────────────────────
USE_GUM=true

gum_confirm() {
  if $USE_GUM; then
    gum confirm "$1"
  else
    read -rp "$1 [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]]
  fi
}

gum_choose() {
  local header="$1"
  shift
  if $USE_GUM; then
    gum choose --no-limit --header="$header" "$@"
  else
    echo "$header"
    select opt in "$@" "Done"; do
      [[ "$opt" == "Done" ]] && break
      echo "$opt"
    done
  fi
}

# =============================================================================
#  INSTALL SECTIONS
# =============================================================================

# ── 1. System update ──────────────────────────────────────────────────────────
do_system_update() {
  info "Updating system packages..."
  $PM_UPDATE >> "$LOG_FILE" 2>&1
  $PM_UPGRADE >> "$LOG_FILE" 2>&1
  ok "System updated"
}

# ── 2. Shell & terminal ───────────────────────────────────────────────────────
do_shell() {
  echo ""
  echo -e "${BOLD}// Shell & Terminal${RESET}"

  install_pkg "zsh"      "$(pkg zsh zsh zsh)"
  install_pkg "curl"     "$(pkg curl curl curl)"
  install_pkg "wget"     "$(pkg wget wget wget)"
  install_pkg "git"      "$(pkg git git git)"
  install_pkg "fzf"      "$(pkg fzf fzf fzf)"
  install_pkg "zoxide"   "$(pkg zoxide zoxide zoxide)"
  install_pkg "starship" "$(pkg starship starship starship)"

  # zsh as default shell
  if [[ "$SHELL" != "$(which zsh)" ]]; then
    if gum_confirm "Set zsh as your default shell?"; then
      chsh -s "$(which zsh)"
      ok "Default shell set to zsh"
    fi
  fi

  # oh-my-zsh
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    if gum_confirm "Install oh-my-zsh?"; then
      info "Installing oh-my-zsh..."
      RUNZSH=no CHSH=no \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
        >> "$LOG_FILE" 2>&1
      ok "oh-my-zsh installed"
    fi
  else
    ok "oh-my-zsh already installed"
  fi

  # zsh-autosuggestions
  local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    info "Installing zsh-autosuggestions..."
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
      "$ZSH_CUSTOM/plugins/zsh-autosuggestions" >> "$LOG_FILE" 2>&1
    ok "zsh-autosuggestions installed"
  fi

  # zsh-syntax-highlighting
  if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
    info "Installing zsh-syntax-highlighting..."
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
      "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" >> "$LOG_FILE" 2>&1
    ok "zsh-syntax-highlighting installed"
  fi

  # atuin
  if ! is_installed atuin; then
    if gum_confirm "Install atuin (shell history sync)?"; then
      info "Installing atuin..."
      bash <(curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh) \
        >> "$LOG_FILE" 2>&1 || warn "atuin install failed"
      ok "atuin installed"
    fi
  else
    ok "atuin already installed"
  fi

  # terminal emulators
  local term_choice
  if $USE_GUM; then
    term_choice=$(gum choose --header="Install a terminal emulator?" \
      "alacritty" "kitty" "wezterm" "skip")
  else
    echo "Terminal emulator: (1) alacritty (2) kitty (3) wezterm (4) skip"
    read -rp "Choice: " tc
    case $tc in 1) term_choice="alacritty";; 2) term_choice="kitty";;
                3) term_choice="wezterm";; *) term_choice="skip";; esac
  fi

  case "$term_choice" in
    alacritty) install_pkg alacritty "$(pkg alacritty alacritty alacritty)" ;;
    kitty)     install_pkg kitty     "$(pkg kitty kitty kitty)" ;;
    wezterm)
      if [[ "$DISTRO" == "arch" ]]; then
        install_pkg wezterm wezterm wezterm
      else
        info "Installing wezterm via flatpak..."
        flatpak install -y flathub org.wezfurlong.wezterm >> "$LOG_FILE" 2>&1 || \
          warn "wezterm flatpak install failed"
      fi
      ;;
    skip) info "Skipping terminal emulator" ;;
  esac

  # tmux or zellij
  if $USE_GUM; then
    local mux_choice
    mux_choice=$(gum choose --header="Multiplexer?" "zellij" "tmux" "both" "skip")
  else
    echo "Multiplexer: (1) zellij (2) tmux (3) both (4) skip"
    read -rp "Choice: " mc
    case $mc in 1) mux_choice="zellij";; 2) mux_choice="tmux";;
                3) mux_choice="both";; *) mux_choice="skip";; esac
  fi

  case "$mux_choice" in
    zellij) install_pkg zellij "$(pkg zellij zellij zellij)" ;;
    tmux)   install_pkg tmux   "$(pkg tmux tmux tmux)" ;;
    both)
      install_pkg zellij "$(pkg zellij zellij zellij)"
      install_pkg tmux   "$(pkg tmux tmux tmux)"
      ;;
    skip) info "Skipping multiplexer" ;;
  esac
}

# ── 3. Modern CLI replacements ────────────────────────────────────────────────
do_cli_tools() {
  echo ""
  echo -e "${BOLD}// Modern CLI Tools${RESET}"

  local tools
  if $USE_GUM; then
    tools=$(gum choose --no-limit \
      --header="Select CLI tools to install (space to select, enter to confirm):" \
      "eza (better ls)"         \
      "bat (better cat)"        \
      "ripgrep (better grep)"   \
      "fd (better find)"        \
      "dust (disk usage)"       \
      "btop (better top)"       \
      "delta (git diffs)"       \
      "tldr (simple man pages)" \
      "duf (better df)"         \
      "jq (JSON processor)"     \
      "yq (YAML processor)"     \
      "xh (better curl)"        \
      "fastfetch (system info)" \
      "lsd (ls with icons)"     \
    )
  else
    tools="eza (better ls)
bat (better cat)
ripgrep (better grep)
fd (better find)
btop (better top)
delta (git diffs)
tldr (simple man pages)
jq (JSON processor)
fastfetch (system info)"
    warn "Using default CLI tools selection (no gum). Install all? Press Ctrl+C to abort."
    sleep 2
  fi

  [[ "$tools" == *"eza"*         ]] && install_pkg eza       "$(pkg eza eza eza)"
  [[ "$tools" == *"bat"*         ]] && install_pkg bat       "$(pkg bat bat bat)"
  [[ "$tools" == *"ripgrep"*     ]] && install_pkg rg        "$(pkg ripgrep ripgrep ripgrep)"
  [[ "$tools" == *"fd"*          ]] && install_pkg fd        "$(pkg fd-find fd-find fd)"
  [[ "$tools" == *"dust"*        ]] && install_pkg dust      "$(pkg dust dust dust)"
  [[ "$tools" == *"btop"*        ]] && install_pkg btop      "$(pkg btop btop btop)"
  [[ "$tools" == *"delta"*       ]] && install_pkg delta     "$(pkg git-delta git-delta git-delta)"
  [[ "$tools" == *"tldr"*        ]] && install_pkg tldr      "$(pkg tldr tldr tldr)"
  [[ "$tools" == *"duf"*         ]] && install_pkg duf       "$(pkg duf duf duf)"
  [[ "$tools" == *"jq"*          ]] && install_pkg jq        "$(pkg jq jq jq)"
  [[ "$tools" == *"yq"*          ]] && install_pkg yq        "$(pkg yq yq yq)"
  [[ "$tools" == *"xh"*          ]] && install_pkg xh        "$(pkg xh xh xh)"
  [[ "$tools" == *"fastfetch"*   ]] && install_pkg fastfetch "$(pkg fastfetch fastfetch fastfetch)"
  [[ "$tools" == *"lsd"*         ]] && install_pkg lsd       "$(pkg lsd lsd lsd)"
}

# ── 4. Developer tools ────────────────────────────────────────────────────────
do_dev_tools() {
  echo ""
  echo -e "${BOLD}// Developer Tools${RESET}"

  # Base tools everyone needs
  for tool in build-essential gcc make; do
    case "$DISTRO" in
      debian) install_pkg "$tool" "$tool" ;;
      fedora) install_pkg "$tool" "$(pkg '' 'gcc make' '')" ;;
      arch)   $PM_INSTALL base-devel >> "$LOG_FILE" 2>&1 && ok "base-devel installed"; break ;;
    esac
  done

  install_pkg "gh"      "$(pkg gh gh github-cli)"
  install_pkg "jq"      "$(pkg jq jq jq)"
  install_pkg "rsync"   "$(pkg rsync rsync rsync)"
  install_pkg "stow"    "$(pkg stow stow stow)"

  # Neovim
  if gum_confirm "Install Neovim?"; then
    case "$DISTRO" in
      debian)
        # Use PPA for latest stable
        sudo add-apt-repository -y ppa:neovim-ppa/stable >> "$LOG_FILE" 2>&1
        sudo apt update -qq >> "$LOG_FILE" 2>&1
        sudo apt install -y neovim >> "$LOG_FILE" 2>&1
        ;;
      fedora) sudo dnf install -y neovim >> "$LOG_FILE" 2>&1 ;;
      arch)   sudo pacman -S --noconfirm --needed neovim >> "$LOG_FILE" 2>&1 ;;
    esac
    ok "Neovim installed"

    if gum_confirm "Install LazyVim starter config?"; then
      if [[ ! -d "$HOME/.config/nvim" ]]; then
        git clone https://github.com/LazyVim/starter "$HOME/.config/nvim" >> "$LOG_FILE" 2>&1
        rm -rf "$HOME/.config/nvim/.git"
        ok "LazyVim config installed → run 'nvim' to finish setup"
      else
        warn "~/.config/nvim already exists — skipping LazyVim"
      fi
    fi
  fi

  # Docker
  if gum_confirm "Install Docker?"; then
    if is_installed docker; then
      ok "Docker already installed"
    else
      info "Installing Docker..."
      case "$DISTRO" in
        debian)
          curl -fsSL https://get.docker.com | sudo sh >> "$LOG_FILE" 2>&1
          ;;
        fedora)
          sudo dnf install -y docker docker-compose >> "$LOG_FILE" 2>&1
          ;;
        arch)
          sudo pacman -S --noconfirm --needed docker docker-compose >> "$LOG_FILE" 2>&1
          ;;
      esac
      sudo systemctl enable --now docker >> "$LOG_FILE" 2>&1
      sudo usermod -aG docker "$USER"
      ok "Docker installed — log out and back in for group to take effect"
    fi
  fi

  # mise (version manager for Node, Python, Ruby, etc.)
  if gum_confirm "Install mise (universal version manager)?"; then
    if is_installed mise; then
      ok "mise already installed"
    else
      curl https://mise.run | sh >> "$LOG_FILE" 2>&1
      ok "mise installed — add 'eval \"\$(\$HOME/.local/bin/mise activate bash)\"' to your .bashrc/.zshrc"
    fi
  fi

  # Nerd Fonts
  if gum_confirm "Install JetBrainsMono Nerd Font?"; then
    install_nerd_font "JetBrainsMono"
  fi
}

# ── 5. Nerd Font installer ────────────────────────────────────────────────────
install_nerd_font() {
  local font_name="${1:-JetBrainsMono}"
  local font_dir="$HOME/.local/share/fonts"
  local zip_file="/tmp/${font_name}.zip"

  info "Downloading ${font_name} Nerd Font..."
  mkdir -p "$font_dir"

  local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font_name}.zip"
  curl -fsSL "$url" -o "$zip_file" >> "$LOG_FILE" 2>&1

  if [[ -f "$zip_file" ]]; then
    unzip -qo "$zip_file" -d "$font_dir/${font_name}" >> "$LOG_FILE" 2>&1
    fc-cache -fv >> "$LOG_FILE" 2>&1
    rm "$zip_file"
    ok "${font_name} Nerd Font installed"
  else
    err "Font download failed"
  fi
}

# ── 6. System utilities ────────────────────────────────────────────────────────
do_system_utils() {
  echo ""
  echo -e "${BOLD}// System Utilities${RESET}"

  # ufw firewall
  if gum_confirm "Set up ufw firewall?"; then
    install_pkg ufw "$(pkg ufw ufw ufw)"
    sudo ufw default deny incoming >> "$LOG_FILE" 2>&1
    sudo ufw default allow outgoing >> "$LOG_FILE" 2>&1
    sudo ufw allow ssh >> "$LOG_FILE" 2>&1
    sudo ufw --force enable >> "$LOG_FILE" 2>&1
    ok "ufw enabled (SSH allowed, everything else blocked)"
  fi

  # Timeshift (snapshots) — debian/ubuntu only
  if [[ "$DISTRO" == "debian" ]] && gum_confirm "Install Timeshift (system snapshots)?"; then
    install_pkg timeshift timeshift timeshift
  fi

  # Flatpak
  if gum_confirm "Ensure Flatpak is set up with Flathub?"; then
    install_pkg flatpak "$(pkg flatpak flatpak flatpak)"
    flatpak remote-add --if-not-exists flathub \
      https://dl.flathub.org/repo/flathub.flatpakrepo >> "$LOG_FILE" 2>&1
    ok "Flatpak + Flathub configured"
  fi
}

# ── 7. GUI apps ───────────────────────────────────────────────────────────────
do_gui_apps() {
  echo ""
  echo -e "${BOLD}// GUI Applications (Flatpak)${RESET}"

  if ! is_installed flatpak; then
    warn "Flatpak not installed — skipping GUI apps"
    return
  fi

  local apps
  if $USE_GUM; then
    apps=$(gum choose --no-limit \
      --header="Select GUI apps to install via Flatpak:" \
      "Obsidian (notes)"          \
      "Bitwarden (passwords)"     \
      "Flameshot (screenshots)"   \
      "VLC (media player)"        \
      "Bottles (run Windows apps)" \
      "Dbeaver (database GUI)"    \
      "Insomnia (API client)"     \
    )
  else
    warn "Skipping GUI app selection (no gum). Run manually with flatpak install."
    return
  fi

  [[ "$apps" == *"Obsidian"*   ]] && flatpak install -y flathub md.obsidian.Obsidian      >> "$LOG_FILE" 2>&1 && ok "Obsidian installed"
  [[ "$apps" == *"Bitwarden"*  ]] && flatpak install -y flathub com.bitwarden.desktop      >> "$LOG_FILE" 2>&1 && ok "Bitwarden installed"
  [[ "$apps" == *"Flameshot"*  ]] && flatpak install -y flathub org.flameshot.Flameshot    >> "$LOG_FILE" 2>&1 && ok "Flameshot installed"
  [[ "$apps" == *"VLC"*        ]] && flatpak install -y flathub org.videolan.VLC           >> "$LOG_FILE" 2>&1 && ok "VLC installed"
  [[ "$apps" == *"Bottles"*    ]] && flatpak install -y flathub com.usebottles.bottles     >> "$LOG_FILE" 2>&1 && ok "Bottles installed"
  [[ "$apps" == *"Dbeaver"*    ]] && flatpak install -y flathub io.dbeaver.DBeaverCommunity >> "$LOG_FILE" 2>&1 && ok "DBeaver installed"
  [[ "$apps" == *"Insomnia"*   ]] && flatpak install -y flathub rest.insomnia.Insomnia     >> "$LOG_FILE" 2>&1 && ok "Insomnia installed"
}

# ── 8. Dotfile setup ──────────────────────────────────────────────────────────
do_dotfiles() {
  echo ""
  echo -e "${BOLD}// Dotfiles${RESET}"

  if gum_confirm "Set up dotfiles from a Git repo?"; then
    local dotfiles_url
    if $USE_GUM; then
      dotfiles_url=$(gum input --placeholder "https://github.com/you/dotfiles.git")
    else
      read -rp "Dotfiles repo URL: " dotfiles_url
    fi

    if [[ -n "$dotfiles_url" ]]; then
      local dotfiles_dir="$HOME/dotfiles"
      if [[ -d "$dotfiles_dir" ]]; then
        warn "~/dotfiles already exists — skipping clone"
      else
        git clone "$dotfiles_url" "$dotfiles_dir" >> "$LOG_FILE" 2>&1
        ok "Dotfiles cloned to ~/dotfiles"
      fi

      if is_installed stow && gum_confirm "Run stow to symlink dotfiles?"; then
        cd "$dotfiles_dir"
        stow . --target="$HOME" --no-folding >> "$LOG_FILE" 2>&1
        ok "stow applied"
        cd - > /dev/null
      fi
    fi
  fi
}

# ── 9. Write/update .zshrc additions ─────────────────────────────────────────
do_zshrc() {
  local zshrc="$HOME/.zshrc"
  local additions=""

  is_installed starship  && additions+=$'\neval "$(starship init zsh)"'
  is_installed zoxide    && additions+=$'\neval "$(zoxide init zsh)"'
  is_installed mise      && additions+=$'\neval "$(~/.local/bin/mise activate zsh)"'
  is_installed atuin     && additions+=$'\neval "$(atuin init zsh)"'
  is_installed eza       && additions+=$'\nalias ls="eza --icons --group-directories-first"'
  is_installed eza       && additions+=$'\nalias ll="eza -la --icons --group-directories-first"'
  is_installed bat       && additions+=$'\nalias cat="bat --style=plain"'
  is_installed rg        && additions+=$'\nalias grep="rg"'
  is_installed fd        && additions+=$'\nalias find="fd"'
  is_installed btop      && additions+=$'\nalias top="btop"'

  if [[ -n "$additions" ]]; then
    if gum_confirm "Append recommended aliases + tool inits to ~/.zshrc?"; then
      {
        echo ""
        echo "# ── fresh-linux.sh additions ──────────────────────────"
        echo "$additions"
        echo "# ───────────────────────────────────────────────────────"
      } >> "$zshrc"
      ok "~/.zshrc updated"
    fi
  fi
}

# ── 10. Summary ───────────────────────────────────────────────────────────────
print_summary() {
  echo ""
  echo -e "${CYAN}┌─────────────────────────────────────┐${RESET}"
  echo -e "${CYAN}│${RESET}  ${BOLD}Setup complete!${RESET}                    ${CYAN}│${RESET}"
  echo -e "${CYAN}│${RESET}  Log saved → ${DIM}$LOG_FILE${RESET}"
  echo -e "${CYAN}└─────────────────────────────────────┘${RESET}"
  echo ""
  echo -e "${DIM}Next steps:${RESET}"
  echo -e "  ${CYAN}→${RESET} Log out and back in (Docker group, new shell)"
  echo -e "  ${CYAN}→${RESET} Open a new terminal and run: ${BOLD}exec zsh${RESET}"
  echo -e "  ${CYAN}→${RESET} Run ${BOLD}nvim${RESET} to complete LazyVim plugin install"
  echo -e "  ${CYAN}→${RESET} Run ${BOLD}fastfetch${RESET} to flex your setup"
  echo ""
}

# =============================================================================
#  MAIN
# =============================================================================
main() {
  print_banner
  detect_distro

  echo ""
  echo -e "${DIM}Installing gum for interactive menus...${RESET}"
  install_gum

  echo ""
  echo -e "${BOLD}What would you like to set up?${RESET}"

  local sections
  if $USE_GUM; then
    sections=$(gum choose --no-limit \
      --header="Select sections to run (space = toggle, enter = confirm):" \
      "System update"      \
      "Shell & terminal"   \
      "Modern CLI tools"   \
      "Developer tools"    \
      "System utilities"   \
      "GUI apps"           \
      "Dotfiles"           \
    )
  else
    # No gum fallback: run everything
    sections="System update
Shell & terminal
Modern CLI tools
Developer tools
System utilities"
    warn "Running all sections (no gum available)"
  fi

  [[ "$sections" == *"System update"*    ]] && do_system_update
  [[ "$sections" == *"Shell & terminal"* ]] && do_shell
  [[ "$sections" == *"Modern CLI tools"* ]] && do_cli_tools
  [[ "$sections" == *"Developer tools"*  ]] && do_dev_tools
  [[ "$sections" == *"System utilities"* ]] && do_system_utils
  [[ "$sections" == *"GUI apps"*         ]] && do_gui_apps
  [[ "$sections" == *"Dotfiles"*         ]] && do_dotfiles

  # Always offer to update .zshrc
  do_zshrc

  print_summary
}

main "$@"
