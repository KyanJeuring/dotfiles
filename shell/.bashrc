# ==================================================
# Bashrc – dotfiles managed
# ==================================================

# Prevent double-loading (important for subshells, SSH, etc.)
[[ -n "${__DOTFILES_BASHRC_LOADED:-}" ]] && return
__DOTFILES_BASHRC_LOADED=1

# ==================================================
# Directory stack enhancements
# ==================================================

if [[ $- == *i* ]]; then
  DIRSTACKSIZE=20

  cd() {
    [[ "$1" == "." ]] && return 0
    builtin cd "$@" || return
    pushd . >/dev/null
  }
fi

# ==================================================
# Load modular bash configuration
# ==================================================

BASHRC_D="$HOME/.bashrc.d"

if [[ -d "$BASHRC_D" ]]; then
  for file in "$BASHRC_D"/*.sh; do
    [[ -r "$file" ]] && source "$file"
  done
fi
