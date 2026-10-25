#!/bin/bash
# コンテナの PID 1。Micro-XRCE-DDS Agent を exec で前面に出す。
# Agent が落ちればコンテナが止まり、compose の restart: always で再起動される。
# 対話シェルは `docker exec -it px4_agent bash`(ホストの da)で入る。~/.bashrc が Humble と ws を source する。
# Agent は素の DDS プロセスで ROS 2 環境は不要なので、ここでは何も source しない。
set -e

# ポートとボーレートは PX4 側(UXRCE_DDS_CFG = TELEMx, SER_TELx_BAUD = 921600)と対。無断で変えない。
DEV=/dev/ttyAMA0
BAUD=921600

echo "Starting Micro-XRCE-DDS Agent on ${DEV} (${BAUD} bps)..."
# 追加の引数(例: -v 6 で詳細ログ)は docker-compose.yaml の command: から渡せる
exec MicroXRCEAgent serial --dev "${DEV}" -b "${BAUD}" "$@"
