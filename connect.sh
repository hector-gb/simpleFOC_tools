#!/usr/bin/env bash
set -euo pipefail

FQBN="esp32:esp32:esp32da"
BAUD="115200"

# Where logs live
LOG_ROOT="${DEBUG_LOG_ROOT:-$HOME/debug_logs}"

# ---- Auto-pick a serial port on macOS (/dev/cu.*) ----
pick_port() {
  arduino-cli board list | awk '
    /\/dev\/cu\./ &&
    $1 !~ /Bluetooth/ &&
    ($1 ~ /usbserial|SLAB_USBtoUART|wchusbserial|usbmodem/) {
      print $1; exit
    }'
}

PORT="$(pick_port)"
if [[ -z "${PORT}" ]]; then
  echo "Could not auto-detect USB serial port."
  arduino-cli board list
  exit 1
fi

# ---- Pick sketch name (for log folder) ----
SKETCH="${1:-}"

if [[ -z "${SKETCH}" ]]; then
  SKETCH="$(ls -1 *.ino 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "${SKETCH}" || ! -f "${SKETCH}" ]]; then
  echo "Usage: $0 path/to/YourSketch.ino"
  echo "Or run it from a folder containing a single .ino"
  exit 1
fi

SKETCH_BASENAME="$(basename "${SKETCH}" .ino)"

# ---- Git metadata (optional, safe) ----
GIT_HASH="nogit"
GIT_DIRTY=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GIT_HASH="$(git rev-parse --short HEAD)"
  git diff --quiet || GIT_DIRTY="-dirty"
fi

# ---- Logging ----
STAMP="$(date +"%Y%m%d_%H%M%S")"
LOG_DIR="${LOG_ROOT}/${SKETCH_BASENAME}"
mkdir -p "${LOG_DIR}"

LOGFILE="${LOG_DIR}/serial_${GIT_HASH}${GIT_DIRTY}_${STAMP}.log"

echo "------------------------------------------------------------"
echo "Connecting to ${PORT} @ ${BAUD}"
echo "Logging to: ${LOGFILE}"
echo "Press Ctrl+C to stop logging."
echo "------------------------------------------------------------"

arduino-cli monitor \
  -p "${PORT}" \
  --fqbn "${FQBN}" \
  -c "baudrate=${BAUD}" \
  | tee "${LOGFILE}"