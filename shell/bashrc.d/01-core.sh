# ==================================================
# Core state
# ==================================================

export EDITOR="nvim"
export VISUAL="nvim"

if [ -n "$NVIM" ]; then
  export GIT_EDITOR=vim
else
  export GIT_EDITOR=nvim
fi

DEPRECATED_FUNCTIONS=(
  deploy
  bashrc-update
  dotfiles-update
)
