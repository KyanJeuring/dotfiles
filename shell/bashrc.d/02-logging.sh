# ==================================================
# Output helpers (portable)
# ==================================================

log() {
  printf '%b\n' "${1:-}"
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

confirm() {
  read -rp "$1 (y/N): " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

is_public_ipv4() {
  local ip="$1"

  [[ -n "$ip" ]] || return 1
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1

  IFS='.' read -r o1 o2 o3 o4 <<< "$ip"

  for o in "$o1" "$o2" "$o3" "$o4"; do
    ((o >= 0 && o <= 255)) || return 1
  done

  ((o1 == 127)) && return 1
  ((o1 == 10)) && return 1
  ((o1 == 192 && o2 == 168)) && return 1
  ((o1 == 172 && o2 >= 16 && o2 <= 31)) && return 1
  ((o1 == 169 && o2 == 254)) && return 1

  return 0
}
