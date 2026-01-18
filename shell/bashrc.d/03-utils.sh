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
dotupdate() {
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
    err "Usage: ipinfo <ip-address>"
    return 1
  fi

  if command -v jq >/dev/null 2>&1; then
    curl -fsS "https://ipinfo.io/$1" 2>/dev/null | jq
  else
    curl -fsS "https://ipinfo.io/$1" 2>/dev/null
  fi
}

## Show HTTP status code for a URL
httpstatus() {
  if [ -z "$1" ]; then
    err "Usage: httpstatus <url>"
    return 1
  fi
  curl -o /dev/null -s -w "%{http_code}\n" "$1"
}

## Show HTTP response headers
httpheaders() {
  if [ -z "$1" ]; then
    err "Usage: httpheaders <url>"
    return 1
  fi
  curl -sI "$1"
}

## Resolve a domain via HTTP request
dnscheck() {
  if [ -z "$1" ]; then
    err "Usage: dnscheck <domain>"
    return 1
  fi
  ( curl -sI "https://$1" || curl -sI "http://$1" ) | head -n 1
}

## Scan open TCP ports on a public IP (default: self)
## Scan open TCP ports on a public IPv4 address (default: self)
portscan() {
  info "Starting port scan utility"
  log

  if ! command -v nmap >/dev/null 2>&1; then
    err "nmap is not installed"
    return 1
  fi

  local TARGET_IP

  if [[ -n "${1:-}" ]]; then
    TARGET_IP="$1"

    if ! is_public_ipv4 "$TARGET_IP"; then
      err "Invalid target IP: $TARGET_IP"
      err "Private, loopback, and link-local IPs are not allowed"
      return 1
    fi

    info "Target IP information:"
    ipinfo "$TARGET_IP"
    log
  else
    info "Detecting public IP..."
    TARGET_IP="$(myip || true)"

    if [[ -z "$TARGET_IP" ]]; then
      err "Could not determine public IP"
      return 1
    fi

    if ! is_public_ipv4 "$TARGET_IP"; then
      err "Detected IP is not a valid public IPv4 address: $TARGET_IP"
      return 1
    fi

    info "Public IP information:"
    myipinfo
    log
  fi

  info "Select scan type:"
  info "  1) Full scan (all TCP ports)"
  info "  2) Targeted scan (specific ports)"
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
      info "Running FULL TCP port scan on $TARGET_IP"
      info "Scanning all 65535 TCP ports"
      warn "This may take several minutes to complete"
      log
      $NMAP_CMD -p- "$TARGET_IP"
      ;;
    2)
      local PORTS
      read -rp "Enter ports (e.g. 22,80,443,2222): " PORTS

      if [[ -z "${PORTS// }" ]]; then
        err "No ports specified"
        return 1
      fi

      log
      info "Running TARGETED TCP port scan on $TARGET_IP"
      info "Scanning the following ports: $PORTS"
      log
      $NMAP_CMD -p "$PORTS" "$TARGET_IP"
      ;;
    *)
      err "Invalid option"
      return 1
      ;;
  esac

  ok "Scan completed"
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

## Show weather for a location (default: current location)
weather() {
  local location="${1:-}"
  curl -fsS "wttr.in/${location}?m" || echo "Weather unavailable"
}
