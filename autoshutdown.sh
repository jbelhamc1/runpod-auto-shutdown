#!/usr/bin/env bash
# auto_shutdown.sh

IDLE_LIMIT=7200           # 2 hours in seconds
CHECK_INTERVAL=300        # poll every 5 minutes
STATE_FILE=/tmp/last_active

WORK_START=9              # 09:00
WORK_END=18               # 18:00

# initialize the “last active” timestamp
date +%s > "$STATE_FILE"

while true; do
  now=$(date +%s)
  hour=$(date +%H)         # current hour, 00–23
  last=$(cat "$STATE_FILE")

  # 1) If in working hours, never shut down
  if [ "$hour" -ge "$WORK_START" ] && [ "$hour" -lt "$WORK_END" ]; then
    echo "Working hours (${WORK_START}:00–${WORK_END}:00); keeping pod alive."
    # (optional) -- you could reset the idle timer here if you
    # want idle→2 h to count only outside working hours:
    # date +%s > "$STATE_FILE"
  else
    # 2) Outside working hours → apply idle logic
    #    count running GPU processes
    GPU_PROCS=$(nvidia-smi --query-compute-apps=pid \
                --format=csv,noheader | wc -l)

    if [ "$GPU_PROCS" -eq 0 ]; then
      idle=$(( now - last ))
      if [ $idle -ge $IDLE_LIMIT ]; then
        echo "Idle for ${idle}s ≥ ${IDLE_LIMIT}s outside working hours → stopping pod."
        runpodctl stop pod "$RUNPOD_POD_ID" && exit
      else
        echo "Idle ${idle}s (<${IDLE_LIMIT}s) — not shutting down yet."
      fi
    else
      # reset timer whenever there *is* activity
      echo "Detected GPU activity → resetting idle timer."
      date +%s > "$STATE_FILE"
    fi
  fi

  sleep $CHECK_INTERVAL
done
