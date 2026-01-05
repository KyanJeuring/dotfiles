# ==================================================
# File search & inspection (cross-platform)
# ==================================================

## Find files by name (case-insensitive)
ff() {
  [[ -z "$1" ]] && {
    err "Usage: ff <pattern>"
    return 1
  }
  find . -iname "*$1*" 2>/dev/null
}

## Search text in files (fallback-safe)
grepall() {
  [[ -z "$1" ]] && {
    err "Usage: grepall <text>"
    return 1
  }

  if command -v rg >/dev/null; then
    rg "$1"
  else
    grep -R "$1" .
  fi
}

## Show directory sizes (top-level only)
dus() {
  {
    du -sh . 2>/dev/null | sed 's|^\(.*\)[[:space:]]\+\.$|\1\t(total)|'
    du -sh ./* ./.??* 2>/dev/null
  } | sort -h
}

## Show largest files (top 20)
bigfiles() {
  find . -type f -log '%s\t%p\n' 2>/dev/null |
  sort -nr | head -n 20 |
  awk '{ printf "%8.1f MB  %s\n", $1/1024/1024, $2 }'
}

## Count files by extension
countfiles() {
  [[ -z "$1" ]] && {
    err "Usage: countfiles <ext>"
    return 1
  }
  find . -type f -name "*.$1" | wc -l
}

## Count lines of code
loc() {
  find . -type f ! -path "./.git/*" -exec wc -l {} + | tail -n 1
}

# ==================================================
# File access & editing (cross-platform)
# ==================================================

## Open file in default editor
edit() {
  "${EDITOR:-vi}" "$@"
}

## Print / view file safely (pager-aware)
catp() {
  if [ -t 1 ]; then
    cat "$@" | less
  else
    cat "$@"
  fi
}

# ==================================================
# File mutation & safety (cross-platform)
# ==================================================

## Backup a file or directory
bu() {
  local target="$1"

  [[ -z "$target" ]] && {
    err "Usage: bu <file|dir>"
    return 1
  }

  [[ ! -e "$target" ]] && {
    err "Target does not exist: $target"
    return 1
  }

  local backup="${target}.bak.$(date +%Y%m%d-%H%M%S)"

  cp -a "$target" "$backup"
  ok "Backup created: $backup"
}


## Restore a file or directory from backup
rbu() {
  local backup="$1"

  [[ -z "$backup" ]] && {
    err "Usage: rbu <file|dir>.bak.YYYYMMDD-HHMMSS"
    return 1
  }

  [[ ! -e "$backup" ]] && {
    err "Backup not found: $backup"
    return 1
  }

  local original="${backup%.bak.*}"

  if [[ -e "$original" ]]; then
    warn "Existing target will be overwritten: $original"
  fi

  cp -a "$backup" "$original"
  ok "Restored: $original"
}

## Remove files/directories safely
rmf() {
  [[ -z "$1" ]] && {
    err "Usage: rmf <file|dir> [...]"
    return 1
  }

  warn "This will permanently delete:"
  for item in "$@"; do
    log "  $item"
  done

  confirm "Continue?" || return 1

  rm -rf -- "$@"
  ok "Removed"
}

# ==================================================
# File permissions (cross-platform)
# ==================================================

## Make executable
x() {
  chmod +x "$@"
  ok "Made executable: $*"
}

# ==================================================
# Navigation commands (cross-platform)
# ==================================================

home() { cd "$HOME" || return 1; }

up() {
  local levels="${1:-1}"
  local path="."

  [[ ! "$levels" =~ ^[0-9]+$ ]] && {
    err "Argument must be a number"
    return 1
  }

  for ((i=0; i<levels; i++)); do
    path="$path/.."
  done

  cd "$path" || return 1
}

mkcd() {
  [[ -z "$1" ]] && {
    err "No directory specified"
    return 1
  }

  mkdir -p "$1" && cd "$1" || return 1
}

back() { cd - >/dev/null || return 1; }

root() {
  local r
  r=$(git rev-parse --show-toplevel 2>/dev/null) || {
    err "Not inside a git repository"
    return 1
  }
  cd "$r" || return 1
}
