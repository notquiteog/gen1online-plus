#!/bin/sh
set -eu
ONLINE_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export ONLINE_ROOT
exec "${LOVE_BIN:-love}" "$ONLINE_ROOT/server" "${1:-crystal}" "${2:-7777}" "${3:-128}"
