#!/usr/bin/env bash
# Run vim-plug install. Requires a TTY (PlugInstall is interactive-ish).
set -euo pipefail

if ! command -v vim >/dev/null 2>&1; then
	exit 0
fi

if [[ ! -t 0 || ! -t 1 ]]; then
	printf 'skip: vim PlugInstall (no TTY). Run manually: vim +PlugInstall +qa\n' >&2
	exit 0
fi

vim '+PlugInstall --sync' +qa || true
