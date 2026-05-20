#!/bin/bash
# Fetch GPU + system memory from the DGX Spark and emit Conky-formatted text.
# Reuses one SSH connection via ControlMaster so polling is fast.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.env
[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"

HOST="${DGX_HOST:?DGX_HOST not set — copy .env.example to .env and configure it}"
USER="${DGX_USER:?DGX_USER not set}"
KEY="${DGX_SSH_KEY:-$HOME/.ssh/id_ed25519}"
SOCKET="/tmp/dgx-ssh-${USER}@${HOST}.sock"

ssh_opts=(
  -S "$SOCKET"
  -o BatchMode=yes
  -o ConnectTimeout=5
)

if ! ssh -O check "${ssh_opts[@]}" "${USER}@${HOST}" 2>/dev/null; then
  ssh -fNM "${ssh_opts[@]}" \
    -o ControlPersist=600 \
    -o StrictHostKeyChecking=accept-new \
    -i "$KEY" "${USER}@${HOST}" 2>/dev/null
fi

OUT=$(ssh "${ssh_opts[@]}" "${USER}@${HOST}" \
  'nvidia-smi --query-gpu=name,utilization.gpu --format=csv,noheader,nounits;
   echo ---;
   grep -E "^(MemTotal|MemAvailable):" /proc/meminfo' 2>/dev/null)

if [ -z "$OUT" ]; then
  echo '${color #e74c3c}offline${color}'
  exit 0
fi

GPU_LINE=$(printf '%s\n' "$OUT" | head -1)
NAME=$(printf '%s' "$GPU_LINE" | awk -F, '{gsub(/^ +| +$/,"",$1); print $1}')
UTIL=$(printf '%s' "$GPU_LINE" | awk -F, '{gsub(/[^0-9]/,"",$2); print $2}')

MEMTOTAL_KB=$(printf '%s\n' "$OUT" | awk '/MemTotal:/{print $2}')
MEMAVAIL_KB=$(printf '%s\n' "$OUT" | awk '/MemAvailable:/{print $2}')
TOTAL_GB=$(awk "BEGIN{printf \"%.0f\", $MEMTOTAL_KB / 1024 / 1024}")
USED_GB=$(awk "BEGIN{printf \"%.2f\", ($MEMTOTAL_KB - $MEMAVAIL_KB) / 1024 / 1024}")
MEM_PCT=$(awk "BEGIN{printf \"%.0f\", ($MEMTOTAL_KB - $MEMAVAIL_KB) / $MEMTOTAL_KB * 100}")

color_for() {
  local pct=$1
  if   [ "$pct" -ge 95 ]; then echo "#e74c3c"
  elif [ "$pct" -ge 80 ]; then echo "#e67e22"
  elif [ "$pct" -ge 60 ]; then echo "#e6c200"
  else                         echo "#76b900"
  fi
}

bar() {
  local pct=$1 width=${2:-12}
  local filled=$(( pct * width / 100 ))
  local i
  for ((i=0; i<filled;       i++)); do printf '█'; done
  for ((i=0; i<width-filled; i++)); do printf '░'; done
}

UTIL_COLOR=$(color_for "$UTIL")
MEM_COLOR=$(color_for "$MEM_PCT")
UTIL_BAR=$(bar "$UTIL" 12)
MEM_BAR=$(bar "$MEM_PCT" 12)

printf '%s\n' "\${color #cccccc}${NAME}\${color}"
printf '%s\n' "GPU   \${color ${UTIL_COLOR}}${UTIL_BAR}  ${UTIL}%\${color}"
printf '%s\n' "MEM   \${color ${MEM_COLOR}}${MEM_BAR}  ${USED_GB} / ${TOTAL_GB} GB\${color}"
