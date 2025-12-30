# ==================================================
# Output formatting (safe + portable)
# ==================================================

if [[ -t 1 ]]; then
  BLACK='\033[0;30m'
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  MAGENTA='\033[0;35m'
  CYAN='\033[0;36m'
  WHITE='\033[0;37m'

  LIGHT='\033[1m'
  UNDERLINE='\033[4m'
  REVERSE='\033[7m'
  NC='\033[0m'
else
  BLACK=''
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  MAGENTA=''
  CYAN=''
  WHITE=''

  LIGHT=''
  UNDERLINE=''
  REVERSE=''
  NC=''
fi

OK="${GREEN}${LIGHT}[OK]${NC}"
ERR="${RED}[ERROR]${NC}"
INFO="${BLUE}${LIGHT}[INFO]${NC}"
WARN="${YELLOW}[WARN]${NC}"

# ==================================================
# Utility helpers
# ==================================================

## Show an overview of custom bash commands
bashrc() {
  echo -e "$INFO Custom bash commands"
  echo

  awk '
    # Detect real section headers (ignore separators and ## docs)
    /^# / && !/^##/ && $0 !~ /^# [=-]+$/ {
      section = substr($0, 3)
      next
    }

    /^## / {
      desc = substr($0, 4)
      getline
      if ($0 ~ /^[a-zA-Z_][a-zA-Z0-9_]*\(\)/) {
        name = $0
        sub(/\(\).*/, "", name)
        printf "[%s]\n%-22s %s\n", section, name, desc
      }
    }
  ' "${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}" |
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
dotfiles-update() {
  local bashrc_link bashrc_real repo_dir

  bashrc_link="${BASH_SOURCE[0]}"
  bashrc_real="$(readlink -f "$bashrc_link" 2>/dev/null || realpath "$bashrc_link")"

  repo_dir="$(cd "$(dirname "$bashrc_real")" \
    && git rev-parse --show-toplevel 2>/dev/null || true)"

  if [[ -z "$repo_dir" ]]; then
    echo -e "$ERR Could not locate dotfiles git repository"
    return 1
  fi

  echo -e "$INFO Updating dotfiles repository"
  echo -e "$INFO Repo: $repo_dir"

  (
    cd "$repo_dir"
    git pull --ff-only
  ) || {
    echo -e "$ERR Git pull failed"
    return 1
  }

  echo -e "$INFO Reloading bashrc"
  # shellcheck disable=SC1090
  source "$bashrc_link"

  echo -e "$OK Dotfiles updated and bashrc reloaded"
}

confirm() {
  read -rp "$1 (y/N): " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

# ==================================================
# System information (cross-platform)
# ==================================================

## Display system information
sysinfo() {
  case "$(uname -s)" in
    Linux*)
      _sysinfo_linux
      ;;
    MINGW*|MSYS*|CYGWIN*)
      _sysinfo_windows
      ;;
    *)
      echo -e "$ERR Unsupported platform"
      return 1
      ;;
  esac
}

### Linux implementation
_sysinfo_linux() {
  echo -e "$INFO System Information"
  echo

  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    os="$NAME"
  else
    os="Linux"
  fi

  host=$(hostname)
  kernel=$(uname -r)
  uptime_str=$(uptime -p 2>/dev/null || uptime)
  load=$(awk '{print $1 ", " $2 ", " $3}' /proc/loadavg)
  cpu_model=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2- | sed 's/^ //')

  read cpu a b c idle rest < /proc/stat
  sleep 0.4
  read cpu a2 b2 c2 idle2 rest2 < /proc/stat
  total1=$((a+b+c+idle))
  total2=$((a2+b2+c2+idle2))
  cpu_pct=$((100*((total2-total1)-(idle2-idle))/(total2-total1)))

  mem_total_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
  mem_avail_kb=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
  mem_used_kb=$((mem_total_kb-mem_avail_kb))
  mem_pct=$((100*mem_used_kb/mem_total_kb))

  mem_used=$(numfmt --to=iec --suffix=B $((mem_used_kb*1024)))
  mem_total=$(numfmt --to=iec --suffix=B $((mem_total_kb*1024)))

  swap_total_kb=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
  swap_free_kb=$(awk '/SwapFree/ {print $2}' /proc/meminfo)
  swap_used_kb=$((swap_total_kb-swap_free_kb))
  swap_pct=$(( swap_total_kb > 0 ? 100*swap_used_kb/swap_total_kb : 0 ))

  swap_used=$(numfmt --to=iec --suffix=B $((swap_used_kb*1024)))
  swap_total=$(numfmt --to=iec --suffix=B $((swap_total_kb*1024)))

  read disk_used disk_total disk_pct <<< \
    "$(df -h / | awk 'NR==2 {print $3, $2, $5}')"

  gpu="Unknown"
  gpu_pct="N/A"
  if command -v nvidia-smi >/dev/null 2>&1; then
    gpu=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1)
    gpu_pct="$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -n1)%"
  fi

  display="Unknown"
  if command -v xrandr >/dev/null 2>&1 && [[ -n "$DISPLAY" ]]; then
    display=$(xrandr --current 2>/dev/null | awk '/\*/ {print $1 " @ " $2; exit}')
  fi

  terminal="${TERM_PROGRAM:-$TERM}"
  ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')

  printf "  OS:        %s\n" "$os"
  printf "  Host:      %s\n" "$host"
  printf "  Kernel:    %s\n" "$kernel"
  printf "  Uptime:    %s\n" "$uptime_str"
  printf "  Load:      %s\n" "$load"
  printf "  CPU:       %s | %s%%\n" "$cpu_model" "$cpu_pct"
  printf "  Memory:    %s / %s | %s%%\n" "$mem_used" "$mem_total" "$mem_pct"
  printf "  Swap:      %s / %s | %s%%\n" "$swap_used" "$swap_total" "$swap_pct"
  printf "  Disk (/):  %s / %s | %s\n" "$disk_used" "$disk_total" "$disk_pct"
  printf "  GPU:       %s | %s\n" "$gpu" "$gpu_pct"
  printf "  Display:   %s\n" "$display"
  printf "  Terminal:  %s\n" "$terminal"
  printf "  IP:        %s\n" "${ip:-N/A}"

  echo
  echo -e "$OK Summary Complete"
}

### Windows implementation
_sysinfo_windows() {
  echo -e "$INFO System Information"
  echo

  ps() {
    powershell.exe -NoProfile -Command "$1" | tr -d '\r'
  }

  os=$(ps '(Get-CimInstance Win32_OperatingSystem).Caption')
  host=$(hostname)
  kernel=$(ps '(Get-CimInstance Win32_OperatingSystem).Version')

  uptime_str=$(ps '
    $uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    "up {0} days, {1} hours" -f $uptime.Days, $uptime.Hours
  ')

  cpu_model=$(ps '(Get-CimInstance Win32_Processor).Name')
  cpu_pct=$(ps '(Get-Counter "\Processor(_Total)\% Processor Time").CounterSamples[0].CookedValue.ToString("F0")')

  mem_total=$(ps '(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory')
  mem_free_kb=$(ps '(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory')
  mem_used=$((mem_total - mem_free_kb*1024))
  mem_pct=$((100*mem_used/mem_total))

  mem_used_h=$(numfmt --to=iec --suffix=B "$mem_used")
  mem_total_h=$(numfmt --to=iec --suffix=B "$mem_total")

  disk_info=$(ps '
    $d = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID=''C:''"
    "{0} {1} {2}" -f $d.Size, ($d.Size - $d.FreeSpace), ([math]::Round(100*($d.Size-$d.FreeSpace)/$d.Size))
  ')

  disk_total=$(echo "$disk_info" | awk '{print $1}')
  disk_used=$(echo "$disk_info" | awk '{print $2}')
  disk_pct=$(echo "$disk_info" | awk '{print $3}%')

  disk_used_h=$(numfmt --to=iec --suffix=B "$disk_used")
  disk_total_h=$(numfmt --to=iec --suffix=B "$disk_total")

  gpu=$(ps '(Get-CimInstance Win32_VideoController | Select-Object -First 1).Name')
  gpu_pct="N/A"

  terminal="${TERM_PROGRAM:-$TERM}"
  ip=$(ipconfig | awk '/IPv4 Address/ {print $NF; exit}')

  printf "  OS:        %s\n" "$os"
  printf "  Host:      %s\n" "$host"
  printf "  Kernel:    %s\n" "$kernel"
  printf "  Uptime:    %s\n" "$uptime_str"
  printf "  Load:      N/A\n"
  printf "  CPU:       %s | %s%%\n" "$cpu_model" "$cpu_pct"
  printf "  Memory:    %s / %s | %s%%\n" "$mem_used_h" "$mem_total_h" "$mem_pct"
  printf "  Swap:      N/A\n"
  printf "  Disk (/):  %s / %s | %s\n" "$disk_used_h" "$disk_total_h" "$disk_pct"
  printf "  GPU:       %s | %s\n" "$gpu" "$gpu_pct"
  printf "  Display:   N/A\n"
  printf "  Terminal:  %s\n" "$terminal"
  printf "  IP:        %s\n" "$ip"

  echo
  echo -e "$OK Summary Complete"
}

# ==================================================
# Linux system overview
# ==================================================

## Show system uptime and load
sysload() {
  uptime
}

## Show CPU model
cpuinfo() {
  grep -m1 "model name" /proc/cpuinfo
}

## Show memory usage (human-readable)
meminfo() {
  free -h
}

## Show disk usage (human-readable)
dfh() {
  df -h
}

# ==================================================
# Linux process inspection
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
    echo "Usage: psfind <name>"
    return 1
  }

  ps aux | grep -i "$1" | grep -v grep
}

# ==================================================
# Linux networking
# ==================================================

## Show IP addresses
ipaddr() {
  ip addr show
}

## Show routing table
iproute() {
  ip route show
}

## Show listening ports
ports() {
  ss -tulpn
}

# ==================================================
# Linux storage & filesystems
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
# Linux hardware info
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
# Linux permissions & ownership
# ==================================================

## Show numeric permissions of a file
perm() {
  [[ -z "$1" ]] && {
    echo "Usage: perm <file>"
    return 1
  }

  stat -c "%a %n" "$1"
}

## Show file owner and group
owner() {
  ls -ld "$1"
}

# ==================================================
# Linux kernel & OS information
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
# Linux system management
# ==================================================

## Update system packages (distro-aware)
sysupdate() {
  [[ ! -f /etc/os-release ]] && {
    echo -e "$ERR Cannot detect distro (missing /etc/os-release)"
    return 1
  }

  . /etc/os-release
  echo -e "$INFO Detected distro: $NAME"

  case "$ID" in
    ubuntu|debian|linuxmint|pop)
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
      echo -e "$ERR Unsupported distro: $ID"
      return 1
      ;;
  esac

  echo -e "$OK System update complete"
}

# ==================================================
# File search & inspection (cross-platform)
# ==================================================

## Find files by name (case-insensitive)
ff() {
  [[ -z "$1" ]] && {
    echo -e "$ERR Usage: ff <pattern>"
    return 1
  }
  find . -iname "*$1*" 2>/dev/null
}

## Search text in files (fallback-safe)
grepall() {
  [[ -z "$1" ]] && {
    echo -e "$ERR Usage: grepall <text>"
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
  find . -type f -printf '%s\t%p\n' 2>/dev/null |
  sort -nr | head -n 20 |
  awk '{ printf "%8.1f MB  %s\n", $1/1024/1024, $2 }'
}

## Count files by extension
countfiles() {
  [[ -z "$1" ]] && {
    echo -e "$ERR Usage: countfiles <ext>"
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
  [[ -z "$1" ]] && {
    echo -e "$ERR Usage: bu <file|dir>"
    return 1
  }

  cp -r "$1" "$1.back-up.$(date +%Y%m%d-%H%M%S)"
  echo -e "$OK Backup created"
}

## Remove files/directories safely
rmf() {
  [[ -z "$1" ]] && {
    echo -e "$ERR Usage: rmf <file|dir>"
    return 1
  }

  echo -e "$WARN This will permanently delete:"
  printf "  %s\n" "$@"
  confirm "Continue?" || return 1

  rm -rf "$@"
  echo -e "$OK Removed"
}

# ==================================================
# File permissions (cross-platform)
# ==================================================

## Make executable
x() {
  chmod +x "$@"
  echo -e "$OK Made executable: $*"
}

# ==================================================
# Navigation commands (cross-platform)
# ==================================================

home() { cd "$HOME" || return 1; }

up() {
  local levels="${1:-1}"
  local path="."

  [[ ! "$levels" =~ ^[0-9]+$ ]] && {
    echo -e "$ERR Argument must be a number"
    return 1
  }

  for ((i=0; i<levels; i++)); do
    path="$path/.."
  done

  cd "$path" || return 1
}

mkcd() {
  [[ -z "$1" ]] && {
    echo -e "$ERR No directory specified"
    return 1
  }

  mkdir -p "$1" && cd "$1" || return 1
}

back() { cd - >/dev/null || return 1; }

root() {
  local r
  r=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo -e "$ERR Not inside a git repository"
    return 1
  }
  cd "$r" || return 1
}

# ==================================================
# Git safety helpers (internal)
# ==================================================

_guard_main_rewrite() {
  local branch upstream commit_hash commit_msg

  branch=$(git branch --show-current 2>/dev/null) || return 1
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null) || true

  commit_hash=$(git rev-parse --short HEAD 2>/dev/null) || return 1
  commit_msg=$(git log -1 --pretty=%s 2>/dev/null) || return 1

  [[ "$branch" != "main" ]] && return 0

  echo -e "$WARN You are on MAIN and about to rewrite history"
  [[ -n "$upstream" ]] && echo -e "$WARN Upstream: $upstream"

  if [[ -n "$upstream" && "$upstream" != */main ]]; then
    echo -e "$WARN NOTE: upstream does not look like main (it is '$upstream')"
  fi

  echo -e "$WARN Commit to be removed: $commit_hash  $commit_msg"
  echo -e "$WARN This affects everyone pulling from main."
  echo

  read -rp "Type 'MAIN $commit_hash' to continue: " ans
  [[ "$ans" == "MAIN $commit_hash" ]]
}

_abort_reset() {
  git rev-parse ORIG_HEAD >/dev/null 2>&1 || {
    echo -e "$ERR No reset to abort"
    return 1
  }

  git reset --hard ORIG_HEAD &&
  echo -e "$OK Operation aborted"
}

# ==================================================
# Git helpers
# ==================================================

## Clone a GitHub
gclone() {
  local repo user url target

  case "$#" in
    1)
      repo="$1"
      user="kyanjeuring"
      ;;
    2)
      repo="$1"
      user="$2"
      ;;
    *)
      echo -e "$ERR Usage: gclone <repo> [username]"
      return 1
      ;;
  esac

  target="$repo"

  if [[ ! "$repo" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo -e "$ERR Invalid repository name: '$repo'"
    return 1
  fi

  if [[ ! "$user" =~ ^[a-zA-Z0-9-]+$ ]]; then
    echo -e "$ERR Invalid username: '$user'"
    return 1
  fi

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local root
    root=$(git rev-parse --show-toplevel 2>/dev/null)
    echo -e "$ERR Cannot clone inside an existing Git repository"
    return 1
  fi

  if [[ -e "$target" ]]; then
    echo -e "$WARN Repository already cloned: $target"
    return 1
  fi

  case "$user" in
    kyanjeuring|kj|kyan|kyanj|me|myself)
      user="kyanjeuring"
      ;;
  esac

  url="git@github.com:$user/$repo.git"

  echo -e "$INFO Checking repository access"
  if ! git ls-remote "$url" >/dev/null 2>&1; then
    echo -e "$ERR Repository not found or access denied"
    return 1
  fi

  echo -e "$INFO Cloning $user/$repo (SSH)"
  if git clone "$url"; then
    echo -e "$OK Clone complete"
  else
    echo -e "$ERR Clone failed"
    return 1
  fi
}

# ==================================================
# Git status & inspection
# ==================================================

## Show git status
gs() {
  git status
}

## Pretty git log
gl() {
  git log --oneline --graph --all --decorate
}

## Show commits pending promotion
gdiffpromote() {
  git log main..dev --oneline --decorate
}

## Show commits that would be promoted
whatwillpromote() {
  echo -e "$INFO Commits that would be promoted:"
  git log main..dev --oneline --decorate
}

# ==================================================
# Git staging & restore
# ==================================================

## Stage all changes
ga() {
  git add .
  echo -e "$OK All changes staged"
}

## Restore unstaged changes
gr() {
  if git diff --quiet; then
    echo -e "$INFO No unstaged changes to restore"
    return 0
  fi

  echo -e "$WARN This will discard ALL unstaged changes"
  confirm "Continue?" || return 1

  git restore .
  echo -e "$OK Changes restored"
}

## Restore staged changes
grs() {
  if git diff --cached --quiet; then
    echo -e "$INFO No staged changes to restore"
    return 0
  fi

  echo -e "$WARN This will unstage ALL staged changes"
  confirm "Continue?" || return 1

  git restore --staged .
  echo -e "$OK Staged changes restored"
}

# ==================================================
# Git sync & fetch
# ==================================================

## Pull with rebase
gpr() {
  git pull --rebase
}

## Prune deleted remote branches
gfp() {
  git fetch -p
}

## Abort current merge
gabort() {
  git merge --abort
}

# ==================================================
# Git undo — local commits
# ==================================================

## Undo last commit (soft)
gus() {
  [[ "$1" == "--abort" ]] && { _abort_reset; return $?; }

  git rev-parse HEAD >/dev/null 2>&1 || {
    echo -e "$ERR Repository has no commits"
    return 1
  }

  (( $(git rev-list --count HEAD) < 2 )) && {
    echo -e "$INFO Nothing to undo"
    return 0
  }

  git reset --soft HEAD~1 &&
  echo -e "$OK Last commit undone (soft)"
  echo -e "$INFO Use 'gus --abort' to restore previous HEAD if needed"
}

## Undo last commit (hard)
guh() {
  [[ "$1" == "--abort" ]] && {
    echo -e "$WARN guh --abort only works immediately after guh"
    _abort_reset
    return $?
  }

  git rev-parse HEAD >/dev/null 2>&1 || {
    echo -e "$ERR Repository has no commits"
    return 1
  }

  (( $(git rev-list --count HEAD) < 2 )) && {
    echo -e "$INFO Nothing to discard"
    return 0
  }

  echo -e "$WARN This will permanently discard the last commit"
  confirm "Continue?" || return 1

  git reset --hard HEAD~1 &&
  echo -e "$OK Last commit discarded (hard)"
  echo -e "$INFO Use 'guh --abort' immediately to restore previous HEAD if needed"
}

# ==================================================
# Git undo — remote commits (DANGEROUS)
# ==================================================

## Undo last remote commit (soft)
gurs() {
  local branch commit_count
  branch=$(git branch --show-current)

  [[ -z "$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)" ]] && {
    echo -e "$ERR No upstream branch set"
    return 1
  }

  commit_count=$(git rev-list --count HEAD)
  (( commit_count < 2 )) && {
    echo -e "$ERR Cannot remove the initial (root) commit"
    return 1
  }

  _guard_main_rewrite || return 1

  echo -e "$INFO Removing latest commit on '$branch' (soft)"
  git reset --soft HEAD~1 &&
  git push --force-with-lease &&
  echo -e "$OK Latest commit removed (soft)"
}

## Undo last remote commit (hard)
gurh() {
  local branch commit_count
  branch=$(git branch --show-current)

  [[ -z "$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)" ]] && {
    echo -e "$ERR No upstream branch set"
    return 1
  }

  commit_count=$(git rev-list --count HEAD)
  (( commit_count < 2 )) && {
    echo -e "$ERR Cannot remove the initial (root) commit"
    return 1
  }

  _guard_main_rewrite || return 1

  if [[ "$branch" != "main" ]]; then
    echo -e "$WARN This will permanently remove the latest commit on '$branch'"
    confirm "Continue?" || return 1
  fi

  git reset --hard HEAD~1 &&
  git push --force-with-lease &&
  echo -e "$OK Latest commit permanently removed"
}

# ==================================================
# Git branch workflows
# ==================================================

## Sync dev with main
gsync() {
  git switch dev && git pull origin main --rebase
}

## Switch to branch, pull latest, show status
workon() {
  [[ -z "$1" ]] && {
    echo -e "$ERR Usage: workon <branch>"
    return 1
  }

  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo -e "$ERR Working tree is dirty"
    echo -e "$INFO Commit or stash your changes before switching branches"
    return 1
  fi

  echo -e "$INFO Switching to branch '$1'"
  git switch "$1" || return 1

  echo -e "$INFO Pulling latest changes"
  git pull || return 1

  git status
}

## Delete merged child branches of current branch
cleanupbranches() {
  local current
  current=$(git branch --show-current)

  echo -e "$INFO Cleaning up merged branches of '$current'"

  git branch --merged | while read -r branch; do
    [[ "$branch" == "*"* ]] && continue
    [[ "$branch" == "$current" ]] && continue
    [[ "$branch" == "main" || "$branch" == "dev" ]] && continue

    base=$(git merge-base "$current" "$branch")
    if [[ "$base" == "$(git rev-parse "$current")" ]]; then
      echo -e "$INFO Deleting branch '$branch'"
      git branch -d "$branch"
    fi
  done

  echo -e "$OK Branch cleanup complete"
}

# ==================================================
# Git destructive sync
# ==================================================

## Force dev to match origin/main (destructive)
syncdev() {
  if [[ "$1" == "--abort" ]]; then
    local tag
    tag=$(git tag --list 'backup-dev-*' --sort=-creatordate | head -n1)

    if [[ -z "$tag" ]]; then
      echo -e "$ERR No backup tag found to abort syncdev"
      return 1
    fi

    echo -e "$INFO Aborting syncdev"
    echo -e "$INFO Restoring dev from backup tag: $tag"

    git switch dev >/dev/null 2>&1 || return 1
    git reset --hard "$tag" || return 1

    echo -e "$OK syncdev aborted successfully"
    return 0
  fi

  local current
  current=$(git branch --show-current)

  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo -e "$ERR Working tree is dirty"
    echo -e "$INFO Commit or stash your changes first"
    return 1
  fi

  echo -e "$WARN This will RESET 'dev' to match 'origin/main'"
  echo -e "$WARN ALL local commits on dev will be LOST"

  if [[ -n "$(git log origin/main..dev --oneline 2>/dev/null)" ]]; then
    echo
    echo -e "$INFO Commits that will be removed:"
    git log origin/main..dev --oneline --decorate
    echo
  else
    echo -e "$INFO No local-only commits on dev"
  fi

  confirm "Continue?" || return 1

  echo -e "$INFO Fetching origin"
  git fetch origin || return 1

  echo -e "$INFO Switching to dev"
  git switch dev || return 1

  backup_tag="backup-dev-$(date +%Y%m%d-%H%M%S)"
  echo -e "$INFO Creating backup tag: $backup_tag"
  git tag "$backup_tag" || return 1

  echo -e "$INFO Resetting dev → origin/main"
  git reset --hard origin/main || return 1

  if [[ "$current" != "dev" ]]; then
    git switch "$current" >/dev/null 2>&1 || \
      echo -e "$WARN Manual switch back to '$current' required"
  fi

  echo -e "$OK dev is now in sync with origin/main"
  echo -e "$INFO Backup tag created: $backup_tag"
  echo -e "$INFO Use 'syncdev --abort' to restore this state"
}

# ==================================================
# Git release / promotion
# ==================================================

## Promote dev → main and create a release tag
promote() {
  set -uo pipefail

  LOCKDIR="/tmp/git-promote.lock"
  if ! mkdir "$LOCKDIR" 2>/dev/null; then
    echo -e "$ERR Another promote is already running"
    return 1
  fi

  original=$(git branch --show-current)

  cleanup() {
    git rebase --abort >/dev/null 2>&1 || true
    git merge --abort >/dev/null 2>&1 || true
    git switch "$original" >/dev/null 2>&1 || \
      echo -e "$WARN Manual switch to $original required"
    rmdir "$LOCKDIR" >/dev/null 2>&1 || true
  }

  trap cleanup RETURN
  trap cleanup EXIT
  trap 'echo -e "$ERR Deploy interrupted"; return 1' INT TERM

  if [[ "$original" != "dev" ]]; then
    echo -e "$ERR Deploy must be run from dev (current: $original)"
    return 1
  fi

  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo -e "$ERR Working tree is dirty — commit or stash first"
    return 1
  fi

  echo -e "$INFO Fetching latest refs"
  git fetch origin || return 1

  if [[ -z "$(git log origin/main..dev --oneline)" ]]; then
    echo -e "$INFO Nothing to deploy (dev == main)"
    return 0
  fi

  echo -e "$INFO Rebasing dev onto origin/dev"
  if ! git rebase origin/dev; then
    echo -e "$ERR Rebase failed — resolve conflicts on dev"
    echo -e "$INFO After resolving:"
    echo -e "$INFO   git rebase --continue"
    echo -e "$INFO   git push origin dev or promote"
    return 1
  fi

  echo -e "$INFO Pushing dev"
  git push origin dev || return 1

  echo -e "$INFO Switching to main"
  git switch main || return 1

  echo -e "$INFO Pulling latest main"
  git pull origin main || return 1

  echo -e "$INFO Fast-forwarding main → dev"
  git merge --ff-only dev || return 1

  echo -e "$INFO Pushing main"
  if ! git push origin main; then
    echo -e "$ERR Push failed, rolling back local main"
    git reset --hard origin/main
    return 1
  fi

  echo -e "$INFO Tagging deploy"
  tag="deploy-$(date +%Y%m%d-%H%M%S)"
  git tag -a "$tag" -m "Production deploy" || return 1
  git push origin "$tag" || return 1

  echo -e "$OK Deploy successful ($tag)"
}

# ==================================================
# Docker stack lifecycle
# ==================================================

## List running containers with status and ports
dps() {
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

## Start docker compose services
dstart() {
  docker compose start
}

## Stop docker compose services
dstop() {
  docker compose stop
}

## Build and start docker stack
dcompose() {
  docker compose up -d --build --remove-orphans
}

## Stop and remove containers + volumes
ddown() {
  docker compose down -v
}

## Restart docker stack
drestart() {
  docker compose down && docker compose up -d
}

## Stop all running containers
dstopall() {
  docker ps -aq | xargs -r docker stop
}

## Recreate docker stack with volume removal
drecompose() {
  docker compose down -v && docker compose up -d
}

## Restart docker compose stack (safe + verbose)
drebootstack() {
  echo -e "$INFO Restarting docker stack"
  docker compose down || return 1
  docker compose up -d || return 1
  echo -e "$OK Stack restarted"
}

## Fully reset docker stack (destructive)
dresetstack() {
  echo -e "$WARN This will remove containers, networks, and volumes"
  confirm "Continue?" || return 1

  docker compose down -v || return 1
  docker system prune -f
  echo -e "$OK Docker stack fully reset"
}

# ==================================================
# Docker logs & debugging
# ==================================================

## Follow logs for all services
dlogs() {
  docker compose logs -f --tail=100
}

## Follow logs for a single service
dlog() {
  docker compose logs -f --tail=100 "$1"
}

## Live container resource usage
dstats() {
  docker stats
}

## Inspect a container (JSON output)
dinspect() {
  docker inspect "$1" | less
}

# ==================================================
# Docker exec & run
# ==================================================

## Exec into a running container (default shell)
dexec() {
  docker compose exec "$1" sh
}

## Run one-off commands in a service
drun() {
  docker compose run --rm "$@"
}

# ==================================================
# Docker images & volumes
# ==================================================

## List images with size
dimg() {
  docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
}

## List docker volumes
dvol() {
  docker volume ls
}

## Inspect a docker volume
dvolinspect() {
  docker volume inspect "$1"
}

# ==================================================
# Docker cleanup
# ==================================================

## Remove stopped containers
dclean() {
  docker container prune -f
}

## Remove dangling images
dcleani() {
  docker image prune -f
}

## Full cleanup (destructive)
dcleanall() {
  echo -e "$WARN Removing unused containers, images, and networks"
  confirm "Continue?" || return 1
  docker system prune -a
}

## Show what prune would remove
dprunewhat() {
  docker system prune --dry-run
}

# ==================================================
# Docker updates & rebuilds
# ==================================================

## Pull latest images
dpull() {
  docker compose pull
}

## Pull images and recreate containers
dupdate() {
  docker compose pull && docker compose up -d
}

## Rebuild and restart a single service
drebuild() {
  docker compose build "$1" && docker compose up -d "$1"
}

# ==================================================
# Docker networking
# ==================================================

## List docker networks
dnet() {
  docker network ls
}

## Inspect a docker network
dnetinspect() {
  docker network inspect "$1"
}

# ==================================================
# Docker compose utilities
# ==================================================

## Show resolved docker compose config
dconfig() {
  docker compose config
}