#!/usr/bin/env bash
set -euo pipefail

FQBN="esp32:esp32:um_feathers3"
BAUD="115200"

# Where logs live (base)
LOG_ROOT="$HOME/debug_logs"

# ---- Pick your sketch (recommended explicit) ----
# Option A: pass sketch path as first arg: ./flash.sh path/to/MySketch.ino
SKETCH="${1:-}"

# Option B: auto-pick first .ino in current dir if none provided
if [[ -z "${SKETCH}" ]]; then
  SKETCH="$(ls -1 *.ino 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "${SKETCH}" || ! -f "${SKETCH}" ]]; then
  echo "Usage: $0 path/to/YourSketch.ino"
  echo "Or run it from a folder containing a single .ino"
  exit 1
fi

# Sketch name (folder name)
SKETCH_BASENAME="$(basename "${SKETCH}" .ino)"
SKETCH_DIR="$(cd "$(dirname "${SKETCH}")" && pwd)"

# ---- Git metadata (if sketch is in a git repo) ----
GIT_HASH="nogit"
GIT_DIRTY=""
if git -C "${SKETCH_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GIT_HASH="$(git -C "${SKETCH_DIR}" rev-parse --short HEAD)"
  git -C "${SKETCH_DIR}" diff --quiet || GIT_DIRTY="-dirty"
fi

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
  echo "Could not auto-detect USB serial port. Here are the ports:"
  arduino-cli board list
  exit 1
fi

echo "Flashing ${FQBN} on ${PORT} | ${GIT_HASH}${GIT_DIRTY} | Sketch: ${SKETCH_BASENAME}"

# ---- Build ----
arduino-cli compile \
  --fqbn "$FQBN" \
  --build-property "compiler.cpp.extra_flags=-DFW_GIT_HASH=\"${GIT_HASH}\" -DFW_GIT_DIRTY=\"${GIT_DIRTY}\"" \
  "${SKETCH_DIR}"

# ---- Upload ----
arduino-cli upload \
  --fqbn "$FQBN" \
  -p "$PORT" \
  --upload-property upload.speed=115200 \
  "${SKETCH_DIR}"

# Some ESP32 boards re-enumerate the USB port after flashing
sleep 1
PORT="$(pick_port)"
if [[ -z "${PORT}" ]]; then
  echo "Upload finished, but could not re-detect USB serial port."
  arduino-cli board list
  exit 1
fi

# ---- Logging ----
STAMP="$(date +"%Y%m%d_%H%M%S")"
LOG_DIR="${LOG_ROOT}/${SKETCH_BASENAME}"
mkdir -p "${LOG_DIR}"

LOGFILE="${LOG_DIR}/serial_${GIT_HASH}${GIT_DIRTY}_${STAMP}.log"

echo "------------------------------------------------------------"
echo "Opening serial monitor on ${PORT} @ ${BAUD}"
echo "Logging to: ${LOGFILE}"
echo "Press Ctrl+C to stop logging."
echo "------------------------------------------------------------"

# Save file to disk save to disk
arduino-cli monitor -p "${PORT}" --fqbn "${FQBN}" -c "baudrate=${BAUD}" | tee "${LOGFILE}"