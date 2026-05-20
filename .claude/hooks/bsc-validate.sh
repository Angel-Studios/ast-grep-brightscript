#!/usr/bin/env bash
# bsc-validate.sh — PostToolUse gate that runs the BrighterScript compiler (bsc)
# against any edited .brs/.bs file's project, so an agent cannot leave invalid
# BrightScript/BrighterScript on disk. Exits 2 (feeding the diagnostics back to
# the agent) when bsc reports error-level diagnostics; exits 0 otherwise.
#
# MANAGED FILE: the canonical copy lives in ast-grep-brightscript
# (.claude/hooks/bsc-validate.sh) and is copied into peer apps by
# scripts/sync-angel-roku.ts. Edit it there and re-run the sync, not in place.
#
#   Disable entirely:   export BSC_VALIDATE_HOOK=0
#   Extra bsc args:     export BSC_VALIDATE_EXTRA_ARGS="--ignore-error-codes 1234"
#
# Why bsc (not the tree-sitter parser): bsc is the real compiler — authoritative
# for "valid", covers both .brs and .bs, and a superset of a parse check. The
# tree-sitter grammar is an approximation and would false-reject valid code.
set -uo pipefail

[ "${BSC_VALIDATE_HOOK:-1}" = "0" ] && exit 0

# --- read the PostToolUse payload (JSON on stdin) and pull the edited path ----
payload="$(cat)"
file_path="$(printf '%s' "$payload" | node -e '
  let d = "";
  process.stdin.on("data", c => d += c).on("end", () => {
    try {
      const j = JSON.parse(d);
      const ti = j.tool_input || {};
      process.stdout.write(ti.file_path || ti.notebook_path || "");
    } catch (e) { process.stdout.write(""); }
  });
' 2>/dev/null)"

[ -z "$file_path" ] && exit 0

# only BrightScript / BrighterScript source
case "$file_path" in
  *.brs|*.bs) ;;
  *) exit 0 ;;
esac

# intentionally-invalid fixtures must not trip the gate
case "$file_path" in
  */corpus/negative/*|*/negative/*) exit 0 ;;
esac

# resolve to an absolute path
case "$file_path" in
  /*) abs="$file_path" ;;
  *)  abs="${CLAUDE_PROJECT_DIR:-$PWD}/$file_path" ;;
esac

# --- find the nearest bsconfig.json by walking up from the file --------------
dir="$(dirname "$abs")"
bsconfig=""
while [ -n "$dir" ] && [ "$dir" != "/" ]; do
  if [ -f "$dir/bsconfig.json" ]; then
    bsconfig="$dir/bsconfig.json"
    break
  fi
  dir="$(dirname "$dir")"
done
[ -z "$bsconfig" ] && exit 0   # not part of a bsc project — nothing to validate
project_root="$(dirname "$bsconfig")"

# --- pick a bsc binary (prefer the project's own) ---------------------------
if [ -x "$project_root/node_modules/.bin/bsc" ]; then
  bsc_cmd=("$project_root/node_modules/.bin/bsc")
elif command -v bsc >/dev/null 2>&1; then
  bsc_cmd=(bsc)
else
  bsc_cmd=(npx --no-install bsc)
fi

# --- validate only: no package, no staging, errors only ---------------------
# shellcheck disable=SC2206
extra=(${BSC_VALIDATE_EXTRA_ARGS:-})
out="$("${bsc_cmd[@]}" --project "$bsconfig" \
        --create-package false --copy-to-staging false \
        --diagnostic-level error "${extra[@]}" 2>&1)"
status=$?

if [ "$status" -ne 0 ]; then
  {
    echo "✖ bsc rejected BrightScript in this project (edited: $file_path)."
    echo "  Fix the error-level diagnostics below, then save again."
    echo "  bsc is a pre-flight gate, not the device — known false positives"
    echo "  (e.g. 'next i') are listed in grammar/BSC_DRIFT.md. Disable: BSC_VALIDATE_HOOK=0"
    echo "  ---"
    printf '%s\n' "$out" | grep -vE '^\s*$' | tail -n 40
  } >&2
  exit 2
fi
exit 0
