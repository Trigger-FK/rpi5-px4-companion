#!/bin/bash
set -e
DEV=/dev/ttyAMA0
BAUD=921600

echo "Starting Micro-XRCE-DDS Agent on ${DEV} (${BAUD} bps)..."

exec MicroXRCEAgent serial --dev "${DEV}" -b "${BAUD}" "$@"
