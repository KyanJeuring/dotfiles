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
    err "Usage: psfind <name>"
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
# USB mount management
# ==================================================

### Get standard mount point for a USB device
_usb_mountpoint() {
  local DEV="$1"
  local LABEL

  LABEL="$(lsblk -no LABEL "$DEV")"

  if [[ -n "$LABEL" ]]; then
    echo "/mnt/usb-$LABEL"
  else
    echo "/mnt/usb-$(basename "$DEV")"
  fi
}

## List removable USB block devices
usblist() {
  lsblk -o NAME,SIZE,RM,TYPE,FSTYPE,LABEL,MOUNTPOINTS \
  | awk '
    NR==1 {print; next}
    $3 == 1 && ($4 == "disk" || $4 == "part") {print}
  '
}

## Mount a USB device to /mnt/usb-<label> or /mnt/usb-<device>
usbmount() {
  local DEV="${1:-}"
  local MNT

  if [[ -z "$DEV" ]]; then
    err "Usage: usb-mount /dev/sdXN"
    return 1
  fi

  if [[ ! -b "$DEV" ]]; then
    err "Not a block device: $DEV"
    return 1
  fi

  MNT="$(_usb_mountpoint "$DEV")"

  if mount | grep -q "on $MNT "; then
    warn "$DEV already mounted at $MNT"
    return 0
  fi

  sudo mkdir -p "$MNT" || return 1
  sudo mount "$DEV" "$MNT" && ok "Mounted $DEV at $MNT"
}

## Unmount a USB device
usbunmount() {
  local DEV="${1:-}"
  local MNT

  if [[ -z "$DEV" ]]; then
    err "Usage: usb-unmount /dev/sdXN"
    return 1
  fi

  MNT="$(_usb_mountpoint "$DEV")"

  if ! mount | grep -q "on $MNT "; then
    warn "$DEV is not mounted"
    return 0
  fi

  sudo umount "$MNT" && ok "Unmounted $DEV"
}

## Safely eject a USB device (unmount + power off)
usbeject() {
  local DEV="${1:-}"
  local BASE

  if [[ -z "$DEV" ]]; then
    err "Usage: usb-eject /dev/sdX or /dev/sdXN"
    return 1
  fi

  BASE="$(lsblk -no PKNAME "$DEV" 2>/dev/null)"
  [[ -n "$BASE" ]] && DEV="/dev/$BASE"

  lsblk -ln "/dev/$(basename "$DEV")" -o NAME | tail -n +2 |
  while read -r part; do
    sudo umount "/mnt/usb-$part" 2>/dev/null || true
  done

  if command -v udisksctl >/dev/null; then
    sudo udisksctl power-off -b "$DEV" && ok "Ejected $DEV"
  else
    warn "udisksctl not installed (device unmounted only)"
  fi
}

# ==================================================
# Permissions & Ownership
# ==================================================

## Show numeric permissions of a file
perm() {
  [[ -z "$1" ]] && {
    err "Usage: perm <file>"
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
