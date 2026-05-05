#!/usr/bin/env bash

set -e

# Get the current directory. Normalize backslashes to forward slashes
# and convert msys-style /c/ paths to C:/ so the comparison works
# regardless of how SAW or pwd reports the path.
normalize_path() {
    sed 's,\\,/,g' | sed -E 's,^/([a-zA-Z])/,\1:/,' | tr '[:upper:]' '[:lower:]'
}

HERE=$(pwd | normalize_path)
RES=$(printf '%s\n%s\n%s\n' ':pwd' 'include "err/err.saw"' ':pwd' | \
    $SAW --interactive --no-color | \
    normalize_path | \
    sed -r '/^\s*$/d' | \
    sort | \
    uniq -d)
[[ "$RES" =~ .*"$HERE".* ]]
