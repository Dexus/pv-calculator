#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/Dexus/pv-calculator.git"
BRANCH="initial-flutter-engine"

git clone "$REPO_URL"
cd pv-calculator
git checkout -b "$BRANCH"

echo "Copy the overlay files into this directory, then run:"
echo "  git add ."
echo "  git commit -m 'Add Flutter/Pure Dart starter structure for PV Calculator'"
echo "  git push -u origin $BRANCH"
