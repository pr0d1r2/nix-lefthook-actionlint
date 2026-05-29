# shellcheck shell=bash
# Lefthook-compatible actionlint wrapper.
# Usage: lefthook-actionlint file1.yml [file2.yaml ...]
# Non-.yml/.yaml files are skipped silently.
# NOTE: sourced by writeShellApplication --no shebang or set needed.

if [ $# -eq 0 ]; then
    exit 0
fi

files=()
for f in "$@"; do
    [ -f "$f" ] || continue
    case "$f" in
        *.yml | *.yaml) files+=("$f") ;;
    esac
done

if [ ${#files[@]} -eq 0 ]; then
    exit 0
fi

exec actionlint "${files[@]}"
