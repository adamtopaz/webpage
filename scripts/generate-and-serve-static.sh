#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${1:-8000}"
WATCH_INTERVAL="${WATCH_INTERVAL:-1}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 is required to serve the page locally." >&2
  exit 1
fi

compute_source_fingerprint() {
  python3 - "$ROOT_DIR" <<'PY'
import hashlib
import os
import sys

root = sys.argv[1]
watch_paths = [
    os.path.join(root, "index.md"),
    os.path.join(root, "static"),
]

entries = []
for path in watch_paths:
    if os.path.isfile(path):
        stat = os.stat(path, follow_symlinks=False)
        entries.append((os.path.relpath(path, root), stat.st_mtime_ns, stat.st_size))
    elif os.path.isdir(path):
        for dirpath, _, filenames in os.walk(path):
            for filename in filenames:
                file_path = os.path.join(dirpath, filename)
                if os.path.isfile(file_path):
                    stat = os.stat(file_path, follow_symlinks=False)
                    entries.append((os.path.relpath(file_path, root), stat.st_mtime_ns, stat.st_size))

fingerprint = hashlib.sha256()
for rel_path, mtime_ns, size in sorted(entries):
    fingerprint.update(rel_path.encode("utf-8", "surrogateescape"))
    fingerprint.update(b"\0")
    fingerprint.update(str(mtime_ns).encode("utf-8"))
    fingerprint.update(b"\0")
    fingerprint.update(str(size).encode("utf-8"))
    fingerprint.update(b"\n")

print(fingerprint.hexdigest())
PY
}

watch_and_regenerate() {
  local previous_fingerprint
  local current_fingerprint

  previous_fingerprint="$(compute_source_fingerprint)"

  while true; do
    sleep "$WATCH_INTERVAL"
    current_fingerprint="$(compute_source_fingerprint)"

    if [[ "$current_fingerprint" != "$previous_fingerprint" ]]; then
      previous_fingerprint="$current_fingerprint"
      echo "Changes detected. Regenerating static site..."
      if "$ROOT_DIR/scripts/generate-static.sh"; then
        echo "Static site regenerated. Refresh your browser to see updates."
      else
        echo "Regeneration failed. Waiting for further changes..." >&2
      fi
    fi
  done
}

"$ROOT_DIR/scripts/generate-static.sh"

watch_and_regenerate &
WATCH_PID=$!

cleanup() {
  kill "$WATCH_PID" >/dev/null 2>&1 || true
}

trap cleanup EXIT INT TERM

cd "$ROOT_DIR/docs"
echo "Serving static site at http://localhost:${PORT}"
echo "Watching index.md and static/ for changes every ${WATCH_INTERVAL}s"
python3 -m http.server "$PORT"
