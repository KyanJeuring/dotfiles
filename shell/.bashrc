# ==================================================
# Bashrc – dotfiles managed
# ==================================================

# Prevent double-loading (important for subshells, SSH, etc.)
[[ -n "${__DOTFILES_BASHRC_LOADED:-}" ]] && return
__DOTFILES_BASHRC_LOADED=1

# ==================================================
# Load modular bash configuration
# ==================================================

BASHRC_D="$HOME/.bashrc.d"

if [[ -d "$BASHRC_D" ]]; then
  for file in "$BASHRC_D"/*.sh; do
    [[ -r "$file" ]] && source "$file"
  done
fi

# If launched from Windows Terminal (not SSH), start in C:
if [[ -n "$WT_SESSION" && -z "$SSH_CONNECTION" ]]; then
  cd /mnt/c/Users/kyanj
fi

