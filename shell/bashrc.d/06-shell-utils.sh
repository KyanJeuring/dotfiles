# ==================================================
# File search & inspection
# ==================================================

## Find files by name (case-insensitive)
ff() {
  [[ -z "$1" ]] && { err "Usage: ff <pattern>"; return 1; }
  find . -iname "*$1*" 2>/dev/null
}

## Fuzzy find files
ffz() {
  command -v fzf >/dev/null || {
    err "fzf not installed"
    return 1
  }

  [[ "$(pwd)" == "$HOME" ]] && {
    warn "Running in HOME — this may be slow"
  }

  find . -type f 2>/dev/null | fzf
}


## Search text in files (ripgrep fallback-safe)
grepall() {
  [[ -z "$1" ]] && { err "Usage: grepall <text>"; return 1; }

  if command -v rg >/dev/null; then
    rg "$1"
  else
    grep -R "$1" .
  fi
}

## Show directory sizes (top-level)
dus() {
  {
    du -sh . 2>/dev/null | sed 's|^\(.*\)[[:space:]]\+\.$|\1\t(total)|'
    du -sh ./* ./.??* 2>/dev/null
  } | sort -h
}

## Show largest files
bigfiles() {
  find . -type f -log '%s\t%p\n' 2>/dev/null |
  sort -nr | head -n 20 |
  awk '{ printf "%8.1f MB  %s\n", $1/1024/1024, $2 }'
}

## Count files by extension
countfiles() {
  [[ -z "$1" ]] && { err "Usage: countfiles <ext>"; return 1; }
  find . -type f -name "*.$1" | wc -l
}

## Count lines of code
loc() {
  find . -type f ! -path "./.git/*" -exec wc -l {} + | tail -n 1
}

# ==================================================
# File access & editing
# ==================================================

## Open file in editor
edit() {
  "${EDITOR:-vi}" "$@"
}

## Pager-aware cat
catp() {
  if [ -t 1 ]; then
    cat "$@" | less
  else
    cat "$@"
  fi
}

# ==================================================
# File mutation & safety
# ==================================================

## Backup file or directory
bu() {
  local target="$1"
  [[ -z "$target" ]] && { err "Usage: bu <file|dir>"; return 1; }
  [[ ! -e "$target" ]] && { err "Target does not exist: $target"; return 1; }

  local backup="${target}.bak.$(date +%Y%m%d-%H%M%S)"
  cp -a "$target" "$backup"
  ok "Backup created: $backup"
}

## Restore backup
rbu() {
  local backup="$1"
  [[ -z "$backup" ]] && { err "Usage: rbu <backup>"; return 1; }
  [[ ! -e "$backup" ]] && { err "Backup not found: $backup"; return 1; }

  local original="${backup%.bak.*}"
  [[ -e "$original" ]] && warn "Existing target will be overwritten: $original"

  cp -a "$backup" "$original"
  ok "Restored: $original"
}

## Rename safely
ren() {
  [[ $# -ne 2 ]] && { err "Usage: ren <source> <new-name>"; return 1; }

  local src="$1" dst="$2"
  [[ ! -e "$src" ]] && { err "Source does not exist: $src"; return 1; }

  [[ -e "$dst" ]] && {
    warn "Target exists: $dst"
    confirm "Overwrite?" || return 1
  }

  mv -i -- "$src" "$dst"
  ok "Renamed: $src → $dst"
}

## Move safely
mvf() {
  [[ $# -lt 2 ]] && { err "Usage: mvf <source> [...] <destination>"; return 1; }

  local dest="${@: -1}"
  local sources=("${@:1:$#-1}")

  [[ ! -d "$dest" ]] && { err "Destination is not a directory: $dest"; return 1; }

  warn "This will move:"
  for s in "${sources[@]}"; do log "  $s"; done
  log "→ $dest"

  confirm "Continue?" || return 1

  mv -i -- "${sources[@]}" "$dest"
  ok "Move complete"
}

## Remove safely
rmf() {
  [[ -z "$1" ]] && { err "Usage: rmf <file|dir> [...]"; return 1; }

  warn "This will permanently delete:"
  for item in "$@"; do log "  $item"; done

  confirm "Continue?" || return 1

  rm -rf -- "$@"
  ok "Removed"
}

# ==================================================
# File permissions
# ==================================================

## Make executable
x() {
  chmod +x "$@"
  ok "Made executable: $*"
}

# ==================================================
# File encryption utilities
# ==================================================

## Encrypt file
encfile() {
  [[ $# -ne 1 ]] && { err "Usage: encfile <file>"; return 1; }

  local infile="$1"
  local base encfile zipfile readme
  local pass confirm ans

  base="$(basename "$infile")"
  encfile="${base}.enc"
  zipfile="${base}.encrypted.zip"
  readme="README.txt"

  [[ -f "$infile" ]] || { err "File not found: $infile"; return 1; }
  [[ -e "$encfile" ]] && { err "Output exists: $encfile"; return 1; }
  [[ -e "$zipfile" ]] && { err "Output exists: $zipfile"; return 1; }

  read -rsp "Encryption password: " pass; echo
  read -rsp "Confirm password: " confirm; echo
  [[ "$pass" != "$confirm" ]] && { err "Passwords do not match"; return 1; }

  printf '%s' "$pass" | openssl enc -aes-256-cbc -pbkdf2 -salt \
    -pass stdin \
    -in "$infile" \
    -out "$encfile" || return 1

  if ! printf '%s' "$pass" | openssl enc -aes-256-cbc -pbkdf2 -d \
        -pass stdin \
        -in "$encfile" \
        -out /dev/null; then
    err "Verification failed — original kept"
    rm -f "$encfile"
    return 1
  fi

  rm "$infile"
  ok "Encrypted: $encfile (original removed)"

  read -rp "Bundle encrypted file with README into ZIP? [y/N]: " ans
  [[ ! "$ans" =~ ^[Yy]$ ]] && return 0

  cat > "$readme" <<EOF
This file was encrypted using OpenSSL (AES-256-CBC).

You need:
- OpenSSL installed
- The password (shared separately)

To decrypt on Linux / macOS / WSL:

  openssl enc -aes-256-cbc -pbkdf2 -d -in $encfile -out $base

Notes:
- The password is case-sensitive
- You can retry if you mistype the password
- Losing the password means the file cannot be recovered
EOF

  zip -q "$zipfile" "$encfile" "$readme"

  rm "$encfile" "$readme"

  ok "Encrypted and bundled: $zipfile"
}

## Decrypt file
decfile() {
  [[ $# -ne 1 ]] && { err "Usage: decfile <file.enc>"; return 1; }

  local infile="$1"
  local outfile="${infile%.enc}"
  local pass

  [[ -f "$infile" ]] || { err "File not found: $infile"; return 1; }
  [[ "$infile" == "$outfile" ]] && { err "Input must end with .enc"; return 1; }
  [[ -e "$outfile" ]] && { err "Output exists: $outfile"; return 1; }

  read -rsp "Decryption password: " pass
  echo

  if ! printf '%s' "$pass" | openssl enc -aes-256-cbc -pbkdf2 -d \
        -pass stdin \
        -in "$infile" \
        -out "$outfile"; then
    rm -f "$outfile"
    err "Decryption failed (wrong password or corrupted file)"
    return 1
  fi

  ok "Decrypted: $outfile"

  read -rp "Delete encrypted file '$infile'? [y/N]: " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    rm "$infile"
    ok "Encrypted file deleted"
  else
    info "Encrypted file kept"
  fi
}

# ==================================================
# Navigation helpers
# ==================================================

home() { cd "$HOME" || return 1; }

up() {
  local levels="${1:-1}"
  [[ ! "$levels" =~ ^[0-9]+$ ]] && { err "Argument must be a number"; return 1; }

  local path="."
  for ((i=0; i<levels; i++)); do path="$path/.."; done
  cd "$path" || return 1
}

mkcd() {
  [[ -z "$1" ]] && { err "No directory specified"; return 1; }
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
