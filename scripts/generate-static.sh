#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v pandoc >/dev/null 2>&1; then
  echo "Error: pandoc is required but not installed." >&2
  exit 1
fi

mkdir -p docs/static
rsync -a static/ docs/static/
pandoc -i index.md -o docs/index.html --css static/main.css --standalone
