#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ==================================================
# Output helpers (portable)
# ==================================================

log() {
  printf '%b\n' "${1:-}"
}

if [[ -t 1 ]]; then
  INFO="\033[0;34m\033[1m[INFO]\033[0m"
  OK="\033[0;32m\033[1m[OK]\033[0m"
  WARN="\033[0;33m\033[1m[WARN]\033[0m"
  ERR="\033[0;31m\033[1m[ERROR]\033[0m"
else
  INFO="[INFO]"
  OK="[OK]"
  WARN="[WARN]"
  ERR="[ERROR]"
fi

info() { log "$INFO $*"; }
ok()   { log "$OK $*"; }
warn() { log "$WARN $*"; }
err()  { log "$ERR $*"; }

info "Running install.sh"
info "This script installs dotfiles using symbolic links"

# ==================================================
# Paths
# ==================================================

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BASHRC_SRC="$DOTFILES_DIR/shell/.bashrc"
BASHRCD_SRC="$DOTFILES_DIR/shell/bashrc.d"

GITCONFIG_SRC="$DOTFILES_DIR/git/.gitconfig"
GITIGNORE_GLOBAL_SRC="$DOTFILES_DIR/git/.gitignore_global"

BASHRC_DEST="$HOME/.bashrc"
BASHRCD_DEST="$HOME/.bashrc.d"

GITCONFIG_DEST="$HOME/.gitconfig"
GITIGNORE_GLOBAL_DEST="$HOME/.gitignore_global"

NVIM_SRC="$DOTFILES_DIR/nvim"
NVIM_DEST="$HOME/.config/nvim"

# ==================================================
# Platform detection
# ==================================================

is_git_bash() {
  [[ -n "${MSYSTEM:-}" ]]
}

is_windows() {
  [[ "${OS:-}" == "Windows_NT" ]] || grep -qi microsoft /proc/version 2>/dev/null
}

# ==================================================
# Backup & cleanup helpers
# ==================================================

backup_real_file() {
  local target="$1"

  [[ -f "$target" && ! -L "$target" ]] || return 0

  local backup="${target}.bak.$(date +%Y%m%d-%H%M%S)"
  mv "$target" "$backup" || {
    warn "Failed to back up $target (skipping)"
    return 0
  }

  warn "Existing $(basename "$target") backed up"
  info "Backup created at: $(basename "$backup")"
}

remove_existing_dir() {
  local target="$1"

  if [[ -d "$target" && ! -L "$target" ]]; then
    local backup="${target}.bak.$(date +%Y%m%d-%H%M%S)"
    mv "$target" "$backup"
    warn "Existing directory $(basename "$target") backed up"
    info "Backup created at: $(basename "$backup")"
  fi
}

remove_wrong_symlink() {
  local dest="$1"
  local src="$2"

  if [[ -L "$dest" ]]; then
    local current
    current="$(readlink "$dest")"
    if [[ "$current" != "$src" ]]; then
      warn "Removing outdated symlink: $(basename "$dest")"
      rm "$dest"
    fi
  fi
}

# ==================================================
# Install helpers
# ==================================================

install_symlink() {
  local src="$1"
  local dest="$2"
  local name="$3"

  # Directories must be handled explicitly
  remove_existing_dir "$dest"

  # Files / symlinks
  backup_real_file "$dest"
  remove_wrong_symlink "$dest" "$src"

  if is_git_bash; then
    info "Installing $name (Git Bash)"
    ln -sfn "$src" "$dest"

  elif is_windows; then
    info "Installing $name (Windows)"
    if ! cmd.exe /c mklink "$(cygpath -w "$dest")" "$(cygpath -w "$src")" >nul 2>&1; then
      warn "mklink failed, copying instead"
      cp -r "$src" "$dest"
    fi

  else
    info "Installing $name (Unix)"
    ln -sfn "$src" "$dest"
  fi

  ok "$name installed"
}

# ==================================================
# Validate sources
# ==================================================

[[ -f "$BASHRC_SRC" ]] || { err "Missing bashrc source"; exit 1; }
[[ -d "$BASHRCD_SRC" ]] || { err "Missing bashrc.d directory"; exit 1; }
[[ -f "$GITCONFIG_SRC" ]] || { err "Missing gitconfig source"; exit 1; }
[[ -f "$GITIGNORE_GLOBAL_SRC" ]] || { err "Missing gitignore_global source"; exit 1; }
[[ -d "$NVIM_SRC" ]] || { err "Missing nvim config directory"; exit 1; }

# ==================================================
# Install dotfiles
# ==================================================

info "Installing dotfiles"
info "Dotfiles directory: $DOTFILES_DIR"
log

install_symlink "$BASHRC_SRC" "$BASHRC_DEST" "bashrc"
install_symlink "$BASHRCD_SRC" "$BASHRCD_DEST" "bashrc.d"
install_symlink "$GITCONFIG_SRC" "$GITCONFIG_DEST" "gitconfig"
install_symlink "$GITIGNORE_GLOBAL_SRC" "$GITIGNORE_GLOBAL_DEST" "global gitignore"
install_symlink "$NVIM_SRC" "$NVIM_DEST" "neovim config"

# Configure git to use global gitignore
git config --global core.excludesfile "$GITIGNORE_GLOBAL_DEST"
ok "Git configured to use global gitignore"

# ==================================================
# Done
# ==================================================

log
ok "Installation complete"
info "Reload your shell with: source ~/.bashrc"
info "Or open a new terminal"
