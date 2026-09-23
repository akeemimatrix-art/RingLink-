#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ ! -d android ]; then
  echo "android/ does not exist. Run scripts/bootstrap_android.sh first."
  exit 1
fi

MANIFEST="android/app/src/main/AndroidManifest.xml"
if [ -f "$MANIFEST" ]; then
  python3 - "$MANIFEST" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
permissions=[
    'android.permission.INTERNET',
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.ACCESS_FINE_LOCATION',
]
insert='\n'.join(f'    <uses-permission android:name="{x}" />' for x in permissions)
marker='<manifest '
start=s.find('>', s.find(marker))
if start == -1:
    raise SystemExit('Could not parse AndroidManifest.xml')
head=s[:start+1]
rest=s[start+1:]
for perm in permissions:
    line=f'    <uses-permission android:name="{perm}" />'
    if line not in s:
        head += '\n' + line
s=head+rest
p.write_text(s)
PY
fi

KTS="android/app/build.gradle.kts"
GROOVY="android/app/build.gradle"
if [ -f "$KTS" ]; then
  python3 - "$KTS" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
s=s.replace('compileSdk = flutter.compileSdkVersion', 'compileSdk = 36')
s=s.replace('targetSdk = flutter.targetSdkVersion', 'targetSdk = 36')
p.write_text(s)
PY
elif [ -f "$GROOVY" ]; then
  python3 - "$GROOVY" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
s=s.replace('compileSdkVersion flutter.compileSdkVersion', 'compileSdkVersion 36')
s=s.replace('targetSdkVersion flutter.targetSdkVersion', 'targetSdkVersion 36')
p.write_text(s)
PY
fi

echo "Android configuration patched for RingLink."
