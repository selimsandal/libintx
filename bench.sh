#!/bin/bash
set -euo pipefail

OUTDIR="${LIBINTX_RESULTS:-./results}"
mkdir -p "$OUTDIR"

if [ $# -eq 0 ]; then
  echo "Usage: $0 <command> [args...]"
  echo "Example: $0 ./build/tests/libintx.gpu.md3.perf 20000 20000"
  exit 1
fi

GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)
GPU_DRIVER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)
GPU_MEMORY=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1)
GPU_SLUG=$(echo "$GPU_NAME" | tr ' ' '_')
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTFILE="${OUTDIR}/${GPU_SLUG}_${TIMESTAMP}.json"

OUTPUT=$("$@" 2>&1)
EXIT_CODE=$?

echo "$OUTPUT"

jq -n \
  --arg gpu "$GPU_NAME" \
  --arg driver "$GPU_DRIVER" \
  --arg memory_mb "$GPU_MEMORY" \
  --arg date "$(date -Iseconds)" \
  --arg hostname "$(hostname)" \
  --arg command "$*" \
  --argjson exit_code "$EXIT_CODE" \
  --arg output "$OUTPUT" \
  '{
    gpu: {
      name: $gpu,
      driver: $driver,
      memory_mb: ($memory_mb | tonumber)
    },
    system: {
      hostname: $hostname,
      date: $date
    },
    benchmark: {
      command: $command,
      exit_code: $exit_code,
      output: $output
    }
  }' > "$OUTFILE"

echo "Results saved to: $OUTFILE" >&2
