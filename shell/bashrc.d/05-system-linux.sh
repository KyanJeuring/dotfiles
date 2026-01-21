[[ "$(uname -s)" != Linux* ]] && return

# ==================================================
# System overview
# ==================================================

## Show system uptime and load
sysload() {
  uptime
}

## Show CPU model
cpuinfo() {
  grep -m1 "model name" /proc/cpuinfo
}

## Show memory usage
meminfo() {
  free -h
}

## Show disk usage
dfh() {
  df -h
}

# ==================================================
# Process inspection
# ==================================================

## Show top CPU-consuming processes
pscpu() {
  ps aux --sort=-%cpu | head -n 15
}

## Show top memory-consuming processes
psmem() {
  ps aux --sort=-%mem | head -n 15
}

## Find process by name
psfind() {
  [[ -z "$1" ]] && {
    log "Usage: psfind <name>"
    return 1
  }

  ps aux | grep -i "$1" | grep -v grep
}

# ==================================================
# Storage & filesystems
# ==================================================

## Show mounted filesystems
mounts() {
  mount | column -t
}

## Show block devices with filesystem info
lsblkf() {
  lsblk -f
}

# ==================================================
# Hardware info
# ==================================================

## Show PCI devices
pci() {
  lspci
}

## Show USB devices
usb() {
  lsusb
}

# ==================================================
# Permissions & Ownership
# ==================================================

## Show numeric permissions of a file
perm() {
  [[ -z "$1" ]] && {
    log "Usage: perm <file>"
    return 1
  }

  stat -c "%a %n" "$1"
}

## Show file owner and group
owner() {
  ls -ld "$1"
}

# ==================================================
# Kernel & OS information
# ==================================================

## Show kernel version
kernel() {
  uname -r
}

## Show OS information
osinfo() {
  cat /etc/os-release
}

# ==================================================
# System Management
# ==================================================

## Update system packages
sysupdate() {
  [[ ! -f /etc/os-release ]] && {
    err "Cannot detect distro (missing /etc/os-release)"
    return 1
  }

  . /etc/os-release
  info "Detected distro: $NAME"

  case "$ID" in
    ubuntu|debian|raspbian|raspios|linuxmint|pop)
      sudo apt update && sudo apt upgrade
      ;;
    arch|manjaro|endeavouros)
      sudo pacman -Syu
      ;;
    fedora|rhel|centos|rocky|almalinux)
      sudo dnf upgrade
      ;;
    opensuse*|suse)
      sudo zypper refresh && sudo zypper update
      ;;
    alpine)
      sudo apk update && sudo apk upgrade
      ;;
    *)
      # Fallback using ID_LIKE
      if [[ "$ID_LIKE" == *debian* ]]; then
        sudo apt update && sudo apt upgrade
      elif [[ "$ID_LIKE" == *arch* ]]; then
        sudo pacman -Syu
      elif [[ "$ID_LIKE" == *rhel* || "$ID_LIKE" == *fedora* ]]; then
        sudo dnf upgrade
      else
        err "Unsupported distro: $ID"
        return 1
      fi
      ;;
  esac

  ok "System update complete"
}
