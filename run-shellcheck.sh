#!/usr/bin/env bash

# Author: Ryan A
# Date: November 02, 2025
# License: MIT

spinner() {
    local pid=$1
    local msg=$2
    local delay=0.1
    local spin='|/-\'

    # show spinner until pid exits
    while kill -0 "$pid" 2>/dev/null; do
        for ((i=0; i<${#spin}; i++)); do
            # 55-char left pad, then msg + spinner glyph
            printf '\r%55s %s' "$msg" "${spin:$i:1}"
            sleep "$delay"
        done
    done
}

find "." -type f \
  -not -path '*/.git/*' \
  -not -path '*/vim/submodules/*' \
  -not -path '*/bash/bash_exports' \
  -exec grep -Il '^#!/usr/bin/env bash' {} + | while read -r file; do

    echo "Processing $file"
    shellcheck $file -S warning
done
