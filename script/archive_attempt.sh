#!/usr/bin/env bash
# Safely archive an "attempt" folder into docs/tpp_register_artifacts/
# Excludes common secret/credential files automatically.
# Usage:
#   ./script/archive_attempt.sh <attempt-path-or-name> [--secrets-dir /absolute/path/to/secrets]
# Examples:
#   ./script/archive_attempt.sh script/attempts/guide_2026-04-09-texpert
#   ./script/archive_attempt.sh guide_2026-04-09-texpert --secrets-dir ./secrets/qseal

set -euo pipefail
IFS=$'\n\t'

show_help() {
  cat <<EOF
Usage: $0 <attempt-path-or-name> [--secrets-dir /absolute/path]

This script copies a non-secret view of an "attempt" folder into
docs/tpp_register_artifacts/<attempt>_<timestamp>/ while excluding
sensitive files automatically.

If --secrets-dir is provided, the script will copy the excluded (secret)
files into that directory under a folder named after the attempt. This
is useful to keep a canonical secret bundle under a git-ignored location.

Excluded patterns (default): *.key *.pem *.p12 *.pfx *.csr *.crt *private* *.jks id_rsa* texpert.zip

Examples:
  $0 script/attempts/guide_2026-04-09-texpert
  $0 guide_2026-04-09-texpert --secrets-dir ./secrets/qseal
EOF
}

if [[ ${#@} -eq 0 ]]; then
  show_help
  exit 0
fi

# Simple arg parsing: supports --dry-run and --secrets-dir <path>
DRY_RUN=false
ATTEMPT_ARG=""
SECRETS_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true; shift ;;
    --secrets-dir)
      SECRETS_DIR="$2"; shift 2 ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      if [[ -z "$ATTEMPT_ARG" ]]; then
        ATTEMPT_ARG="$1"
      else
        echo "Unknown extra argument: $1"; show_help; exit 1
      fi
      shift ;;
  esac
done

if [[ -z "$ATTEMPT_ARG" ]]; then
  echo "Attempt argument missing."; show_help; exit 1
fi

# Resolve attempt directory:
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
attempt_dir=""
if [[ -d "$ATTEMPT_ARG" ]]; then
  attempt_dir="$ATTEMPT_ARG"
elif [[ -d "script/attempts/$ATTEMPT_ARG" ]]; then
  attempt_dir="script/attempts/$ATTEMPT_ARG"
elif [[ -d "./$ATTEMPT_ARG" ]]; then
  attempt_dir="./$ATTEMPT_ARG"
elif [[ -d "$repo_root/secrets/qseal/$ATTEMPT_ARG" ]]; then
  attempt_dir="$repo_root/secrets/qseal/$ATTEMPT_ARG"
else
  echo "Attempt folder not found: $ATTEMPT_ARG"
  echo
  show_help
  exit 1
fi

# Normalize name and timestamp
attempt_name=$(basename "$attempt_dir")
timestamp=$(date -u +"%Y-%m-%d_%H%M%SZ")
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
artifacts_dir="$repo_root/docs/tpp_register_artifacts"
mkdir -p "$artifacts_dir"

out_dir="$artifacts_dir/${attempt_name}_$timestamp"
if [[ -e "$out_dir" ]]; then
  echo "Output path already exists: $out_dir"
  exit 1
fi

# If dry-run, do not create the real out directory yet; just simulate
if [[ "$DRY_RUN" == true ]]; then
  echo "DRY RUN: no files will be copied. The archive would be created at: $out_dir"
else
  mkdir -p "$out_dir"
fi

# Exclude patterns (add more if your policy requires). These will NOT be copied into docs.
EXCLUDES=(
  "--exclude=.git/"
  "--exclude=secrets/"
  "--exclude=*/secrets/*"
  "--exclude=*.key"
  "--exclude=*.pem"
  "--exclude=*.p12"
  "--exclude=*.pfx"
  "--exclude=*.csr"
  "--exclude=*.crt"
  "--exclude=*private*"
  "--exclude=*id_rsa*"
  "--exclude=*.jks"
  "--exclude=*.p7b"
  "--exclude=texpert.zip"
)

# Build rsync exclude args
RSYNC_EXCLUDES=()
for e in "${EXCLUDES[@]}"; do
  RSYNC_EXCLUDES+=("$e")
done

echo "Archiving attempt: $attempt_dir"
echo "Destination: $out_dir"

if [[ "$DRY_RUN" == true ]]; then
  echo "DRY RUN: rsync simulation (shows what would be copied)."
  # shellcheck disable=SC2086
  rsync -av --delete --human-readable --dry-run --itemize-changes "${RSYNC_EXCLUDES[@]}" "$attempt_dir/" "$out_dir/" || true

  # Show excluded files that would be omitted
  echo "\nDRY RUN: files that match excluded patterns (would be moved to secrets):"
  excluded_manifest="/tmp/${attempt_name}_excluded_files_${timestamp}.txt"
  > "$excluded_manifest"
  patterns=("*.key" "*.pem" "*.p12" "*.pfx" "*.csr" "*.crt" "*private*" "id_rsa*" "*.jks" "*.p7b" "texpert.zip")
  for p in "${patterns[@]}"; do
    find "$attempt_dir" -type f -name "$p" 2>/dev/null >> "$excluded_manifest" || true
  done
  if [[ -s "$excluded_manifest" ]]; then
    sed -n '1,200p' "$excluded_manifest"
    echo "\nDRY RUN: (total excluded files: $(wc -l < "$excluded_manifest" | tr -d ' '))"
  else
    echo "  (none)"
  fi

  if [[ -n "$SECRETS_DIR" ]]; then
    echo "\nDRY RUN: secrets would be copied to: $SECRETS_DIR/${attempt_name}_$timestamp"
  fi
else
  echo "Running rsync to copy non-secret files..."
  # shellcheck disable=SC2086
  rsync -av --delete --human-readable "${RSYNC_EXCLUDES[@]}" "$attempt_dir/" "$out_dir/"

  # Create a manifest of files that were excluded (for audit)
  excluded_manifest="$out_dir/EXCLUDED_FILES.txt"
  > "$excluded_manifest"

  # For each pattern, list matching files under attempt_dir and append to manifest
  patterns=("*.key" "*.pem" "*.p12" "*.pfx" "*.csr" "*.crt" "*private*" "id_rsa*" "*.jks" "*.p7b" "texpert.zip")
  for p in "${patterns[@]}"; do
    # use find to locate files; ignore errors if none
    while IFS= read -r f; do
      echo "$f" >> "$excluded_manifest"
    done < <(find "$attempt_dir" -type f -name "$p" 2>/dev/null || true)
  done

  # If secrets dir provided, copy only the excluded files into secrets location (preserve relative layout)
  if [[ -n "$SECRETS_DIR" ]]; then
    echo "Secrets dir provided: $SECRETS_DIR"
    # Ensure the secrets dir exists and get its absolute path robustly
    abs_secrets_dir="$(mkdir -p "$SECRETS_DIR" && cd "$SECRETS_DIR" && pwd)"
    target_secrets_dir="$abs_secrets_dir/${attempt_name}_$timestamp"
    mkdir -p "$target_secrets_dir"

    echo "Copying excluded files into: $target_secrets_dir"
    # loop the manifest and copy each file preserving relative path
    while IFS= read -r secret_file; do
      rel_path="${secret_file#$attempt_dir/}"
      dest_dir="$(dirname "$target_secrets_dir/$rel_path")"
      mkdir -p "$dest_dir"
      cp -p "$secret_file" "$dest_dir/" || true
    done < "$excluded_manifest"

    echo "Secrets copy completed. To keep secrets safe, ensure $abs_secrets_dir is git-ignored."
  fi
fi

# Summary
if [[ "$DRY_RUN" == true ]]; then
  copied_count="(dry-run)"
  if [[ -f "$excluded_manifest" ]]; then
    excluded_count=$(wc -l < "$excluded_manifest" | tr -d ' ')
  else
    excluded_count=0
  fi
else
  copied_count=$(find "$out_dir" -type f | wc -l | tr -d ' ')
  excluded_count=$(wc -l < "$excluded_manifest" | tr -d ' ')
fi

cat <<EOF
Archive complete.
  Attempt: $attempt_name
  Source: $attempt_dir
  Archive: $out_dir
  Files copied (approx): $copied_count
  Excluded files (listed): $excluded_count
  Excluded manifest: ${excluded_manifest:-N/A}

Review the archive and the excluded manifest. If you want to include additional patterns,
edit this script's EXCLUDES list.
EOF

exit 0
