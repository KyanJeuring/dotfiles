#!/usr/bin/env bash
set -euo pipefail

# ==================================================
# Colors / output helpers
# ==================================================
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

OK="${GREEN}[OK]${NC}"
INFO="${BLUE}[INFO]${NC}"
WARN="${YELLOW}[WARN]${NC}"
ERR="${RED}[ERROR]${NC}"

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
    echo -e "$WARN Existing $(basename "$target") backed up and removed"
    echo -e "$INFO Backup created at: $(basename "$backup")"
  fi
}

is_windows() {
  [[ "$OS" == "Windows_NT" ]]
}

# ==================================================
# Start
# ==================================================
echo -e "$INFO Installing dotfiles"
echo -e "$INFO Dotfiles directory: $DOTFILES_DIR"
echo

# ==================================================
# Validate sources
# ==================================================
[[ -f "$BASHRC_SRC" ]] || { echo -e "$ERR Missing bashrc source"; exit 1; }
[[ -f "$GITCONFIG_SRC" ]] || { echo -e "$ERR Missing gitconfig source"; exit 1; }

# ==================================================
# Backup + remove existing configs
# ==================================================
backup_and_remove "$BASHRC_DEST"
backup_and_remove "$GITCONFIG_DEST"

# ==================================================
# Install bashrc
# ==================================================
if is_windows; then
  echo -e "$INFO Installing bashrc (Windows / CMD)"
  cmd.exe /c mklink "%USERPROFILE%\\.bashrc" "$(cygpath -w "$BASHRC_SRC")" >nul
else
  echo -e "$INFO Installing bashrc (Linux)"
  ln -s "$BASHRC_SRC" "$BASHRC_DEST"
fi

echo -e "$OK bashrc installed"

# ==================================================
# Install gitconfig
# ==================================================
if is_windows; then
  echo -e "$INFO Installing gitconfig (Windows / CMD)"
  cmd.exe /c mklink "%USERPROFILE%\\.gitconfig" "$(cygpath -w "$GITCONFIG_SRC")" >nul
else
  echo -e "$INFO Installing gitconfig (Linux)"
  ln -s "$GITCONFIG_SRC" "$GITCONFIG_DEST"
fi

echo -e "$OK gitconfig installed"

# ==================================================
# Done
# ==================================================
echo
echo -e "$OK Installation complete"
echo -e "$INFO Restart your shell or run: source ~/.bashrc"
