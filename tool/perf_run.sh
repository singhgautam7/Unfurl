#!/bin/sh
# Runs the perf harness APK on one device and keeps its "perf:" lines.
#   tool/perf_run.sh <serial> <apk> <out.txt> [--keep]
# Uninstalls first (a first run after an install is slower: run twice, keep the second with --keep).
set -e
ADB="${ADB:-$HOME/Library/Android/sdk/platform-tools/adb} -s $1"
[ "$4" = "--keep" ] || $ADB uninstall com.grs.unfurl >/dev/null 2>&1 || true
$ADB install -r "$2" >/dev/null
$ADB shell am force-stop com.grs.unfurl
$ADB logcat -c || true
# A buffer that would not clear still holds the last run: read from now on.
SINCE=$($ADB shell "date '+%m-%d %H:%M:%S.000'" | tr -d '\r')
$ADB shell am start -n com.grs.unfurl/.MainActivity >/dev/null
i=0
while [ $i -lt 150 ]; do
  sleep 10
  i=$((i + 1))
  $ADB logcat -d -T "$SINCE" -s flutter >/tmp/perf_$1.log
  if grep -q '"name":"done"' /tmp/perf_$1.log; then break; fi
  if grep -q 'Unhandled Exception\|EXCEPTION CAUGHT\|Some tests failed' /tmp/perf_$1.log; then echo "test failed"; tail -40 /tmp/perf_$1.log; break; fi
done
grep -o 'perf: {.*' /tmp/perf_$1.log >"$3" || true
wc -l "$3"
