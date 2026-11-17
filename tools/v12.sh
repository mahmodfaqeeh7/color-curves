#!/bin/bash
# Dev helper for designing v1.2 levels.
#   tools/v12.sh try c4_01 c4_02     reset their solutions to the guesses in levels_v12.py, build, report
#   tools/v12.sh st c4               build and report (keep tuned solutions)
#   tools/v12.sh tune 200 18 3 c4_01 c4_02 ...   hill-climb solutions (4 in parallel)
#   tools/v12.sh pic c4_01 out.png   picture of the level with ball paths
set -u
cd "$(dirname "$0")/.."
G="${GODOT:?set GODOT}"
cmd="$1"; shift
case "$cmd" in
  try)
    python3 - "$@" <<'PY'
import json, sys
p = "tools/solution_ctrl.json"; c = json.load(open(p))
for k in sys.argv[1:]: c.pop(k, None)
open(p, "w").write("{\n" + ",\n".join('"%s": %s' % (k, json.dumps(c[k])) for k in sorted(c)) + "\n}\n")
PY
    BUILD_NO_INK=1 python3 tools/build_levels.py >/dev/null || exit 1
    ids=$(IFS=,; echo "$*")
    "$G" --headless --path . --script res://tools/probe_level.gd -- --ids="$ids" 2>&1 | grep -E "^c[0-9]|SCRIPT ERROR|Parse" ;;
  st)
    BUILD_NO_INK=1 python3 tools/build_levels.py >/dev/null || exit 1
    ids=$(IFS=,; echo "$*")
    "$G" --headless --path . --script res://tools/probe_level.gd -- --ids="$ids" 2>&1 | grep -E "^c[0-9]|SCRIPT ERROR|Parse" ;;
  tune)
    it="$1"; sg="$2"; sd="$3"; shift 3
    printf '%s\n' "$@" | xargs -P 4 -I{} sh -c "GODOT='$G' python3 tools/tune_solution.py {} $it $sg $sd 2>&1 | grep BEST | cut -c1-40" ;;
  pic)
    "$G" --headless --path . --script res://tools/trace_level.gd -- --only="$1" --out=${V12_TMP:-/tmp}/trace_$1.json >/dev/null 2>&1
    python3 tools/render_trace.py ${V12_TMP:-/tmp}/trace_$1.json "$2" ;;
esac
