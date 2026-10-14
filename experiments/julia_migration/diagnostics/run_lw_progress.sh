#!/usr/bin/env bash
# Linux / WSL2. Frozen source; no edits to the caller's checkout.
set -euo pipefail
root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
base=5b09a58c3009f59044cc08d2a551f939a3fa7790
julia_bin=${JULIA_BIN:-julia}
command -v "$julia_bin" >/dev/null
"$julia_bin" --startup-file=no -e 'VERSION == v"1.13.1" || error("Julia 1.13.1 required")'
out=${1:-"$HOME/lw-bench/diagnostic-$(date +%Y%m%d-%H%M%S)"}
if [ -e "$out" ]; then echo "Refusing existing output: $out" >&2; exit 2; fi
mkdir -p "$out/source"
out=$(cd "$out" && pwd)
git -C "$root" archive "$base" | tar -x -C "$out/source"
cp "$out/source/experiments/julia_migration/lw_day/run.jl" "$out/run.original.jl"
python3 "$root/experiments/julia_migration/diagnostics/instrument_progress.py" "$out/source"
diff -u "$out/run.original.jl" "$out/source/experiments/julia_migration/lw_day/run.jl" > "$out/instrumentation.patch" || test "$?" -eq 1
cd "$out/source"
{ date -Is; uname -a; lscpu; free -b; printf 'source_commit=%s\n' "$base"; "$julia_bin" --version; } > "$out/environment.txt"
printf '%s\n' "${HARDWARE_NOTE:-not specified}" > "$out/hardware-note.txt"
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 LW_PROGRESS_PATH="$out/progress.tsv"
printf 'preparing\n' > "$out/status.txt"
if "$julia_bin" --startup-file=no --project=experiments/julia_migration/julia experiments/julia_migration/julia/setup.jl > "$out/setup.log" 2>&1; then :; else
  code=$?; printf 'setup_failed=%s\n' "$code" > "$out/status.txt"; exit "$code"
fi
printf 'unix_time\twall_seconds\tsim_seconds\tday\tcompleted_operations\tstage\tpeak_rss_bytes\n' > "$out/progress.tsv"
printf 'unix_time\tpid\tVmRSS_kB\tVmSize_kB\tVmHWM_kB\n' > "$out/memory.tsv"
printf 'running\n' > "$out/status.txt"
start=$(date +%s)
"$julia_bin" --startup-file=no --project=experiments/julia_migration/julia experiments/julia_migration/lw_integrated/search_review_campaign.jl "$out" > "$out/run.log" 2>&1 &
pid=$!
printf '%s\n' "$pid" > "$out/pid"
echo "Running PID $pid; results: $out"
while kill -0 "$pid" 2>/dev/null; do
  awk -v now="$(date +%s)" -v pid="$pid" '/^VmRSS:/ {rss=$2} /^VmSize:/ {vs=$2} /^VmHWM:/ {peak=$2} END {printf "%s\t%s\t%s\t%s\t%s\n",now,pid,rss,vs,peak}' "/proc/$pid/status" >> "$out/memory.tsv" 2>/dev/null || true
  sleep 5
done
code=0
wait "$pid" || code=$?
end=$(date +%s)
printf 'exit_code=%s\nwall_seconds=%s\n' "$code" "$((end-start))" > "$out/status.txt"
date -Is >> "$out/status.txt"
cat "$out/status.txt"
tail -12 "$out/run.log"
exit "$code"
