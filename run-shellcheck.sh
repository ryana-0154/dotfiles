#!/usr/bin/env bash

# Author: Ryan A
# Date: November 02, 2025
# License: MIT
#
# Run shellcheck across every tracked file with a `#!/usr/bin/env bash`
# shebang. Excludes vendored submodules and bash_exports (which references
# externally-set vars).

set -uo pipefail

failed=0

while IFS= read -r file; do
    echo "==> $file"
    if ! shellcheck -S warning -- "$file"; then
        failed=1
    fi
done < <(
    find . -type f \
      -not -path '*/.git/*' \
      -not -path '*/vim/submodules/*' \
      -not -path '*/claude/skills/*' \
      -not -path '*/claude/agents/*' \
      -not -path '*/home/dot_bash_exports' \
      -exec grep -Il '^#!/usr/bin/env bash' {} +
)

exit "$failed"
