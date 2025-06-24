#!/usr/bin/env bash
# csvlinter‑action helper
# ----------------------------------------------------------------------
# * Downloads csvlinter (<version>|latest) for the runner's OS/arch
# * Expands INPUT_PATHS glob(s) (comma‑separated, defaults **/*.csv)
# * Runs `csvlinter validate` on each file, respecting optional overrides
# * Stops early when INPUT_MAX_FAILURES (0 = unlimited) is reached
# * Emits detailed output **only** for failing files to keep successful logs minimal
# * Writes `files_checked` and `errors_found` to $GITHUB_OUTPUT when available

set -euo pipefail

# Inputs (provided by composite action or `export` when local testing)
CSVLINTER_VERSION="${INPUT_CSVLINTER_VERSION:-latest}"
INPUT_PATHS="${INPUT_PATHS:-**/*.csv}"
INPUT_SCHEMA="${INPUT_SCHEMA:-}"
INPUT_DELIMITER="${INPUT_DELIMITER:-}"
INPUT_FAIL_FAST="${INPUT_FAIL_FAST:-false}"
INPUT_MAX_FAILURES="${INPUT_MAX_FAILURES:-0}"

# Detect OS / arch → release asset name
OS=$(uname -s | tr '[:upper:]' '[:lower:]')   # linux | darwin | windows
ARCH=$(uname -m)
case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "::error ::unsupported arch $ARCH"; exit 1 ;;
esac

# Download csvlinter binary
BASE_URL="https://github.com/csvlinter/csvlinter/releases"
if [[ "$CSVLINTER_VERSION" == "latest" ]]; then
  DL_URL="$BASE_URL/latest/download/csvlinter-${OS}-${ARCH}.tar.gz"
else
  DL_URL="$BASE_URL/download/${CSVLINTER_VERSION}/csvlinter-${OS}-${ARCH}.tar.gz"
fi

echo "📥  Downloading $DL_URL"
TMPDIR=$(mktemp -d)
curl -sSLf "$DL_URL" | tar -xz -C "$TMPDIR"
LINTER="$TMPDIR/csvlinter"
chmod +x "$LINTER"

# Expand globs to file list
IFS=',' read -ra PATTERNS <<< "$INPUT_PATHS"
shopt -s globstar nullglob
FILES=()
for pat in "${PATTERNS[@]}"; do
  [[ $pat == ~* ]] && pat="${pat/#~/$HOME}"
  for f in $pat; do FILES+=("$f"); done
done
shopt -u globstar

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "::warning ::No CSV files matched '$INPUT_PATHS'"
  echo "All CSV files passed"
  exit 0
fi

echo "🔍  Running csvlinter on ${#FILES[@]} file(s) (max failures: ${INPUT_MAX_FAILURES:-unlimited})"

# Lint loop with minimal success output
failed_files=0
for f in "${FILES[@]}"; do
  args=()
  [[ -n "$INPUT_SCHEMA" ]]     && args+=(--schema "$INPUT_SCHEMA")
  [[ -n "$INPUT_DELIMITER" ]]  && args+=(--delimiter "$INPUT_DELIMITER")
  [[ "$INPUT_FAIL_FAST" == "true" ]] && args+=(--fail-fast)

  output=$("$LINTER" validate "${args[@]}" "$f" 2>&1)
  exit_code=$?

  # Determine if this file failed (non‑zero exit OR "INVALID" status)
  if (( exit_code != 0 )) || grep -qE "Status:[[:space:]]+✗[[:space:]]+INVALID" <<< "$output"; then
    echo "— $f" # show the failing filename
    echo "$output"
    ((failed_files++))
    if [[ "$INPUT_MAX_FAILURES" != "0" && "$failed_files" -ge "$INPUT_MAX_FAILURES" ]]; then
      echo "::warning ::Reached failure limit ($INPUT_MAX_FAILURES); stopping early to keep logs manageable"
      break
    fi
  else
    echo "✓ $f" # concise success marker
  fi

done

# Write outputs & final status
{
  echo "files_checked=${#FILES[@]}"
  echo "errors_found=$failed_files"
} >> "${GITHUB_OUTPUT:-/dev/null}" 2>/dev/null || true

if (( failed_files > 0 )); then
  echo "::error ::csvlinter found $failed_files file(s) with violations"
  exit 1
fi

echo "All CSV files passed"