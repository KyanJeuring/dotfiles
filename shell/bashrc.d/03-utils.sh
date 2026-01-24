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
    # Detect top separator
    /^# [=]{5,}$/ {
      if (prev_was_sep) {
        prev_was_sep = 0
      } else {
        prev_was_sep = 1
      }
      next
    }

    # Capture section name only if surrounded by separators
    prev_was_sep && /^# / {
      section = substr($0, 3)
      prev_was_sep = 0
      in_section = 1
      next
    }

    # Reset if anything else appears
    {
      prev_was_sep = 0
    }

    # Command description
    /^## / && in_section {
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

## Show network interfaces
netifaces() {
  info "Network interfaces"
  log

  printf "  %-10s %-8s %-10s\n" "Interface" "State" "Type"
  printf "  %-10s %-8s %-10s\n" "---------" "-----" "----"

  ip -o link show | awk -F': ' '{print $2}' | while read -r iface; do
    state="$(cat /sys/class/net/$iface/operstate 2>/dev/null)"
    if [[ "$iface" =~ ^wl ]]; then
      type="Wi-Fi"
    elif [[ "$iface" =~ ^en ]]; then
      type="Ethernet"
    else
      type="Other"
    fi
    printf "  %-10s %-8s %-10s\n" "$iface" "$state" "$type"
  done

  log
}

### Get default Wi-Fi interface name
_wifi_iface() {
  ip -o link show | awk -F': ' '$2 ~ /^wl/ {print $2; exit}'
}

### Get default Ethernet interface name
_eth_iface() {
  ip -o link show | awk -F': ' '$2 ~ /^e/ {print $2; exit}'
}

## Show Wi-Fi status
netwifi() {
  local iface="$(_wifi_iface)"
  [[ -z "$iface" ]] && { warn "No Wi-Fi interface found"; return 1; }

  info "Wi-Fi status ($iface)"
  log
  iw dev "$iface" link || warn "Not connected"
  log
}

## Scan for available Wi-Fi networks
netwifiscan() {
  local iface="$(_wifi_iface)"
  [[ -z "$iface" ]] && { err "No Wi-Fi interface found"; return 1; }

  info "Scanning Wi-Fi networks ($iface)"
  warn "Active scan"
  log

  sudo iw dev "$iface" scan |
    awk -F: '
      /SSID/   {ssid=$2}
      /signal/ {printf "  %-30s %s\n", ssid, $2}
    '

  log
}

## Connect to Wi-Fi network
netwificonnect() {
  local iface ssid pass
  iface="$(_wifi_iface)"
  ssid="${1:-}"
  pass="${2:-}"

  [[ -z "$iface" ]] && { err "No Wi-Fi interface found"; return 1; }
  [[ -z "$ssid"  ]] && { err "Usage: netwificonnect <SSID> [password]"; return 1; }

  info "Resetting Wi-Fi state ($iface)"
  log

  # Hard reset (safe & idempotent)
  sudo killall wpa_supplicant 2>/dev/null || true
  sudo dhclient -r "$iface" 2>/dev/null || true
  sudo ip addr flush dev "$iface"
  sudo ip link set "$iface" down
  sleep 1
  sudo ip link set "$iface" up

  info "Connecting to Wi-Fi"
  info "SSID: $ssid"
  log

  if [[ -n "$pass" ]]; then
    wpa_passphrase "$ssid" "$pass" |
      sudo tee /etc/wpa_supplicant/wpa_supplicant.conf >/dev/null
  fi

  sudo wpa_supplicant -B -i "$iface" -c /etc/wpa_supplicant/wpa_supplicant.conf
  sudo dhclient "$iface"

  ok "Wi-Fi connected"
  log
}

## Disconnect from Wi-Fi network
netwifidisconnect() {
  local iface="$(_wifi_iface)"
  [[ -z "$iface" ]] && { err "No Wi-Fi interface found"; return 1; }

  info "Disconnecting Wi-Fi ($iface)"
  log

  sudo killall wpa_supplicant 2>/dev/null || true
  sudo dhclient -r "$iface" 2>/dev/null || true
  sudo ip addr flush dev "$iface"
  sudo ip link set "$iface" down

  ok "Wi-Fi disconnected"
  log
}


## Show Ethernet status
neteth() {
  local iface="$(_eth_iface)"
  [[ -z "$iface" ]] && { warn "No Ethernet interface found"; return 1; }

  info "Ethernet status ($iface)"
  log

  ip -4 addr show "$iface" | awk '/inet /{print "  IP:", $2}'
  log
}

## Bring Ethernet interface up
netethup() {
  local iface="$(_eth_iface)"
  [[ -z "$iface" ]] && { err "No Ethernet interface found"; return 1; }

  info "Bringing Ethernet up ($iface)"
  log

  sudo ip link set "$iface" up
  sudo dhclient "$iface"

  ok "Ethernet up"
  log
}

## Bring Ethernet interface down
netethdown() {
  local iface="$(_eth_iface)"
  [[ -z "$iface" ]] && { err "No Ethernet interface found"; return 1; }

  info "Bringing Ethernet down ($iface)"
  log

  sudo dhclient -r "$iface" 2>/dev/null || true
  sudo ip link set "$iface" down

  ok "Ethernet down"
  log
}

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

### Edit netscan alias file for current subnet
_netscan_edit_aliases() {
  local IFACE NET_ID GW_IP GW_MAC NET_ID_FILE ALIAS_FILE EDITOR_CMD

  mkdir -p "$HOME/.config/netaliases"

  IFACE="$(ip route | awk '/default/ {print $5; exit}')"
  [[ -z "$IFACE" ]] && { err "Could not determine interface"; return 1; }

  NET_ID="$(ip -4 route show dev "$IFACE" | awk '/proto kernel/ {print $1; exit}')"
  GW_IP="$(ip route | awk '/default/ {print $3; exit}')"
  GW_MAC="$(ip neigh show "$GW_IP" | awk '{print $5; exit}')"

  NET_ID_FILE="${NET_ID//\//_}__${GW_MAC//:/}"
  ALIAS_FILE="$HOME/.config/netaliases/$NET_ID_FILE"

  if [[ ! -f "$ALIAS_FILE" ]]; then
    cat >"$ALIAS_FILE" <<EOF
# netscan aliases
# Interface: $IFACE | Subnet: $NET_ID | Gateway: $GW_IP ($GW_MAC)
#
# Format:
#   <ip> <hostname> [type]
#
# Use '-' to keep detected hostname but override type.
# Lines starting with '#' are ignored.
EOF
  fi

  "${EDITOR:-nano}" "$ALIAS_FILE"
}

### netscan for Windows systems (Git Bash)
_netscan_windows() {
  info "Scanning local network for devices"
  log
  info "Environment : Windows (Git Bash)"
  warn "Using Windows host network"
  log

  command -v nmap >/dev/null || { err "nmap is not installed"; return 1; }

  if [[ -t 1 ]]; then
    HEADER="\033[0;34m\033[1m"
    RED="\033[0;31m\033[1m"
    RESET="\033[0m"
  else
    HEADER=""; RED=""; RESET=""
  fi

  local IP CIDR SUBNET

  IP="$(powershell.exe -NoProfile -Command '
    $r = Get-NetRoute -DestinationPrefix "0.0.0.0/0" |
         Sort-Object RouteMetric,InterfaceMetric |
         Select-Object -First 1
    (Get-NetIPAddress -InterfaceIndex $r.InterfaceIndex -AddressFamily IPv4 |
     Where-Object { $_.IPAddress -notlike "169.254*" })[0].IPAddress
  ' | tr -d "\r")"

  CIDR="$(powershell.exe -NoProfile -Command '
    $r = Get-NetRoute -DestinationPrefix "0.0.0.0/0" |
         Sort-Object RouteMetric,InterfaceMetric |
         Select-Object -First 1
    (Get-NetIPAddress -InterfaceIndex $r.InterfaceIndex -AddressFamily IPv4 |
     Where-Object { $_.IPAddress -notlike "169.254*" })[0].PrefixLength
  ' | tr -d "\r")"

  SUBNET="$IP/$CIDR"

  info "Subnet    : $SUBNET"
  warn "Active scan (ICMP)"
  log

  printf "  | ${HEADER}%-15s${RESET} | ${HEADER}%-32s${RESET} | ${HEADER}%-10s${RESET} | ${HEADER}%-17s${RESET} | ${HEADER}%-36s${RESET} |\n" \
    "IP" "Hostname" "Type" "MAC" "Manufacturer"

  printf "  | %-15s | %-32s | %-10s | %-17s | %-36s |\n" \
    "---------------" "--------------------------------" "----------" "-----------------" "------------------------------------"

  local ARP
  ARP="$(powershell.exe -NoProfile -Command '
    Get-NetNeighbor -AddressFamily IPv4 |
    Where-Object { $_.State -eq "Reachable" } |
    ForEach-Object { "$($_.IPAddress) $($_.LinkLayerAddress)" }
  ' | tr -d "\r")"

  nmap -sn "$SUBNET" |
  awk -v ARP="$ARP" -v RED="$RED" -v RESET="$RESET" '
    BEGIN {
      n = split(ARP, a, "\n")
      for (i=1; i<=n; i++) {
        split(a[i], f, " ")
        mac[f[1]] = f[2]
      }
    }

    function classify(host, vendor) {
      h = tolower(host)

      if (h ~ /(proxmox|pve|lxc|kvm)/) return "Server"
      if (h ~ /(nas|storage)/) return "Storage"
      if (h ~ /(print|printer|mfc|brother|epson|canon)/) return "Printer"
      if (h ~ /(cam|camera|nvr)/) return "Camera"
      if (h ~ /(switch|router|firewall|ap)/) return "Network"
      if (h ~ /(tv|smarttv|chromecast|roku)/) return "TV/Media"
      if (h ~ /(laptop|desktop|pc|workstation|notebook|macbook)/) return "Computer"

      if (h ~ /(iphone|ipad|pixel)/) return "Phone"
      if (h ~ /(galaxy|s[0-9]{2}|note[0-9]?)/) return "Phone"
      if (h ~ /(redmi|xiaomi|mi[0-9])/ ) return "Phone"
      if (h ~ /(oneplus|oppo|realme)/) return "Phone"
      if (h ~ /(huawei|honor|sony|xperia|lg|htc)/) return "Phone"

      return "Unknown"
    }

    function trunc(s,w){ return (length(s)>w)?substr(s,1,w-1)"…":s }

    /^Nmap scan report for/ {
      hostname="[UNKNOWN]"
      ip=$NF
      if ($0 ~ /\(/) {
        match($0,/for ([^ ]+) \(([^)]+)\)/,m)
        hostname=m[1]; ip=m[2]
      }
    }

    /Host is up/ {
      type = classify(hostname, "")
      hc = sprintf("%-32s", trunc(hostname,32))

      if (hostname=="[UNKNOWN]" && RED!="")
        sub(/^\[UNKNOWN\]/,RED"[UNKNOWN]"RESET,hc)

      printf "  | %-15s | %s | %-10s | %-17s | %-36s |\n",
        ip,
        hc,
        type,
        (ip in mac ? mac[ip] : "-"),
        "[Windows]"
    }
  ' | sort -V

  SELF_HOST="$(powershell.exe -NoProfile -Command '$env:COMPUTERNAME' | tr -d "\r")"
  SELF_MAC="$(powershell.exe -NoProfile -Command '
    (Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1).MacAddress
  ' | tr -d "\r")"

  SELF_HOST_CELL="$(printf '%-32s' "$(printf '%.32s' "$SELF_HOST (this device)")")"

  printf "  | %-15s | %s | %-10s | %-17s | %-36s |\n" \
    "$IP" "$SELF_HOST_CELL" "Computer" "$SELF_MAC" "[local]"

  log
  ok "Scan completed"
}

### netscan for Linux systems
_netscan_linux() {
  info "Scanning local network for devices"
  log

  command -v nmap >/dev/null || { err "nmap not installed"; return 1; }

  IFACE="$(ip route | awk '/default/ {print $5; exit}')"
  SUBNET="$(ip -4 route show dev "$IFACE" | awk '/proto kernel/ {print $1; exit}')"

  GW_IP="$(ip route | awk '/default/ {print $3; exit}')"
  GW_MAC="$(ip neigh show "$GW_IP" | awk '{print $5; exit}')"

  NET_ID_FILE="${SUBNET//\//_}__${GW_MAC//:/}"
  ALIAS_FILE="$HOME/.config/netaliases/$NET_ID_FILE"


  [[ -z "$IFACE" || -z "$SUBNET" ]] && { err "Could not determine network"; return 1; }

  if [[ -t 1 ]]; then
    HEADER="\033[1;34m"
    RED="\033[1;31m"
    RESET="\033[0m"
  else
    HEADER=""; RED=""; RESET=""
  fi

  info "Interface : $IFACE"
  info "Subnet    : $SUBNET"
  warn "Active scan (ARP/ICMP)"
  log

  printf "  | ${HEADER}%-15s${RESET} | ${HEADER}%-32s${RESET} | ${HEADER}%-10s${RESET} | ${HEADER}%-17s${RESET} | ${HEADER}%-36s${RESET} |\n" \
    "IP" "Hostname" "Type" "MAC" "Manufacturer"
  printf "  | %-15s | %-32s | %-10s | %-17s | %-36s |\n" \
    "---------------" "--------------------------------" "----------" "-----------------" "------------------------------------"

  ip neigh flush all >/dev/null 2>&1 || true
  ping -c 1 -b 255.255.255.255 >/dev/null 2>&1 || true

  sudo nmap -sn -PR "$SUBNET" 2>/dev/null |
  awk -v ALIAS_FILE="$ALIAS_FILE" -v RED="$RED" -v RESET="$RESET" '

    BEGIN {
      if (ALIAS_FILE != "" && (getline < ALIAS_FILE) >= 0) {
        do {
          if ($0 ~ /^#/ || NF < 2) continue
          alias_host[$1] = $2
          alias_type[$1] = (NF >= 3 ? $3 : "")
        } while (getline < ALIAS_FILE)
        close(ALIAS_FILE)
      }
    }

    function classify(host, vendor) {
      h = tolower(host)
      v = tolower(vendor)

      # Hostname-based (primary)
      if (h ~ /(proxmox|pve|lxc|kvm)/) return "Server"
      if (h ~ /(nas|storage)/) return "Storage"
      if (h ~ /(print|printer|mfc|brother|epson|canon)/) return "Printer"
      if (h ~ /(cam|camera|nvr)/) return "Camera"
      if (h ~ /(switch|router|firewall|ap)/) return "Network"
      if (h ~ /(tv|smarttv|chromecast|roku)/) return "TV/Media"
      if (h ~ /(laptop|desktop|pc|workstation|notebook|macbook)/) return "Computer"
      if (h ~ /(iphone|ipad|pixel)/) return "Phone"
      if (h ~ /(galaxy|s[0-9][0-9][^a-z0-9]|note[0-9]?)/) return "Phone"
      if (h ~ /(redmi|xiaomi|mi[0-9])/ ) return "Phone"
      if (h ~ /(oneplus|oppo|realme)/) return "Phone"
      if (h ~ /(huawei|honor)/) return "Phone"
      if (h ~ /(sony|xperia)/) return "Phone"
      if (h ~ /(lg|htc)/) return "Phone"

      # Vendor-based (secondary)
      if (v ~ /proxmox/) return "Server"
      if (v ~ /dahua/) return "Camera"
      if (v ~ /(netapp|qnap|synology|asustor|western digital)/) return "Storage"
      if (v ~ /amazon/ && h ~ /(echo|alexa|kindle|fire)/) return "IoT"
      if (v ~ /(cisco|ubiquiti|mikrotik|tp-link|netgear|arcadyan|sagemcom|kreatel)/)
        return "Network"
      if (v ~ /(samsung|huawei|xiaomi|oneplus|sony|lg|htc)/) return "Phone"
      if (v ~ /(dell|lenovo|acer|msi|gigabyte|intel)/) return "Computer"

      return "Unknown"
    }

    function trunc(s,w) {
      return (length(s) > w) ? substr(s,1,w-1) "…" : s
    }

    /^Nmap scan report for/ {
      line = $0
      sub(/^.*for /, "", line)
      if (line ~ /\(/) {
        ip = line
        sub(/^.*\(/, "", ip)
        sub(/\).*$/, "", ip)
        sub(/\s*\(.*$/, "", line)
        host = line
      } else {
        ip = line
        host = "[UNKNOWN]"
      }
    }

    /MAC Address:/ {
      mac = $3
      vendor = $4
      for (i = 5; i <= NF; i++) vendor = vendor " " $i

      if (ip in alias_host && alias_host[ip] != "-") {
        host = alias_host[ip]
      }

      atype = (ip in alias_type && alias_type[ip] != "-" ? alias_type[ip] : classify(host, vendor))

      raw = trunc(host, 32)
      cell = sprintf("%-32s", raw)

      if (raw == "[UNKNOWN]" && RED != "")
        sub(/\[UNKNOWN\]/, RED "[UNKNOWN]" RESET, cell)

      printf "  | %-15s | %s | %-10s | %-17s | %-36s |\n",
        ip,
        cell,
        atype,
        mac,
        trunc(vendor, 36)
    }
  ' | sort -V

  SELF_IP="$(ip -4 addr show "$IFACE" | awk '/inet / {print $2}' | cut -d/ -f1)"
  SELF_HOST="$(cat /proc/sys/kernel/hostname)"
  SELF_MAC="$(cat /sys/class/net/$IFACE/address)"

  printf "  | %-15s | %-32s | %-10s | %-17s | %-36s |\n" \
    "$SELF_IP" "$SELF_HOST (this device)" "Computer" "$SELF_MAC" "[local]"

  log
  ok "Scan completed"
}

## Scan local network for connected devices
netscan() {
  case "${1:-}" in
    --edit-aliases) _netscan_edit_aliases; return ;;
  esac

  if [[ "$OSTYPE" == msys* || "$OSTYPE" == cygwin* ]]; then
    _netscan_windows
  else
    _netscan_linux
  fi

  info "To edit aliases for this subnet, run:"
  info "  netscan --edit-aliases"
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

### Check if an IPv4 address is public
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

## Scan open TCP ports on a LAN (private IPv4 only)
lanportscan() {
  info "Starting LAN port scan utility"
  log

  if ! command -v nmap >/dev/null 2>&1; then
    err "nmap is not installed"
    return 1
  fi

  local TARGET_IP="${1:-}"

  if [[ -z "$TARGET_IP" ]]; then
    err "Usage: lanportscan <lan-ip>"
    return 1
  fi

  # Explicitly reject public IPv4 addresses
  if is_public_ipv4 "$TARGET_IP"; then
    err "Invalid target IP: $TARGET_IP"
    err "Public IPv4 addresses are not allowed for LAN scans"
    return 1
  fi

  info "Target LAN device:"
  ipinfo "$TARGET_IP" 2>/dev/null || true
  log

  info "Select scan type:"
  info "  1) Quick scan (top 1000 TCP ports)  [default]"
  info "  2) Targeted scan (specific ports)"
  info "  3) Full scan (all 65535 TCP ports)"
  log

  local CHOICE
  read -rp "Enter choice [1-3] (default: 1): " CHOICE
  CHOICE="${CHOICE:-1}"
  log

  local NMAP_CMD="nmap"
  if command -v sudo >/dev/null 2>&1; then
    NMAP_CMD="sudo nmap"
  fi

  case "$CHOICE" in
    1)
      info "Running QUICK TCP scan on $TARGET_IP"
      info "Scanning top 1000 commonly used ports"
      log
      $NMAP_CMD "$TARGET_IP"
      ;;
    2)
      local PORTS
      read -rp "Enter ports (e.g. 22,80,443,8080): " PORTS

      if [[ -z "${PORTS// }" ]]; then
        err "No ports specified"
        return 1
      fi

      log
      info "Running TARGETED TCP scan on $TARGET_IP"
      info "Ports: $PORTS"
      log
      $NMAP_CMD -p "$PORTS" "$TARGET_IP"
      ;;
    3)
      info "Running FULL TCP scan on $TARGET_IP"
      warn "This will scan all 65535 TCP ports"
      warn "Expect more noise and longer runtime"
      log
      $NMAP_CMD -p- "$TARGET_IP"
      ;;
    *)
      err "Invalid option"
      return 1
      ;;
  esac

  ok "LAN port scan completed"
  log
}

## Network stress test using nping
netstress() {
  local TARGET PROTO RATE SIZE PORT DURATION FLAGS EXTRA
  local START_TS END_TS ELAPSED
  local SENT=0 RCVD=0 LOST=0 LOSS_PCT
  local COUNT=500

  info "Network stress test"
  log

  read -rp "Target IP/host: " TARGET
  [[ -z "$TARGET" ]] && { err "No target specified"; return 1; }

  read -rp "Target port (empty = default device stress): " PORT

  if [[ -z "$PORT" ]]; then
    PROTO="UDP"
    PORT=50000
    info "No port specified → defaulting to UDP device stress (port $PORT)"
  else
    info "Protocol for port $PORT:"
    select PROTO in UDP TCP ICMP; do
      [[ -n "$PROTO" ]] && break
    done
    [[ "$PROTO" == "ICMP" ]] && PORT=""
  fi

  read -rp "Packet rate (pps) [5000]: " RATE
  RATE="${RATE:-5000}"

  read -rp "Packet size (bytes) [1200]: " SIZE
  SIZE="${SIZE:-1200}"
  (( SIZE > 1472 )) && SIZE=1472 

  read -rp "Duration in seconds (0 = unlimited) [30]: " DURATION
  DURATION="${DURATION:-30}"

  log
  info "Target        : $TARGET"
  info "Protocol      : $PROTO"
  [[ -n "$PORT" ]] && info "Port          : $PORT"
  info "Packet rate   : $RATE pps"
  info "Packet size   : $SIZE bytes"
  info "Duration      : $DURATION s"
  log

  read -rp "Start test? [y/N]: " CONFIRM
  [[ ! "$CONFIRM" =~ ^[yY]$ ]] && { warn "Aborted."; return 0; }

  case "$PROTO" in
    ICMP) FLAGS="--icmp" ;;
    UDP)  FLAGS="--udp -p $PORT" ;;
    TCP)  FLAGS="--tcp -p $PORT --flags syn" ;;
  esac

  EXTRA="--rate $RATE --data-length $SIZE --count $COUNT"

  info "Running stress test..."
  log

  START_TS="$(date +%s)"
  END_TS=$(( DURATION > 0 ? START_TS + DURATION : 0 ))

  while :; do
    OUT="$(
      sudo nping $FLAGS $EXTRA "$TARGET" 2>&1 |
      grep -vE '^(SENT|RCVD)'
    )"

    s="$(grep -oP 'Raw packets sent:\s*\K[0-9]+' <<<"$OUT")"
    r="$(grep -oP 'Rcvd:\s*\K[0-9]+' <<<"$OUT")"
    l="$(grep -oP 'Lost:\s*\K[0-9]+' <<<"$OUT")"

    (( SENT += s ))
    (( RCVD += r ))
    (( LOST += l ))

    [[ "$DURATION" -gt 0 && "$(date +%s)" -ge "$END_TS" ]] && break
    sleep 0.1
  done

  ELAPSED="$(( $(date +%s) - START_TS ))"
  LOSS_PCT=$(( SENT > 0 ? (100 * LOST / SENT) : 0 ))

  info "Results"
  log

  info "Packets sent     : $SENT"
  info "Packets received : $RCVD"
  info "Packets lost     : $LOST (${LOSS_PCT}%)"
  info "Elapsed time     : ${ELAPSED}s"
  log

  if [[ "$PROTO" == "ICMP" && "$RCVD" -eq 0 ]]; then
    warn "ICMP replies stopped (likely rate-limited)"

  elif [[ "$RCVD" -eq 0 && "$ELAPSED" -ge 5 ]]; then
    ok "Target stopped responding under sustained load"

  elif [[ "$LOSS_PCT" -gt 10 ]]; then
    ok "High packet loss detected → target under stress"

  else
    warn "Target handled load without failure"
  fi
}

## Aggressively stress a LAN IPv4 device
lanoverload() {
  local TARGET RATE SIZE DURATION COUNT
  local START_TS END_TS

  info "LAN overload test"
  warn "When run against the router or broadcast IP, this may degrade the entire LAN!"
  log

  read -rp "Target IP/host (router or broadcast IP): " TARGET
  [[ -z "$TARGET" ]] && { err "No target specified"; return 1; }

  read -rp "Packet rate (pps) [20000]: " RATE
  RATE="${RATE:-20000}"

  read -rp "Packet size (bytes) [1472]: " SIZE
  SIZE="${SIZE:-1472}"
  (( SIZE > 1472 )) && SIZE=1472

  read -rp "Duration in seconds [10]: " DURATION
  DURATION="${DURATION:-10}"

  read -rp "Packets per burst [1000]: " COUNT
  COUNT="${COUNT:-1000}"

  log
  warn "This WILL degrade the LAN"
  warn "Target   : $TARGET"
  warn "Rate     : $RATE pps"
  warn "Size     : $SIZE bytes"
  warn "Duration : $DURATION s"
  log

  read -rp "Proceed? [y/N]: " CONFIRM
  [[ ! "$CONFIRM" =~ ^[yY]$ ]] && { warn "Aborted."; return 0; }

  info "Overloading LAN..."
  log

  START_TS="$(date +%s)"
  END_TS=$(( START_TS + DURATION ))

  while [[ "$(date +%s)" -lt "$END_TS" ]]; do
    sudo nping \
      --udp \
      -p 50000 \
      --rate "$RATE" \
      --data-length "$SIZE" \
      --count "$COUNT" \
      "$TARGET" \
      >/dev/null 2>&1
  done

  log
  ok "LAN overload test completed"
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
