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

# ==================================================
# Network utilities
# ==================================================

## Check internet connectivity
netcheck() {
  curl -fsS https://1.1.1.1 >/dev/null && echo "Online" || echo "Offline"
}

## Show current UTC time from internet
utctime() {
  curl -fsS https://timeapi.io/api/Time/current/zone?timeZone=UTC 2>/dev/null |
    jq -r '.dateTime' 2>/dev/null && return
  curl -fsS https://worldtimeapi.org/api/timezone/Etc/UTC 2>/dev/null |
    jq -r '.utc_datetime' 2>/dev/null && return
  warn "Using local system UTC time"
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

## Show public IP address
myip() {
  curl -fsS https://api.ipify.org || curl -fsS https://ifconfig.me || echo "IP unavailable"
}

## Show public IP and rough geolocation
myipinfo() {
  if command -v jq >/dev/null 2>&1; then
    curl -fsS https://ipinfo.io 2>/dev/null | jq
  else
    curl -fsS https://ipinfo.io 2>/dev/null
  fi
}

## Show IP info for a specific IP address
ipinfo() {
  if [ -z "$1" ]; then
    echo "Usage: ipinfo <ip-address>"
    return 1
  fi

  if command -v jq >/dev/null 2>&1; then
    curl -fsS "https://ipinfo.io/$1" 2>/dev/null | jq
  else
    curl -fsS "https://ipinfo.io/$1" 2>/dev/null
  fi
}

## Check if an IPv4 address is public
is-public-ipv4() {
  if [ -z "$1" ]; then
    echo "Usage: is-public-ipv4 <ip-address>"
    return 1
  fi

  local ip="$1"

  # Basic IPv4 format check
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1

  # Split octets
  IFS='.' read -r o1 o2 o3 o4 <<< "$ip"

  # Each octet must be 0–255
  for o in "$o1" "$o2" "$o3" "$o4"; do
    ((o >= 0 && o <= 255)) || return 1
  done

  # Reject loopback
  ((o1 == 127)) && return 1

  # Reject private ranges
  ((o1 == 10)) && return 1
  ((o1 == 192 && o2 == 168)) && return 1
  ((o1 == 172 && o2 >= 16 && o2 <= 31)) && return 1

  # Reject link-local
  ((o1 == 169 && o2 == 254)) && return 1

  return 0
}

## Show HTTP status code for a URL
httpstatus() {
  if [ -z "$1" ]; then
    echo "Usage: httpstatus <url>"
    return 1
  fi
  curl -o /dev/null -s -w "%{http_code}\n" "$1"
}

## Show HTTP response headers
httpheaders() {
  if [ -z "$1" ]; then
    echo "Usage: httpheaders <url>"
    return 1
  fi
  curl -sI "$1"
}

## Resolve a domain via HTTP request
dnscheck() {
  if [ -z "$1" ]; then
    echo "Usage: dnscheck <domain>"
    return 1
  fi
  ( curl -sI "https://$1" || curl -sI "http://$1" ) | head -n 1
}

## Scan open TCP ports on a public IP (default: self)
portscan() {
  log "$INFO Starting port scan utility"
  log

  if ! command -v nmap >/dev/null 2>&1; then
    log "$ERR nmap is not installed"
    return 1
  fi

  local TARGET_IP

  if [[ -n "${1:-}" ]]; then
    TARGET_IP="$1"

    if ! is-public-ipv4 "$TARGET_IP"; then
      log "$ERR Invalid target IP: $TARGET_IP"
      log "$ERR Private, loopback, and link-local IPs are not allowed"
      return 1
    fi

    log "$WARN You are about to scan a user-specified PUBLIC IP: $TARGET_IP"
    log "$WARN Only scan systems you own or have permission to test"
    confirm "Continue?" || return 1
  else
    log "$INFO Detecting public IP..."
    TARGET_IP="$(myip || true)"

    if [[ -z "$TARGET_IP" ]]; then
      log "$ERR Could not determine public IP"
      return 1
    fi

    if ! is-public-ipv4 "$TARGET_IP"; then
      log "$ERR Detected IP is not a valid public IPv4 address: $TARGET_IP"
      return 1
    fi

    log "$OK Public IP detected: $TARGET_IP"
    log
    log "$INFO Public IP information:"
    myipinfo
    log
  fi

  log "$INFO Select scan type:"
  log "  1) Full scan (all TCP ports)"
  log "  2) Targeted scan (specific ports)"
  log

  local CHOICE
  read -rp "Enter choice [1-2] (default: 2): " CHOICE
  CHOICE="${CHOICE:-2}"
  log

  local NMAP_CMD="nmap"
  if command -v sudo >/dev/null 2>&1; then
    NMAP_CMD="sudo nmap"
  fi

  case "$CHOICE" in
    1)
      log "$INFO Running FULL TCP port scan on $TARGET_IP"
      log "$INFO Scanning all 65535 TCP ports"
      log "$WARN This may take several minutes to complete"
      log
      $NMAP_CMD -p- "$TARGET_IP"
      ;;
    2)
      local PORTS
      read -rp "Enter ports (e.g. 22,80,443,2222): " PORTS
      if [[ -z "${PORTS// }" ]]; then
        log "$ERR No ports specified"
        return 1
      fi
      log
      log "$INFO Running TARGETED TCP port scan on $TARGET_IP"
      log "$INFO Scanning the following ports: $PORTS"
      log
      $NMAP_CMD -p "$PORTS" "$TARGET_IP"
      ;;
    *)
      log "$ERR Invalid option"
      return 1
      ;;
  esac

  log "$OK Scan completed"
  log
}

# ==================================================
# API testing utilities
# ==================================================

## Fetch JSON from URL (pretty if jq is available)
getjson() {
  if [ -z "$1" ]; then
    echo "Usage: getjson <url>"
    return 1
  fi

  if command -v jq >/dev/null 2>&1; then
    curl -fsS "$1" | jq
  else
    curl -fsS "$1"
  fi
}

# ==================================================
# Weather utility
# ==================================================

weather() {
  local location="${1:-}"
  curl -fsS "wttr.in/${location}?m" || echo "Weather unavailable"
}
