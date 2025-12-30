#!/usr/bin/env bash
set -euo pipefail

# ==================================================
# Output helpers (portable)
# ==================================================

log() {
  printf '%b\n' "$1"
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
info "This script installs dotfiles by creating symbolic links"

# ==================================================
# Paths
# ==================================================
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BASHRC_SRC="$DOTFILES_DIR/bashrc"
GITCONFIG_SRC="$DOTFILES_DIR/gitconfig"

BASHRC_DEST="$HOME/.bashrc"
GITCONFIG_DEST="$HOME/.gitconfig"

# ==================================================
# Helpers
# ==================================================
backup_and_remove() {
  local target="$1"

  if [[ -e "$target" || -L "$target" ]]; then
    local backup="${target}.bak.$(date +%Y%m%d-%H%M%S)"
    mv "$target" "$backup"
    warn "Existing $(basename "$target") backed up"
    info "Backup created at: $(basename "$backup")"
  fi
}

is_windows() {
  [[ "${OS:-}" == "Windows_NT" ]]
}

# ==================================================
# Start
# ==================================================
info "Installing dotfiles"
info "Dotfiles directory: $DOTFILES_DIR"
log

# ==================================================
# Validate sources
# ==================================================
[[ -f "$BASHRC_SRC" ]] || { err "Missing bashrc source"; exit 1; }
[[ -f "$GITCONFIG_SRC" ]] || { err "Missing gitconfig source"; exit 1; }

# ==================================================
# Backup existing configs
# ==================================================
backup_and_remove "$BASHRC_DEST"
backup_and_remove "$GITCONFIG_DEST"

# ==================================================
# Install bashrc
# ==================================================
if is_windows; then
  info "Installing bashrc (Windows)"
  cmd.exe /c mklink "%USERPROFILE%\\.bashrc" "$(cygpath -w "$BASHRC_SRC")" >nul
else
  info "Installing bashrc (Linux)"
  ln -sf "$BASHRC_SRC" "$BASHRC_DEST"
fi

ok "bashrc installed"

# ==================================================
# Install gitconfig
# ==================================================
if is_windows; then
  info "Installing gitconfig (Windows)"
  cmd.exe /c mklink "%USERPROFILE%\\.gitconfig" "$(cygpath -w "$GITCONFIG_SRC")" >nul
else
  info "Installing gitconfig (Linux)"
  ln -sf "$GITCONFIG_SRC" "$GITCONFIG_DEST"
fi

ok "gitconfig installed"

# ==================================================
# Done
# ==================================================
log
ok "Installation complete"
info "Reload your shell with: source ~/.bashrc"
info "Or open a new terminal"
