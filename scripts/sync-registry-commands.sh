#!/usr/bin/env bash
set -euo pipefail
# usage: scripts/sync-registry-commands.sh [--check]
#
# Thin wrapper around scripts/sync-registry-commands.py so pre-commit and CI
# keep the same entry point.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$script_dir/sync-registry-commands.py" "$@"
