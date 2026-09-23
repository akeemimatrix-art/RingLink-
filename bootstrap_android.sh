#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK not found. Install Flutter first: https://docs.flutter.dev/get-started/install"
  exit 1
fi

if [ -d android ]; then
  echo "android/ already exists; skipping flutter create."
else
  flutter create --platforms=android --org com.ringlink --project-name ringlink .
fi

bash scripts/patch_android.sh

echo "Android platform created and patched."
