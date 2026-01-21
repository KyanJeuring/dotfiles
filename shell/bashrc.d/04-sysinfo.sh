# ==================================================
# System information
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
      err "Unsupported platform"
      return 1
      ;;
  esac
}

### Linux implementation
_sysinfo_linux() {
  info "System Information"
  log

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
  log
  ok "Summary Complete"
}

### Windows implementation
_sysinfo_windows() {
  info "System Information"
  log

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

  disk_total=$(log "$disk_info" | awk '{print $1}')
  disk_used=$(log "$disk_info" | awk '{print $2}')
  disk_pct=$(log "$disk_info" | awk '{print $3}%')

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
  log
  ok "Summary Complete"
}