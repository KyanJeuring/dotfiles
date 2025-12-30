#!/usr/bin/env bash
set -e

# ==================================================
# Output formatting (portable ANSI)
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

INFO="${BLUE}[INFO]${NC}"
OK="${GREEN}[OK]${NC}"
WARN="${YELLOW}[WARN]${NC}"
ERR="${RED}[ERROR]${NC}"

# ==================================================
# Helpers
# ==================================================

backup_and_remove() {
  local target="$1"

  if [[ -e "$target" || -L "$target" ]]; then
    local backup="${target}.bak.$(date +%Y%m%d-%H%M%S)"
    mv "$target" "$backup"
    echo -e "$WARN Existing $(basename "$target") backed up and removed"
    echo -e "$INFO Backup created: $(basename "$backup")"
  fi
}

link_linux() {
  local src="$1"
  local dest="$2"

  ln -s "$src" "$dest"
  echo -e "$OK Linked $(basename "$dest")"
}

link_windows_cmd() {
  local src="$1"
  local dest="$2"

  local src_win dest_win
  src_win="$(cygpath -w "$src")"
  dest_win="$(cygpath -w "$dest")"

  if cmd.exe /c "mklink \"$dest_win\" \"$src_win\"" >/dev/null 2>&1; then
    echo -e "$OK Linked $(basename "$dest") (via cmd)"
    return 0
  fi

  return 1
}

copy_fallback() {
  local src="$1"
  local dest="$2"

  cp "$src" "$dest"
  echo -e "$WARN Symlink unavailable — copied instead"
}

# ==================================================
# OS detection
# ==================================================

OS="linux"
case "$(uname -s)" in
  Linux*) OS="linux" ;;
  MINGW*|MSYS*|CYGWIN*) OS="windows" ;;
esac

echo -e "$INFO Detected OS: $OS"

# ==================================================
# Paths
# ==================================================

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="$HOME"

BASHRC_SRC="$DOTFILES_DIR/bashrc"
BASHRC_DEST="$HOME_DIR/.bashrc"
BASH_PROFILE="$HOME_DIR/.bash_profile"

# ==================================================
# Validate source
# ==================================================

if [[ ! -f "$BASHRC_SRC" ]]; then
  echo -e "$ERR bashrc not found in dotfiles repo"
  exit 1
fi

# ==================================================
# Install bashrc
# ==================================================

backup_and_remove "$BASHRC_DEST"

if [[ "$OS" == "linux" ]]; then
  link_linux "$BASHRC_SRC" "$BASHRC_DEST"

elif [[ "$OS" == "windows" ]]; then
  if ! link_windows_cmd "$BASHRC_SRC" "$BASHRC_DEST"; then
    copy_fallback "$BASHRC_SRC" "$BASHRC_DEST"
  fi
fi

# ==================================================
# Ensure bash_profile sources bashrc
# ==================================================

if [[ ! -f "$BASH_PROFILE" ]]; then
  echo '[[ -f ~/.bashrc ]] && source ~/.bashrc' > "$BASH_PROFILE"
  echo -e "$OK Created .bash_profile"
elif ! grep -q "source ~/.bashrc" "$BASH_PROFILE"; then
  echo '[[ -f ~/.bashrc ]] && source ~/.bashrc' >> "$BASH_PROFILE"
  echo -e "$OK Updated .bash_profile"
else
  echo -e "$INFO .bash_profile already configured"
fi

# ==================================================
# Done
# ==================================================

echo -e "$OK Dotfiles installation complete"
echo -e "$INFO Restart your shell or run: source ~/.bashrc"
