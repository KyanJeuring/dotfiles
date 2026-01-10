# ==================================================
# Utility helpers
# ==================================================

### Remove deprecated functions automatically (warn once)
for fn in "${DEPRECATED_FUNCTIONS[@]}"; do
  if declare -F "$fn" >/dev/null; then
    warn "'$fn' is deprecated and has been removed"
    unset -f "$fn"
  fi
done

## Show an overview of custom bash commands
bashrc() {
  info "Custom bash commands"
  log

  shopt -s nullglob
  local files=("$HOME/.bashrc.d"/*.sh)
  shopt -u nullglob

  ((${#files[@]})) || return

  awk '
    FNR == 1 {
      section = ""
    }

    /^# / && !/^##/ && $0 !~ /^# [=-]+$/ {
      section = substr($0, 3)
      next
    }

    /^## / {
      desc = substr($0, 4)
      getline
      if ($0 ~ /^[a-zA-Z_][a-zA-Z0-9_-]*\(\)/) {
        name = $0
        sub(/\(\).*/, "", name)
        printf "[%s]\n%-22s %s\n", section, name, desc
      }
    }
  ' "${files[@]}" |
  awk '
    /^\[/ {
      if ($0 != last) {
        if (NR > 1) print ""
        print $0
        last = $0
      }
      next
    }
    { print "  " $0 }
  '
}

## Update dotfiles repository and reload bashrc
update-dotfiles() {
  local repo_dir install_script

  repo_dir="$HOME/dotfiles"
  install_script="$repo_dir/install.sh"

  if [[ ! -d "$repo_dir/.git" ]]; then
    err "Dotfiles repository not found at $repo_dir"
    err "Run the bootstrap installer first"
    return 1
  fi

  info "Updating dotfiles repository"
  info "Repo: $repo_dir"  

  (
    cd "$repo_dir"
    git pull --ff-only
  ) || {
    err "Git pull failed"
    return 1
  }

  if [[ ! -f "$install_script" ]]; then
    err "install.sh not found in dotfiles repository"
    return 1
  fi

  if [[ ! -x "$install_script" ]]; then
    chmod +x "$install_script"
  fi

  info "Running install.sh"
  "$install_script" || {
    err "install.sh failed"
    return 1
  }
}
