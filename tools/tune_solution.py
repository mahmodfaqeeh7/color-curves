"""Dev tool: improve a level's stored solution with search_solution.gd.
GODOT=/path/to/godot python3 tools/tune_solution.py c1_08 [iters] [sigma] [seeds]
Writes the best control points back to tools/solution_ctrl.json if better."""
import json, os, re, subprocess, sys
here = os.path.dirname(os.path.abspath(__file__))
root = os.path.dirname(here)
G = os.environ["GODOT"]
lid = sys.argv[1]
iters = sys.argv[2] if len(sys.argv) > 2 else "300"
sigma = sys.argv[3] if len(sys.argv) > 3 else "15"
seeds = int(sys.argv[4]) if len(sys.argv) > 4 else 3
ctrl_path = os.path.join(here, "solution_ctrl.json")
# Search without an ink budget; the final build sets the budget from the result.
subprocess.run([sys.executable, os.path.join(here, "build_levels.py")], check=True, capture_output=True,
               env=dict(os.environ, BUILD_NO_INK="1"))
ctrl = json.load(open(ctrl_path))
best_s, best = None, None
for sd in range(1, seeds + 1):
    out = subprocess.run([G, "--headless", "--path", root, "--script", "res://tools/search_solution.gd", "--",
                          "--only=" + lid, "--ctrl=" + json.dumps(ctrl[lid]), "--iters=" + iters,
                          "--sigma=" + sigma, "--seed=" + str(sd)], capture_output=True, text=True).stdout
    start = re.search(r"^start (\S+)", out, re.M)
    m = re.search(r"^BEST (\S+) (.*)$", out, re.M)
    if best_s is None and start:
        best_s, best = float(start.group(1)), ctrl[lid]
    if m and float(m.group(1)) > (best_s if best_s is not None else -1e18):
        best_s, best = float(m.group(1)), json.loads(m.group(2))
    print(lid, "seed", sd, m.group(1) if m else "?")
    if best_s is not None and best_s >= 1770:
        break
# Parallel-safe: lock, re-read, update only this level, write.
import fcntl
with open(ctrl_path + ".lock", "w") as lk:
    fcntl.flock(lk, fcntl.LOCK_EX)
    ctrl = json.load(open(ctrl_path))
    ctrl[lid] = best
    with open(ctrl_path, "w") as f:
        f.write("{\n" + ",\n".join('"%s": %s' % (k, json.dumps(ctrl[k])) for k in sorted(ctrl)) + "\n}\n")
    subprocess.run([sys.executable, os.path.join(here, "build_levels.py")], check=True, capture_output=True)
    fcntl.flock(lk, fcntl.LOCK_UN)
print(lid, "BEST", best_s, json.dumps(best))
