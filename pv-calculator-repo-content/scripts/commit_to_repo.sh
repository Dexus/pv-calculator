#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: scripts/commit_to_repo.sh /path/to/local/Dexus/pv-calculator" >&2
  exit 1
fi

TARGET_REPO="$1"
PACKAGE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ ! -d "$TARGET_REPO/.git" ]]; then
  echo "Target is not a Git repository: $TARGET_REPO" >&2
  exit 1
fi

rsync -av \
  --exclude '.git' \
  --exclude '*.zip' \
  "$PACKAGE_ROOT/" "$TARGET_REPO/"

cd "$TARGET_REPO"
git status
git add README.md docs prototypes app scripts
git commit -m "Add PV Calculator docs and starter code"
git push origin main
