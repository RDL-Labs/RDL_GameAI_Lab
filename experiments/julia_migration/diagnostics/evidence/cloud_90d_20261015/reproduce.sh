#!/usr/bin/env bash
set -euo pipefail
evidence=$(cd "$(dirname "$0")" && pwd)
root=$(git -C "$evidence" rev-parse --show-toplevel)
base=5b09a58c3009f59044cc08d2a551f939a3fa7790
julia_bin=${JULIA_BIN:-julia}
julia_bin=$(command -v "$julia_bin")
"$julia_bin" --startup-file=no -e 'VERSION == v"1.13.1" || error("Julia 1.13.1 required")'
out=${1:?Supply a new output directory}
if [ -e "$out" ]; then echo "Refusing existing output: $out" >&2; exit 2; fi
mkdir -p "$out/source"
out=$(cd "$out" && pwd)
git -C "$root" archive "$base" | tar -x -C "$out/source"
patch --batch --forward -d "$out/source" -p1 < "$evidence/experiment.patch"
cmp "$out/source/experiments/julia_migration/lw_integrated/search_review_spec.json" "$evidence/spec.json"
cd "$out/source"
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 LW_PROGRESS_PATH="$out/progress.tsv"
printf 'preparing\n' > "$out/status.txt"
if "$julia_bin" --startup-file=no --project=experiments/julia_migration/julia experiments/julia_migration/julia/setup.jl > "$out/setup.log" 2>&1; then :; else
  code=$?; printf 'setup_failed=%s\n' "$code" > "$out/status.txt"; exit "$code"
fi
printf 'unix_time\twall_seconds\tsim_seconds\tday\tcompleted_operations\tstage\tpeak_rss_bytes\n' > "$out/progress.tsv"
printf 'running\n' > "$out/status.txt"
start=$(date +%s)
code=0
"$julia_bin" --startup-file=no --project=experiments/julia_migration/julia experiments/julia_migration/lw_integrated/search_review_campaign.jl "$out" > "$out/run.log" 2>&1 || code=$?
end=$(date +%s)
printf 'exit_code=%s\nwall_seconds=%s\n' "$code" "$((end-start))" > "$out/status.txt"
date -Is >> "$out/status.txt"
cat "$out/status.txt"
exit "$code"
