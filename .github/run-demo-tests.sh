#!/usr/bin/env bash
# run-demo-tests.sh
#
# Runs the curated demo / smoke tests for the saw-script fork. Used by the
# demo-tests CI workflow as a merge gate, and runnable locally with:
#
#   SAW=$(cabal list-bin exe:saw) .github/run-demo-tests.sh
#
# Each demo is wrapped in a GitHub Actions log group (no-op when run locally)
# and tracked individually so the final summary shows exactly which demos
# failed.
#
# Add new demos to the DEMOS array (one entry per "name|workdir|cmd" tuple).
# Keep entries small and fast (< 30s wall-clock each) so the merge gate stays
# responsive.

set -uo pipefail

: "${SAW:=saw}"
: "${CLANG:=clang}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v "$SAW" >/dev/null 2>&1; then
  echo "ERROR: saw binary not on PATH (set SAW=/path/to/saw or add it to PATH)" >&2
  exit 2
fi

# Best-effort: build the loop-fixpoint demo's bitcode if a suitable clang is
# available. The demo is skipped (not failed) if clang is missing.
build_loop_fixpoint_bc() {
  if ! command -v "$CLANG" >/dev/null 2>&1; then
    echo "::warning::clang not found; skipping loop_fixpoint_demo bitcode rebuild"
    return 1
  fi
  (cd examples/loop-fixpoint && "$CLANG" -O0 -emit-llvm -c simple_loop.c -o simple_loop.bc)
}

# Format: "demo_id|working_dir|command (run with bash -lc, $SAW exported)"
#
# Demo IDs should be short, lowercase, hyphen-free where possible.
DEMOS=(
  # ── intTests-style smoke tests ─────────────────────────────────────────
  "intTest:llvm_loop_fixpoint|intTests/test_llvm_loop_fixpoint|$SAW test.saw"

  # ── examples/llvm: core LLVM verification sanity checks ────────────────
  # These have committed .bc files, so no toolchain dependency.
  "example:basic|examples/llvm|$SAW basic.saw"
  "example:struct|examples/llvm|$SAW struct.saw"
  "example:assert|examples/llvm|$SAW assert.saw"
  "example:ptr|examples/llvm|$SAW ptr.saw"
  "example:dotprod_struct|examples/llvm|$SAW dotprod_struct.saw"
  "example:global|examples/llvm|$SAW global.saw"
  "example:nested|examples/llvm|$SAW nested.saw"

  # ── loop fixpoint demo (PR #3285) ──────────────────────────────────────
  # Requires clang to rebuild simple_loop.bc; built by build_loop_fixpoint_bc.
  "example:loop_fixpoint_demo|examples/loop-fixpoint|$SAW loop_fixpoint_demo.saw"
)

# Demos that need the clang rebuild step. If clang is missing, these are
# skipped with a warning rather than failing the gate.
NEEDS_CLANG=(
  "example:loop_fixpoint_demo"
)

clang_available=true
if ! build_loop_fixpoint_bc; then
  clang_available=false
fi

passed=()
failed=()
skipped=()

for entry in "${DEMOS[@]}"; do
  id="${entry%%|*}"
  rest="${entry#*|}"
  workdir="${rest%%|*}"
  cmd="${rest#*|}"

  needs_clang=false
  for nc in "${NEEDS_CLANG[@]}"; do
    if [[ "$nc" == "$id" ]]; then needs_clang=true; break; fi
  done

  if $needs_clang && ! $clang_available; then
    skipped+=("$id (clang unavailable)")
    continue
  fi

  echo "::group::$id"
  (
    cd "$workdir"
    export SAW
    bash -lc "$cmd"
  )
  status=$?
  echo "::endgroup::"

  if [[ $status -eq 0 ]]; then
    passed+=("$id")
  else
    failed+=("$id (exit $status)")
  fi
done

echo
echo "================ Demo test summary ================"
echo "passed:  ${#passed[@]}"
for n in "${passed[@]}";  do echo "  ✓ $n"; done
echo "skipped: ${#skipped[@]}"
for n in "${skipped[@]}"; do echo "  - $n"; done
echo "failed:  ${#failed[@]}"
for n in "${failed[@]}";  do echo "  ✗ $n"; done
echo "==================================================="

if (( ${#failed[@]} > 0 )); then
  exit 1
fi
