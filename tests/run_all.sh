#!/usr/bin/env bash
# Headless test gate: import, word/level validation, rules, saves and rewards,
# the end-to-end UI flow, and a boot smoke test that must print no errors.
set -o pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)}"
fail=0

run() {  # name, then godot args
  local name="$1"; shift
  local out
  out="$("$GODOT" --headless --path . "$@" 2>&1)"
  local code=$?
  echo "$out" | grep -E "^(LEVELS|LOGIC|PROFILE|UI FLOW):|  FAIL:" || true
  if echo "$out" | grep -qE "SCRIPT ERROR|Parse Error|Leaked instance|leaked at exit|still in use"; then
    echo "$out" | grep -E "SCRIPT ERROR|Parse Error|leaked|still in use" | head -10
    echo "$name: engine errors or leaks reported"
    fail=1
  fi
  if [ $code -ne 0 ]; then echo "$name: exit code $code"; fail=1; fi
}

"$GODOT" --headless --path . --import >/dev/null 2>&1
run levels  -s res://tests/levels_test.gd
run logic   -s res://tests/logic_test.gd
run profile res://tests/profile_test.tscn
run ui      res://tests/ui_flow.tscn
boot="$("$GODOT" --headless --path . --quit-after 300 2>&1)"
if echo "$boot" | grep -qE "ERROR|WARNING"; then
  echo "$boot" | grep -E "ERROR|WARNING" | head -10
  echo "BOOT: errors or warnings while running the game"
  fail=1
else
  echo "BOOT: PASS (no errors or warnings)"
fi

if [ $fail -ne 0 ]; then echo "SOME CHECKS FAILED"; exit 1; fi
echo "ALL CHECKS PASSED"
