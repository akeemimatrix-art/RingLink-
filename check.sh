#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail=0
for required in pubspec.yaml analysis_options.yaml lib/main.dart lib/app.dart supabase/migrations/202609230001_initial_schema.sql supabase/seed.sql config/dev.example.json README.md; do
  if [ ! -f "$required" ]; then
    echo "MISSING: $required"
    fail=1
  fi
done

if grep -R "YOUR_SUPABASE" -n lib supabase --exclude-dir=.dart_tool >/dev/null 2>&1; then
  echo "INFO: placeholder Supabase values exist only where expected in config examples or docs."
fi

if grep -R "service_role" -n lib config --exclude='dev.example.json' >/dev/null 2>&1; then
  echo "ERROR: service_role key found in app/config source."
  fail=1
fi

if grep -R "FetchOptions" -n lib >/dev/null 2>&1; then
  echo "ERROR: Deprecated FetchOptions usage detected."
  fail=1
fi

if grep -R "Navigator.pushNamed" -n lib >/dev/null 2>&1; then
  echo "ERROR: Named navigation reference detected without a route table."
  fail=1
fi

if [ $fail -ne 0 ]; then
  exit 1
fi

echo "RingLink repository checks passed."
echo "Run flutter analyze and flutter test with a local Flutter SDK for language/toolchain validation."
