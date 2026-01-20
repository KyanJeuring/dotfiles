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

## Show known devices on the local network (ARP/neighbor cache)
netneighbors() {
  info "Known network devices (neighbor cache)"
  log

  if command -v ip >/dev/null 2>&1; then
    ip neigh show \
      | awk '
        $1 ~ /^[0-9]/ {
          printf "  %-16s  %-17s  %s\n", $1, $5, $NF
        }'
  elif command -v arp >/dev/null 2>&1; then
    arp -n \
      | awk '
        $1 ~ /^[0-9]/ {
          printf "  %-16s  %-17s  %s\n", $1, $3, $NF
        }'
  else
    err "Neither ip nor arp command available"
    return 1
  fi

  log
  warn "Only shows devices this machine has recently seen"
}

## Scan local network for connected devices
netscan() {
  info "Scanning local network for devices"
  log

  if ! command -v nmap >/dev/null 2>&1; then
    err "nmap is not installed"
    return 1
  fi

  local IFACE SUBNET
  IFACE="$(ip route | awk '/default/ {print $5; exit}')"
  SUBNET="$(ip -4 addr show "$IFACE" | awk '/inet / {print $2; exit}')"

  if [[ -z "$SUBNET" ]]; then
    err "Could not determine local subnet"
    return 1
  fi

  info "Interface : $IFACE"
  info "Subnet    : $SUBNET"
  warn "Active scan (ARP/ICMP)"
  log

  printf "  %-15s  %-15s  %-17s  %s\n" "IP" "Hostname" "MAC" "Manufacturer"
  printf "  %-15s  %-15s  %-17s  %s\n" \
    "---------------" "---------------" "-----------------" "----------------------------"

  if command -v sudo >/dev/null 2>&1; then
    sudo nmap -sn "$SUBNET"
  else
    nmap -sn "$SUBNET"
  fi |
  awk '
    /^Nmap scan report for/ {
      hostname="-"
      ip=$NF

      # Case: hostname present
      if ($5 ~ /\(/) {
        hostname=$5
        sub(/\(.*/, "", hostname)
        sub(/\)/, "", ip)
      }
    }
    /MAC Address:/ {
      mac=$3
      vendor=$4
      for (i=5; i<=NF; i++) vendor=vendor" "$i
      printf "  %-15s  %-15s  %-17s  %s\n", ip, hostname, mac, vendor
    }
  ' | sort -V

  log
  ok "Scan completed"
}

## Show known network devices and optionally run active scan
netwatch() {
  netneighbors
  read -rp "Run active network scan? [y/N]: " ans
  [[ "$ans" =~ ^[Yy]$ ]] && netscan
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

## Show local LAN IPv4 addresses
lanip() {
  info "Local IPv4 addresses"
  log

  ip -4 addr show \
    | awk '
      /inet / && !/127.0.0.1/ {
        printf "  %-18s  %s\n", $2, $NF
      }'

  log
}

## Show IP addresses
ipaddr() {
  info "IP addresses"
  log

  ip addr show \
    | awk '
      /^[0-9]+:/ {
        iface=$2; sub(":", "", iface)
        printf "[%s]\n", iface
      }
      /inet / {
        printf "  IPv4  %-18s\n", $2
      }
      /inet6 / {
        printf "  IPv6  %-18s\n", $2
      }'

  log
}

## Show routing table
iproute() {
  info "Routing table"
  log

  ip route show \
    | awk '
      {
        printf "  %-18s -> %s\n", $1, $0
      }'

  log
}

## Show listening ports
ports() {
  info "Listening ports"
  log

  ss -tulpn \
    | awk 'NR==1 {print "  " $0; next} {print "  " $0}'

  log
}

portsl() {
  info "Listening ports (LISTEN state)"
  log
  ss -tulpn state listening
  log
}

## Show public IPv4 address
pubip() {
  curl -fsS https://api.ipify.org || curl -fsS https://ifconfig.me || echo "IP unavailable"
}

## Show public IPv4 address and rough geolocation
pubipinfo() {
  if command -v jq >/dev/null 2>&1; then
    curl -fsS https://ipinfo.io 2>/dev/null | jq
  else
    curl -fsS https://ipinfo.io 2>/dev/null
  fi
}

## Show IP information for a specific IPv4 address
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
    TARGET_IP="$(pubip || true)"

    if [[ -z "$TARGET_IP" ]]; then
      err "Could not determine public IP"
      return 1
    fi

    if ! is_public_ipv4 "$TARGET_IP"; then
      err "Detected IP is not a valid public IPv4 address: $TARGET_IP"
      return 1
    fi

    info "Public IP information:"
    pubipinfo
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
# Curl utilities
# ==================================================

## Download file from URL with resume support
dload() {
  if [[ -z "${1:-}" ]]; then
    err "Usage: dload <url>"
    return 1
  fi

  curl -fL \
    --progress-bar \
    --retry 3 \
    --retry-delay 2 \
    --retry-connrefused \
    -C - \
    -O "$1"
}

## Make an API call with customizable options
apicall() {
  local method url data file
  local headers=()
  local raw=false dry_run=false
  local curl_opts=()

  if [[ $# -lt 2 ]]; then
    err "Usage: apicall <METHOD> <url> [options] [json]"
    return 1
  fi

  method="${1^^}"
  url="$2"
  shift 2

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f|--file)
        file="$2"
        shift 2
        ;;
      -H)
        headers+=("$2")
        shift 2
        ;;
      --raw)
        raw=true
        shift
        ;;
      --dry-run)
        dry_run=true
        shift
        ;;
      *)
        data="$1"
        shift
        ;;
    esac
  done

  if [[ "$url" == /* && -n "${API_BASE_URL:-}" ]]; then
    url="${API_BASE_URL%/}$url"
  fi

  if [[ -n "$file" ]]; then
    [[ -f "$file" ]] || {
      err "File not found: $file"
      return 1
    }
    data="$(cat "$file")"
  fi

  if [[ -z "$data" && ! -t 0 ]]; then
    data="$(cat)"
  fi

  case "$method" in
    GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS) ;;
    *)
      err "Unsupported HTTP method: $method"
      return 1
      ;;
  esac

  case "$method" in
    GET|HEAD|OPTIONS)
      if [[ -n "$data" ]]; then
        err "$method requests must not include a body"
        return 1
      fi
      ;;
  esac

  if [[ -n "$data" && "$raw" == false ]] && command -v jq >/dev/null 2>&1; then
    jq -e . >/dev/null 2>&1 <<<"$data" || {
      err "Invalid JSON body"
      return 1
    }
  fi

  curl_opts+=(
    -sS
    -L
    --fail-with-body
    --connect-timeout 5
    --max-time 30
    -X "$method"
    -H "User-Agent: apicall/1.0"
  )

  if [[ -n "${APICALL_TOKEN:-}" ]]; then
    curl_opts+=(-H "Authorization: Bearer $APICALL_TOKEN")
  fi

  if [[ -n "$data" ]]; then
    curl_opts+=(-H "Content-Type: application/json")
  fi

  for h in "${headers[@]}"; do
    curl_opts+=(-H "$h")
  done

  if [[ "$dry_run" == true ]]; then
    printf 'curl'
    printf ' %q' "${curl_opts[@]}"
    [[ -n "$data" ]] && printf ' -d %q' "$data"
    printf ' %q\n' "$url"
    return 0
  fi

  if [[ "$raw" == false && -n "$data" && $(command -v jq) ]]; then
    curl "${curl_opts[@]}" -d "$data" "$url" | jq
  elif [[ "$raw" == false && $(command -v jq) ]]; then
    curl "${curl_opts[@]}" "$url" | jq
  else
    if [[ -n "$data" ]]; then
      curl "${curl_opts[@]}" -d "$data" "$url"
    else
      curl "${curl_opts[@]}" "$url"
    fi
  fi
}

# ==================================================
# Weather utility
# ==================================================

## Show weather for a location (default: current location)
weather() {
  if [ "$#" -gt 1 ]; then
    err "Location contains spaces — use quotes"
    return 1
  fi

  local location label info city region country

  case "$1" in
    "" )
      info="$(curl -fsS https://ipinfo.io/json 2>/dev/null)" \
        || { warn "Location detection failed"; return 1; }

      city="$(printf '%s\n' "$info" | awk -F'"' '/"city"/{print $4}')"
      region="$(printf '%s\n' "$info" | awk -F'"' '/"region"/{print $4}')"
      country="$(printf '%s\n' "$info" | awk -F'"' '/"country"/{print $4}')"
      location="$(printf '%s\n' "$info" | awk -F'"' '/"loc"/{print $4}')"

      label="$city, $region, $country"
      ;;
    home )
      label="Emmen, Drenthe, NL"
      location="52.7858,6.8976"
      ;;
    * )
      label="$1"
      location="$1"
      ;;
  esac

  # URL-encode spaces for named locations
  location="${location// /%20}"

  info "Weather for $label"
  log

  curl -fsS "wttr.in/${location}?m" \
    | sed '/^Location:/d' \
    || warn "Weather unavailable"

  log
}
