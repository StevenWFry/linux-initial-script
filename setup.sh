#!/usr/bin/env bash
# =============================================================================
# Post-Install Setup Script
# Supports: Pop!_OS, Fedora, Arch Linux, Debian/Ubuntu and derivatives
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSHRC_TEMPLATE="$SCRIPT_DIR/zshrc.template"

# Set by the upfront prompt-theme question in main()
PROMPT_THEME="p10k"   # p10k | starship | skip

# -----------------------------------------------------------------------------
# Colors
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# -----------------------------------------------------------------------------
# Logging helpers
# -----------------------------------------------------------------------------
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
header()  { echo -e "\n${BOLD}${CYAN}==> $*${NC}"; }

ask() {
    # ask <variable_name> <prompt> [default]
    local var="$1" prompt="$2" default="${3:-}" full_prompt
    if [[ -n "$default" ]]; then
        full_prompt="${BOLD}${prompt} [${default}]: ${NC}"
    else
        full_prompt="${BOLD}${prompt}: ${NC}"
    fi
    echo -en "$full_prompt"
    read -r input
    [[ -z "$input" && -n "$default" ]] && input="$default"
    printf -v "$var" '%s' "$input"
}

ask_yn() {
    # ask_yn <prompt> [Y|N]  — returns 0 for yes, 1 for no
    local prompt="$1" default="${2:-Y}" choices
    [[ "${default^^}" == "Y" ]] && choices="[Y/n]" || choices="[y/N]"
    echo -en "${BOLD}${prompt} ${choices}: ${NC}"
    read -r ans
    [[ -z "$ans" ]] && ans="$default"
    [[ "${ans^^}" == "Y" ]]
}

cmd_exists() { command -v "$1" &>/dev/null; }

# -----------------------------------------------------------------------------
# Sudo / privilege management
# -----------------------------------------------------------------------------
require_sudo() {
    if [[ $EUID -eq 0 ]]; then
        error "Do not run this script as root. Run as your regular user with sudo privileges."
        exit 1
    fi
    if ! sudo -v 2>/dev/null; then
        error "This script requires sudo privileges."
        exit 1
    fi
    # Keep sudo alive in the background for the duration of the script
    ( while true; do sudo -v; sleep 50; done ) &
    SUDO_KEEPALIVE_PID=$!
    trap '_cleanup' INT TERM EXIT
}

_cleanup() {
    kill "${SUDO_KEEPALIVE_PID:-}" 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# Ensure ~/.local/bin is available (for symlinks / user-installed binaries)
# -----------------------------------------------------------------------------
setup_local_bin() {
    local local_bin="$HOME/.local/bin"
    mkdir -p "$local_bin"
    # Make available for the rest of this script
    export PATH="$local_bin:$PATH"
}

# -----------------------------------------------------------------------------
# GitHub helpers
# -----------------------------------------------------------------------------
github_latest_tag() {
    # github_latest_tag <owner/repo>  → prints latest release tag (e.g. v1.2.3)
    curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
        | grep '"tag_name"' \
        | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/'
}

# -----------------------------------------------------------------------------
# Distro detection
# -----------------------------------------------------------------------------
detect_distro() {
    header "Detecting distribution"

    [[ ! -f /etc/os-release ]] && { error "/etc/os-release not found."; exit 1; }

    # shellcheck source=/dev/null
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_ID_LIKE="${ID_LIKE:-}"
    DISTRO_NAME="${NAME:-Unknown}"

    case "$DISTRO_ID" in
        pop)
            DISTRO="popos"; PKG_MGR="apt" ;;
        ubuntu | debian | linuxmint | elementary)
            DISTRO="debian"; PKG_MGR="apt" ;;
        fedora | rhel | centos | rocky | almalinux)
            DISTRO="fedora"; PKG_MGR="dnf" ;;
        arch | manjaro | endeavouros | garuda)
            DISTRO="arch"; PKG_MGR="pacman" ;;
        *)
            if echo "$DISTRO_ID_LIKE" | grep -qiE "debian|ubuntu"; then
                DISTRO="debian"; PKG_MGR="apt"
            elif echo "$DISTRO_ID_LIKE" | grep -qi "fedora"; then
                DISTRO="fedora"; PKG_MGR="dnf"
            elif echo "$DISTRO_ID_LIKE" | grep -qi "arch"; then
                DISTRO="arch"; PKG_MGR="pacman"
            else
                error "Unsupported distro: $DISTRO_NAME ($DISTRO_ID)"
                error "Supported: Pop!_OS, Debian/Ubuntu, Fedora, Arch and their derivatives."
                exit 1
            fi ;;
    esac

    success "Detected: ${DISTRO_NAME}  (profile=${DISTRO}, pkg=${PKG_MGR})"
}

# -----------------------------------------------------------------------------
# Package manager wrappers
# -----------------------------------------------------------------------------
pkg_update() {
    info "Syncing package lists..."
    case "$DISTRO" in
        popos | debian) sudo apt-get update -qq ;;
        fedora)         sudo dnf check-update -q || true ;;   # returns 100 when updates exist
        arch)           sudo pacman -Sy --noconfirm ;;
    esac
}

pkg_install() {
    info "Installing: $*"
    case "$DISTRO" in
        popos | debian) sudo apt-get install -y "$@" ;;
        fedora)         sudo dnf install -y "$@" ;;
        arch)           sudo pacman -S --noconfirm --needed "$@" ;;
    esac
}

# -----------------------------------------------------------------------------
# Hostname
# -----------------------------------------------------------------------------
configure_hostname() {
    header "Hostname"
    local current_hostname
    current_hostname=$(hostname)
    info "Current hostname: ${current_hostname}"

    if ask_yn "Change hostname?" N; then
        ask NEW_HOSTNAME "New hostname" "$current_hostname"
        if [[ -n "$NEW_HOSTNAME" && "$NEW_HOSTNAME" != "$current_hostname" ]]; then
            sudo hostnamectl set-hostname "$NEW_HOSTNAME"
            if grep -q "$current_hostname" /etc/hosts 2>/dev/null; then
                sudo sed -i "s/\b${current_hostname}\b/${NEW_HOSTNAME}/g" /etc/hosts
            fi
            success "Hostname set to: $NEW_HOSTNAME (takes full effect after reboot)"
        else
            info "Hostname unchanged."
        fi
    fi
}

# -----------------------------------------------------------------------------
# VM detection
# -----------------------------------------------------------------------------
detect_vm() {
    header "Environment detection"
    IS_VM=false
    VM_TYPE="none"

    if cmd_exists systemd-detect-virt; then
        local virt
        virt=$(systemd-detect-virt 2>/dev/null || echo "none")
        if [[ "$virt" != "none" ]]; then
            IS_VM=true; VM_TYPE="$virt"
            info "VM detected: ${VM_TYPE}"; return
        fi
    fi

    if [[ -r /sys/class/dmi/id/product_name ]]; then
        local product
        product=$(cat /sys/class/dmi/id/product_name)
        case "${product,,}" in
            *virtualbox*)  IS_VM=true; VM_TYPE="virtualbox" ;;
            *vmware*)      IS_VM=true; VM_TYPE="vmware"     ;;
            *kvm*|*qemu*)  IS_VM=true; VM_TYPE="kvm"        ;;
            *hyper-v*)     IS_VM=true; VM_TYPE="hyper-v"    ;;
        esac
    fi

    if $IS_VM; then
        info "VM detected: ${VM_TYPE}"
    else
        info "Bare metal (or undetected hypervisor)"
    fi
}

install_vbox_guest_deps() {
    header "VirtualBox Guest Additions — build dependencies"
    case "$DISTRO" in
        popos | debian)
            pkg_install build-essential dkms "linux-headers-$(uname -r)" perl bzip2 ;;
        fedora)
            pkg_install kernel-devel kernel-headers gcc make perl bzip2 elfutils-libelf-devel ;;
        arch)
            pkg_install base-devel linux-headers dkms ;;
    esac
    success "Build deps installed."
    warn "Mount the Guest Additions ISO and run VBoxLinuxAdditions.run to finish."
}

offer_vbox_utils() {
    case "$DISTRO" in
        arch)
            if ask_yn "Install virtualbox-guest-utils from pacman?" Y; then
                pkg_install virtualbox-guest-utils
                sudo systemctl enable --now vboxservice
                success "virtualbox-guest-utils installed and enabled."
            fi ;;
        fedora)
            if ask_yn "Install virtualbox-guest-additions from dnf?" Y; then
                pkg_install virtualbox-guest-additions
                success "VirtualBox guest additions installed."
            fi ;;
        popos | debian)
            info "Tip: after rebooting, run: sudo /media/$(whoami)/VBox*/VBoxLinuxAdditions.run" ;;
    esac
}

# -----------------------------------------------------------------------------
# Git
# -----------------------------------------------------------------------------
install_git() {
    header "Git"
    if cmd_exists git; then
        success "git already installed ($(git --version))"
    else
        pkg_install git
        success "git installed"
    fi
}

configure_git() {
    header "Git — user configuration"
    local current_name current_email
    current_name=$(git config --global user.name  2>/dev/null || true)
    current_email=$(git config --global user.email 2>/dev/null || true)

    ask GIT_NAME  "Git user name"  "${current_name:-}"
    ask GIT_EMAIL "Git user email" "${current_email:-}"

    [[ -n "$GIT_NAME"  ]] && git config --global user.name  "$GIT_NAME"  && success "git user.name  = $GIT_NAME"
    [[ -n "$GIT_EMAIL" ]] && git config --global user.email "$GIT_EMAIL" && success "git user.email = $GIT_EMAIL"
}

# -----------------------------------------------------------------------------
# zsh + Oh My Zsh
# -----------------------------------------------------------------------------
install_zsh() {
    header "zsh"
    if cmd_exists zsh; then
        success "zsh already installed ($(zsh --version | head -1))"
    else
        pkg_install zsh
        success "zsh installed"
    fi
}

install_oh_my_zsh() {
    header "Oh My Zsh"
    local omz_dir="${HOME}/.oh-my-zsh"
    if [[ -d "$omz_dir" ]]; then
        success "Oh My Zsh already installed"
        return
    fi
    info "Installing Oh My Zsh (unattended, no shell switch)..."
    RUNZSH=no CHSH=no \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
        "" --unattended
    success "Oh My Zsh installed"

    # Apply our pre-built template only for p10k (it has p10k baked in)
    if [[ "$PROMPT_THEME" == "p10k" && -f "$ZSHRC_TEMPLATE" ]]; then
        info "Applying zshrc.template → ~/.zshrc"
        cp "$ZSHRC_TEMPLATE" "$HOME/.zshrc"
        success "~/.zshrc initialised from template"
    elif [[ "$PROMPT_THEME" != "p10k" ]]; then
        info "Skipping template (non-p10k theme) — keeping OMZ default ~/.zshrc"
    else
        warn "zshrc.template not found alongside setup.sh — keeping OMZ default ~/.zshrc"
    fi
}

# -----------------------------------------------------------------------------
# Powerlevel10k
# -----------------------------------------------------------------------------
install_powerlevel10k() {
    header "Powerlevel10k"

    if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
        warn "Oh My Zsh not found — skipping Powerlevel10k"
        return
    fi

    local p10k_dir="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/themes/powerlevel10k"

    if [[ -d "$p10k_dir" ]]; then
        success "Powerlevel10k already installed"
    else
        info "Cloning Powerlevel10k..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
        success "Powerlevel10k installed"
    fi

    _configure_p10k_zshrc
    _install_p10k_config
}

_install_p10k_config() {
    local target="$HOME/.p10k.zsh"
    if [[ -f "$target" ]]; then
        success "~/.p10k.zsh already exists — skipping"
        return
    fi
    if [[ -f "$SCRIPT_DIR/p10k.zsh" ]]; then
        cp "$SCRIPT_DIR/p10k.zsh" "$target"
        success "Copied p10k.zsh → ~/.p10k.zsh"
    else
        warn "p10k.zsh not found alongside setup.sh — skipping"
        info "Run 'p10k configure' to generate a config interactively."
    fi
}

_configure_p10k_zshrc() {
    local zshrc="$HOME/.zshrc"
    [[ ! -f "$zshrc" ]] && return

    # 1. Set ZSH_THEME
    if grep -q 'ZSH_THEME="powerlevel10k/powerlevel10k"' "$zshrc"; then
        success "ZSH_THEME already set to powerlevel10k"
    else
        sed -i 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' "$zshrc"
        success "ZSH_THEME → powerlevel10k/powerlevel10k"
    fi

    # 2. Prepend instant-prompt block (must be near the top of .zshrc)
    if ! grep -q 'p10k-instant-prompt' "$zshrc"; then
        local tmp
        tmp=$(mktemp)
        cat > "$tmp" <<'BLOCK'
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

BLOCK
        cat "$tmp" "$zshrc" > "${zshrc}.tmp" && mv "${zshrc}.tmp" "$zshrc"
        rm -f "$tmp"
        success "Added p10k instant prompt block to ~/.zshrc"
    else
        success "p10k instant prompt already present"
    fi

    # 3. Source ~/.p10k.zsh at the end
    if ! grep -q 'p10k.zsh' "$zshrc"; then
        printf '\n# Powerlevel10k config — run `p10k configure` to regenerate\n[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh\n' >> "$zshrc"
        success "Added ~/.p10k.zsh source to ~/.zshrc"
    else
        success "~/.p10k.zsh source already present"
    fi

    info "Run 'p10k configure' after opening a new shell to set up your prompt."
}

# -----------------------------------------------------------------------------
# Starship
# -----------------------------------------------------------------------------
install_starship() {
    header "Starship"

    if cmd_exists starship; then
        success "Starship already installed ($(starship --version))"
    else
        case "$DISTRO" in
            popos | debian)
                info "Installing Starship via official install script..."
                curl -sS https://starship.rs/install.sh | sh -s -- --yes
                ;;
            fedora)
                pkg_install starship
                ;;
            arch)
                pkg_install starship
                ;;
        esac
        success "Starship installed"
    fi

    _configure_starship_zshrc
    _install_starship_config
}

_install_starship_config() {
    local target_dir="$HOME/.config"
    local target="$target_dir/starship.toml"

    if [[ -f "$target" ]]; then
        success "~/.config/starship.toml already exists — skipping"
        return
    fi

    mkdir -p "$target_dir"

    if [[ -f "$SCRIPT_DIR/starship.toml" ]]; then
        cp "$SCRIPT_DIR/starship.toml" "$target"
        success "Copied starship.toml → ~/.config/starship.toml"
    else
        warn "starship.toml not found alongside setup.sh — skipping"
        info "Create ~/.config/starship.toml to customise your prompt."
    fi
}

_configure_starship_zshrc() {
    local zshrc="$HOME/.zshrc"
    [[ ! -f "$zshrc" ]] && return

    # Disable OMZ theme management (empty string = let Starship handle the prompt)
    if grep -q '^ZSH_THEME=' "$zshrc"; then
        sed -i 's|^ZSH_THEME=.*|ZSH_THEME=""|' "$zshrc"
        success "ZSH_THEME set to \"\" (Starship manages the prompt)"
    fi

    # Add starship init eval if not already present
    if grep -q 'starship init' "$zshrc"; then
        success "Starship init already in ~/.zshrc"
    else
        printf '\neval "$(starship init zsh)"\n' >> "$zshrc"
        success "Added starship init to ~/.zshrc"
    fi
}

# -----------------------------------------------------------------------------
# zsh plugins
#   External: zsh-autosuggestions, zsh-syntax-highlighting
#   Built-in OMZ: git, sudo, history, colored-man-pages
# -----------------------------------------------------------------------------
install_zsh_plugins() {
    header "zsh plugins"

    local custom_plugins="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins"

    if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
        warn "Oh My Zsh not found — skipping plugin install"
        return
    fi

    # zsh-autosuggestions
    if [[ -d "$custom_plugins/zsh-autosuggestions" ]]; then
        success "zsh-autosuggestions already installed"
    else
        info "Cloning zsh-autosuggestions..."
        git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
            "$custom_plugins/zsh-autosuggestions"
        success "zsh-autosuggestions installed"
    fi

    # zsh-syntax-highlighting (must be sourced last)
    if [[ -d "$custom_plugins/zsh-syntax-highlighting" ]]; then
        success "zsh-syntax-highlighting already installed"
    else
        info "Cloning zsh-syntax-highlighting..."
        git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git \
            "$custom_plugins/zsh-syntax-highlighting"
        success "zsh-syntax-highlighting installed"
    fi

    _configure_zsh_plugins
}

_configure_zsh_plugins() {
    local zshrc="$HOME/.zshrc"

    if [[ ! -f "$zshrc" ]]; then
        warn "~/.zshrc not found — cannot update plugins list"
        return
    fi

    # Only handle the common single-line format: plugins=(...)
    if ! grep -qE '^plugins=\(' "$zshrc"; then
        warn "Multi-line or missing plugins=() in ~/.zshrc — add these manually:"
        warn "  zsh-autosuggestions  zsh-syntax-highlighting"
        return
    fi

    local current_line
    current_line=$(grep -E '^plugins=\(' "$zshrc" | head -1)

    # Extract existing plugin names (strip 'plugins=(' and ')')
    local plugin_str
    plugin_str=$(echo "$current_line" | sed -E 's/^plugins=\(([^)]*)\)$/\1/' | tr -s ' ')

    # Remove zsh-syntax-highlighting if present (re-added at the end to keep it last)
    plugin_str=$(echo "$plugin_str" | sed 's/\bzsh-syntax-highlighting\b//g' | tr -s ' ' | sed 's/^ //;s/ $//')

    local changed=false

    # Add built-in OMZ plugins if absent
    for plugin in sudo history colored-man-pages; do
        if ! echo " $plugin_str " | grep -q " $plugin "; then
            plugin_str="$plugin_str $plugin"
            changed=true
        fi
    done

    # Add zsh-autosuggestions before syntax-highlighting
    if ! echo " $plugin_str " | grep -q " zsh-autosuggestions "; then
        plugin_str="$plugin_str zsh-autosuggestions"
        changed=true
    fi

    # Always append zsh-syntax-highlighting last
    plugin_str="$plugin_str zsh-syntax-highlighting"

    # Normalise whitespace
    plugin_str=$(echo "$plugin_str" | tr -s ' ' | sed 's/^ //;s/ $//')

    if grep -q "zsh-syntax-highlighting" "$current_line" 2>/dev/null && ! $changed; then
        success "~/.zshrc plugins already up to date"
        return
    fi

    sed -i "s|^plugins=(.*)|plugins=(${plugin_str})|" "$zshrc"
    success "Updated ~/.zshrc: plugins=(${plugin_str})"
}

# -----------------------------------------------------------------------------
# Configure ~/.zshrc — zoxide and atuin init evals
# -----------------------------------------------------------------------------
configure_zshrc_evals() {
    header "Configuring ~/.zshrc (zoxide + atuin init)"

    local zshrc="$HOME/.zshrc"

    # Create a minimal .zshrc if Oh My Zsh somehow didn't make one
    if [[ ! -f "$zshrc" ]]; then
        warn "~/.zshrc not found — creating a minimal one"
        touch "$zshrc"
    fi

    # Each entry: "guard_string" "line_to_append"
    local -a evals=(
        "zoxide init"   'eval "$(zoxide init zsh)"'
        "atuin init"    'eval "$(atuin init zsh)"'
    )

    local i
    for (( i = 0; i < ${#evals[@]}; i += 2 )); do
        local guard="${evals[$i]}"
        local line="${evals[$i+1]}"
        if grep -qF "$guard" "$zshrc"; then
            success "Already present: $guard"
        else
            printf '\n%s\n' "$line" >> "$zshrc"
            success "Added to ~/.zshrc: $line"
        fi
    done
}

# -----------------------------------------------------------------------------
# Shell aliases — bat and eza
# -----------------------------------------------------------------------------
configure_shell_aliases() {
    header "Shell aliases (bat + eza)"

    local zshrc="$HOME/.zshrc"
    local marker="# --- bat & eza aliases"

    if [[ ! -f "$zshrc" ]]; then
        warn "~/.zshrc not found — skipping aliases"
        return
    fi

    if grep -qF "$marker" "$zshrc"; then
        success "Aliases already present in ~/.zshrc"
        return
    fi

    cat >> "$zshrc" <<'EOF'

# --- bat & eza aliases ---

# bat — falls back to batcat (Debian/Ubuntu package name)
if command -v bat &>/dev/null; then
    alias cat='bat --paging=never'
    alias catp='bat'                      # bat with paging
elif command -v batcat &>/dev/null; then
    alias cat='batcat --paging=never'
    alias catp='batcat'
fi

# eza — modern ls replacement
alias ls='eza --icons --group-directories-first'
alias ll='eza -lh --icons --group-directories-first --git'
alias la='eza -lah --icons --group-directories-first --git'
alias lt='eza --tree --icons --level=2'
alias l='eza -1 --icons'
EOF

    success "bat and eza aliases added to ~/.zshrc"
}

set_default_shell_zsh() {
    header "Default shell"
    local zsh_path
    zsh_path=$(command -v zsh)
    if [[ "$SHELL" == "$zsh_path" ]]; then
        success "zsh is already the default shell"
        return
    fi
    if ask_yn "Set zsh as the default shell for ${USER}?" Y; then
        grep -qxF "$zsh_path" /etc/shells || echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
        sudo chsh -s "$zsh_path" "$USER"
        success "Default shell → zsh (takes effect on next login)"
    fi
}

# -----------------------------------------------------------------------------
# Base utilities: curl, wget, jq, xclip, fontconfig
# -----------------------------------------------------------------------------
install_base_tools() {
    header "Base utilities (curl, wget, jq, xclip)"
    case "$DISTRO" in
        popos | debian)
            pkg_install curl wget jq xclip fontconfig ;;
        fedora)
            pkg_install curl wget jq xclip fontconfig ;;
        arch)
            pkg_install curl wget jq xclip fontconfig ;;
    esac
    success "Base utilities installed"
}

# -----------------------------------------------------------------------------
# Modern CLI tools
#   bat, ripgrep, fd, fzf, eza, ncdu, btop, duf, tldr, zoxide
# -----------------------------------------------------------------------------
install_modern_cli() {
    header "Modern CLI tools (bat, ripgrep, fd, fzf, ncdu, btop, duf, tldr, zoxide)"

    case "$DISTRO" in
        popos | debian)
            pkg_install \
                bat \
                ripgrep \
                fd-find \
                fzf \
                ncdu \
                btop \
                duf \
                tldr \
                zoxide

            # Debian/Ubuntu ships bat as 'batcat' and fd as 'fdfind' — add ~/.local/bin shims
            local local_bin="$HOME/.local/bin"
            if [[ -f /usr/bin/batcat && ! -e "$local_bin/bat" ]]; then
                ln -sf /usr/bin/batcat "$local_bin/bat"
                success "Symlink created: bat → batcat"
            fi
            if cmd_exists fdfind && [[ ! -e "$local_bin/fd" ]]; then
                ln -sf "$(command -v fdfind)" "$local_bin/fd"
                success "Symlink created: fd → fdfind"
            fi
            ;;

        fedora)
            pkg_install \
                bat \
                ripgrep \
                fd-find \
                fzf \
                ncdu \
                btop \
                duf \
                tealdeer \
                zoxide
            ;;

        arch)
            pkg_install \
                bat \
                ripgrep \
                fd \
                fzf \
                ncdu \
                btop \
                duf \
                tealdeer \
                zoxide
            ;;
    esac

    success "Modern CLI tools installed"
}

# -----------------------------------------------------------------------------
# eza  (needs a custom apt repo on Debian/Ubuntu)
# -----------------------------------------------------------------------------
install_eza() {
    header "eza"
    if cmd_exists eza; then
        success "eza already installed ($(eza --version | head -1))"
        return
    fi
    case "$DISTRO" in
        popos | debian) _install_eza_apt ;;
        fedora)         pkg_install eza  ;;
        arch)           pkg_install eza  ;;
    esac
    success "eza installed"
}

_install_eza_apt() {
    info "Adding eza apt repository..."
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
        | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
        | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
    sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
    sudo apt-get update -qq
    sudo apt-get install -y eza
}

# -----------------------------------------------------------------------------
# atuin  (shell history)
# -----------------------------------------------------------------------------
install_atuin() {
    header "atuin"
    if cmd_exists atuin; then
        success "atuin already installed ($(atuin --version))"
        return
    fi
    case "$DISTRO" in
        popos | debian)
            info "Installing atuin via official install script..."
            curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
            success "atuin installed to ~/.atuin/bin/ (restart shell to use)"
            ;;
        fedora)
            pkg_install atuin ;;
        arch)
            pkg_install atuin ;;
    esac
    success "atuin installed"
}

# -----------------------------------------------------------------------------
# delta  (better git diffs)
# -----------------------------------------------------------------------------
install_delta() {
    header "delta (git-delta)"
    if cmd_exists delta; then
        success "delta already installed ($(delta --version))"
        return
    fi
    case "$DISTRO" in
        popos | debian) _install_delta_deb ;;
        fedora)         pkg_install git-delta ;;
        arch)           pkg_install git-delta ;;
    esac
    success "delta installed"
}

_install_delta_deb() {
    info "Downloading latest delta .deb from GitHub..."
    local tag arch deb tmp
    tag=$(github_latest_tag "dandavison/delta")
    arch=$(dpkg --print-architecture)
    deb="git-delta_${tag#v}_${arch}.deb"
    tmp=$(mktemp /tmp/delta-XXXXXX.deb)
    wget -q -O "$tmp" \
        "https://github.com/dandavison/delta/releases/download/${tag}/${deb}"
    sudo dpkg -i "$tmp"
    rm -f "$tmp"
}

# -----------------------------------------------------------------------------
# Neovim
# -----------------------------------------------------------------------------
install_neovim() {
    header "Neovim"
    if cmd_exists nvim; then
        success "neovim already installed ($(nvim --version | head -1))"
        return
    fi
    case "$DISTRO" in
        popos | debian) pkg_install neovim ;;
        fedora)         pkg_install neovim ;;
        arch)           pkg_install neovim ;;
    esac
    success "neovim installed"
}

# -----------------------------------------------------------------------------
# GitHub CLI (gh)
# -----------------------------------------------------------------------------
install_gh() {
    header "GitHub CLI (gh)"
    if cmd_exists gh; then
        success "gh already installed ($(gh --version | head -1))"
        return
    fi
    case "$DISTRO" in
        popos | debian) _install_gh_apt ;;
        fedora)         pkg_install gh  ;;
        arch)           pkg_install github-cli ;;
    esac
    success "gh installed"
}

_install_gh_apt() {
    info "Adding GitHub CLI apt repository..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y gh
}

# -----------------------------------------------------------------------------
# fastfetch
# -----------------------------------------------------------------------------
install_fastfetch() {
    header "fastfetch"
    if cmd_exists fastfetch; then
        success "fastfetch already installed"
        return
    fi
    case "$DISTRO" in
        popos | debian) _install_fastfetch_deb ;;
        fedora)         pkg_install fastfetch  ;;
        arch)           pkg_install fastfetch  ;;
    esac
    success "fastfetch installed"
}

_install_fastfetch_deb() {
    info "Downloading latest fastfetch .deb from GitHub..."
    local tag arch deb tmp
    tag=$(github_latest_tag "fastfetch-cli/fastfetch")
    arch=$(dpkg --print-architecture)
    deb="fastfetch-linux-${arch}.deb"
    tmp=$(mktemp /tmp/fastfetch-XXXXXX.deb)
    wget -q -O "$tmp" \
        "https://github.com/fastfetch-cli/fastfetch/releases/download/${tag}/${deb}"
    sudo dpkg -i "$tmp"
    rm -f "$tmp"
}

# -----------------------------------------------------------------------------
# Nerd Fonts
# -----------------------------------------------------------------------------
install_nerd_fonts() {
    header "Nerd Fonts"

    local -a FONTS=(
        "JetBrainsMono"
        "FiraCode"
        "Hack"
        "CascadiaCode"
        "Meslo"
        "UbuntuMono"
        "RobotoMono"
        "SourceCodePro"
        "NerdFontsSymbolsOnly"
    )

    echo ""
    echo -e "  ${BOLD}Available Nerd Fonts:${NC}"
    for i in "${!FONTS[@]}"; do
        printf "    %2d) %s\n" $((i + 1)) "${FONTS[$i]}"
    done
    echo "     a) All fonts"
    echo "     0) Skip"
    echo ""
    echo -en "${BOLD}Select fonts (e.g. 1 3 5  or  a  or  0 to skip): ${NC}"
    read -r font_input

    if [[ "$font_input" == "0" || -z "$font_input" ]]; then
        info "Skipping Nerd Fonts"
        return
    fi

    local -a to_install=()
    if [[ "$font_input" == "a" ]]; then
        to_install=("${FONTS[@]}")
    else
        for num in $font_input; do
            if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#FONTS[@]} )); then
                to_install+=("${FONTS[$((num - 1))]}")
            fi
        done
    fi

    if [[ "${#to_install[@]}" -eq 0 ]]; then
        warn "No valid font selections — skipping."
        return
    fi

    local fonts_dir="$HOME/.local/share/fonts/NerdFonts"
    mkdir -p "$fonts_dir"

    local tag
    tag=$(github_latest_tag "ryanoasis/nerd-fonts")
    info "Nerd Fonts release: ${tag}"

    for font in "${to_install[@]}"; do
        local font_dir="$fonts_dir/$font"
        if [[ -d "$font_dir" ]] && ls "$font_dir"/*.ttf &>/dev/null 2>&1; then
            success "$font already installed"
            continue
        fi
        info "Downloading ${font}..."
        local tmp_dir
        tmp_dir=$(mktemp -d /tmp/nf-XXXXXX)
        wget -q -O "$tmp_dir/${font}.tar.xz" \
            "https://github.com/ryanoasis/nerd-fonts/releases/download/${tag}/${font}.tar.xz"
        mkdir -p "$font_dir"
        tar -xJf "$tmp_dir/${font}.tar.xz" -C "$font_dir"
        rm -rf "$tmp_dir"
        success "${font} installed"
    done

    info "Refreshing font cache..."
    fc-cache -f
    success "Nerd Fonts ready"
}

# -----------------------------------------------------------------------------
# flameshot
# -----------------------------------------------------------------------------
install_flameshot() {
    header "flameshot"
    if cmd_exists flameshot; then
        success "flameshot already installed"
        return
    fi
    case "$DISTRO" in
        popos | debian) pkg_install flameshot ;;
        fedora)         pkg_install flameshot ;;
        arch)           pkg_install flameshot ;;
    esac
    success "flameshot installed"
}

# -----------------------------------------------------------------------------
# VLC  (Fedora needs RPM Fusion)
# -----------------------------------------------------------------------------
install_vlc() {
    header "VLC"
    if cmd_exists vlc; then
        success "VLC already installed"
        return
    fi
    case "$DISTRO" in
        popos | debian) pkg_install vlc ;;
        fedora)
            _enable_rpmfusion
            pkg_install vlc ;;
        arch) pkg_install vlc ;;
    esac
    success "VLC installed"
}

_enable_rpmfusion() {
    if sudo dnf repolist enabled 2>/dev/null | grep -q rpmfusion-free; then
        info "RPM Fusion already enabled"
        return
    fi
    info "Enabling RPM Fusion (free + nonfree)..."
    local fedora_ver
    fedora_ver=$(rpm -E %fedora)
    sudo dnf install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_ver}.noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_ver}.noarch.rpm"
    success "RPM Fusion enabled"
}

# -----------------------------------------------------------------------------
# Flatpak + Flathub  (for Obsidian and Bitwarden)
# -----------------------------------------------------------------------------
setup_flatpak() {
    header "Flatpak + Flathub"
    if ! cmd_exists flatpak; then
        case "$DISTRO" in
            popos | debian) pkg_install flatpak ;;
            fedora)         pkg_install flatpak ;;
            arch)           pkg_install flatpak ;;
        esac
    else
        success "flatpak already installed"
    fi

    if ! flatpak remotes 2>/dev/null | grep -q flathub; then
        info "Adding Flathub remote..."
        sudo flatpak remote-add --if-not-exists flathub \
            https://dl.flathub.org/repo/flathub.flatpakrepo
        success "Flathub added"
    else
        success "Flathub remote already configured"
    fi
}

install_obsidian() {
    header "Obsidian"
    if flatpak list 2>/dev/null | grep -q md.obsidian.Obsidian; then
        success "Obsidian already installed"
        return
    fi
    flatpak install -y flathub md.obsidian.Obsidian
    success "Obsidian installed"
}

install_bitwarden() {
    header "Bitwarden"
    if flatpak list 2>/dev/null | grep -q com.bitwarden.desktop; then
        success "Bitwarden already installed"
        return
    fi
    flatpak install -y flathub com.bitwarden.desktop
    success "Bitwarden installed"
}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
print_summary() {
    local do_vbox="${1:-false}"

    local prompt_label
    case "$PROMPT_THEME" in
        p10k)     prompt_label="Powerlevel10k" ;;
        starship) prompt_label="Starship"      ;;
        *)        prompt_label="(skipped)"     ;;
    esac

    echo ""
    echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════╗"
    echo -e "║                   Setup complete!                        ║"
    echo -e "╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BOLD}Installed / configured:${NC}"
    echo "  Shell          │ zsh, Oh My Zsh (${prompt_label}), zsh-autosuggestions, zsh-syntax-highlighting"
    echo "  Aliases        │ cat/catp→bat  ls/ll/la/lt/l→eza"
    echo "  Downloads      │ curl, wget"
    echo "  Data           │ jq"
    echo "  Clipboard      │ xclip"
    echo "  File listing   │ eza, fd, ncdu, duf"
    echo "  Search         │ fzf, ripgrep"
    echo "  Viewing        │ bat, btop"
    echo "  Navigation     │ zoxide"
    echo "  History        │ atuin"
    echo "  Git            │ git (configured), delta, gh"
    echo "  Editors        │ neovim"
    echo "  Info           │ fastfetch, tldr"
    echo "  Fonts          │ Nerd Fonts (selected)"
    echo "  Screenshots    │ flameshot"
    echo "  Media          │ vlc"
    echo "  Notes          │ obsidian (flatpak)"
    echo "  Passwords      │ bitwarden (flatpak)"
    [[ "$do_vbox" == "true" ]] && \
    echo "  VM             │ VirtualBox Guest Additions deps"
    echo ""
    warn "Start a new terminal session for zsh, zoxide, and atuin to take effect."
    warn "If you installed Nerd Fonts, you may need to set them in your terminal emulator settings."
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║             Post-Install Setup Script                    ║"
    echo "║     Pop!_OS · Fedora · Arch · Debian/Ubuntu              ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    require_sudo
    setup_local_bin
    detect_distro
    detect_vm

    # --- Ask upfront questions before any installing starts ---

    # Prompt theme selection
    header "Prompt theme"
    echo "  1) Powerlevel10k  — powerline arrows, git info, pre-built config included"
    echo "  2) Starship       — fast, minimal, cross-shell, toml config"
    echo "  3) Skip           — keep whatever is already set"
    echo ""
    ask THEME_CHOICE "Choice" "1"
    case "${THEME_CHOICE:-1}" in
        2) PROMPT_THEME="starship" ;;
        3) PROMPT_THEME="skip"    ;;
        *) PROMPT_THEME="p10k"    ;;
    esac
    info "Prompt theme: ${PROMPT_THEME}"

    local do_vbox=false

    if $IS_VM; then
        if [[ "$VM_TYPE" == "virtualbox" ]]; then
            ask_yn "VirtualBox VM detected — install Guest Additions build deps?" Y \
                && do_vbox=true || true
        else
            warn "VM type is '${VM_TYPE}' — VirtualBox deps not auto-selected."
            ask_yn "Install VirtualBox Guest Additions deps anyway?" N \
                && do_vbox=true || true
        fi
    else
        ask_yn "Bare metal detected — install VirtualBox Guest Additions deps anyway?" N \
            && do_vbox=true || true
    fi

    configure_hostname

    # --- Update package lists once ---
    header "Syncing package manager"
    pkg_update

    # --- Install everything ---
    install_base_tools
    install_git
    configure_git
    install_zsh
    install_oh_my_zsh
    case "$PROMPT_THEME" in
        p10k)     install_powerlevel10k ;;
        starship) install_starship      ;;
        skip)     info "Skipping prompt theme" ;;
    esac
    install_zsh_plugins
    install_modern_cli
    install_eza
    install_atuin
    install_delta
    install_neovim
    install_gh
    install_fastfetch
    install_nerd_fonts
    install_flameshot
    install_vlc
    setup_flatpak
    install_obsidian
    install_bitwarden
    configure_zshrc_evals
    configure_shell_aliases

    [[ "$do_vbox" == "true" ]] && install_vbox_guest_deps && offer_vbox_utils

    set_default_shell_zsh
    print_summary "$do_vbox"
}

main "$@"
