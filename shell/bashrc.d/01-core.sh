# ==================================================
# Core state
# ==================================================

if command -v nvim >/dev/null 2>&1; then
  VISUAL=nvim
elif command -v vim >/dev/null 2>&1; then
  VISUAL=vim
elif command -v vi >/dev/null 2>&1; then
  VISUAL=vi
else
  VISUAL=nano
fi

export VISUAL

if command -v vim >/dev/null 2>&1; then
  export EDITOR=vim
elif command -v vi >/dev/null 2>&1; then
  export EDITOR=vi
else
  export EDITOR=nano
fi

DEPRECATED_FUNCTIONS=(
  deploy
  bashrc-update
  dotfiles-update
  drestart
  dresetstack
  update-dotfiles
  update_dotfiles
  is-public-ipv4
  git-host-status
  grescue
  root
  getjson
  netdevices
  usb-list
  usb-mount
  usb-umount
  usb-unmount
  usb-eject
  usb-auto
)
