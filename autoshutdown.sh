#!/usr/bin/env bash
set -eux

# allow overrides for quick testing
IDLE_LIMIT=${IDLE_LIMIT:-7200}       # seconds before shutdown
CHECK_INTERVAL=${CHECK_INTERVAL:-300}
WORK_START=${WORK_START:-9}
WORK_END=${WORK_END:-18}
STATE_FILE=/tmp/last_active

# init
date +%s > "$STATE_FILE"
echo "[watcher] starting with IDLE_LIMIT=${IDLE_LIMIT}s, CHECK_INTERVAL=${CHECK_INTERVAL}s"

while true; do
  now=$(date +%s)
  hour=$(date +%H)
  last=$(cat "$STATE_FILE")

  if (( hour >= WORK_START && hour < WORK_END )); then
    echo "[watcher] within working hours (${hour}), skipping shutdown checks"
  else
    GPU_PROCS=$(nvidia-smi --query-compute-apps=pid --format=csv,noheader | wc -l)
    echo "[watcher] GPU_PROCS=$GPU_PROCS, idle=$((now-last))s"

    if (( GPU_PROCS == 0 )); then
      idle=$(( now - last ))
      if (( idle >= IDLE_LIMIT )); then
        echo "[watcher] idle for ${idle}s ≥ ${IDLE_LIMIT}s → stopping pod now!"
        runpodctl stop pod "$RUNPOD_POD_ID"
        exit 0
      fi
    else
      echo "[watcher] activity detected, resetting timer"
      date +%s > "$STATE_FILE"
    fi
  fi

  sleep "$CHECK_INTERVAL"
done
