# Dotfiles

Personal `~/` configuration, organized as one directory per tool. Heavily
inspired by [Dave Eddy's dotfiles](https://github.com/bahamas10/dotfiles) and
the patterns at [dotfiles.github.io](https://dotfiles.github.io/).

## Install

```sh
git clone --recurse-submodules git@github.com:<you>/dotfiles ~/repos/dotfiles
cd ~/repos/dotfiles
./install
```

The `install` script symlinks each tracked file from `<dir>/<name>` into
`~/.<name>` (or, for `vim`/`claude`/`ssh`/`extra_bins`, the whole directory).
Re-run it any time after pulling — it's idempotent.

> `install` will offer to install useful APT packages (or Homebrew on macOS).
> Say no if you'd rather manage them yourself.

## Layout

| Path           | What it provides                                                  |
|----------------|-------------------------------------------------------------------|
| `bash/`        | `bashrc`, `bash_profile`, exports, aliases, functions, `inputrc`  |
| `git/`         | `gitconfig`, `gitignore` (global), `gitattributes`, `gitk`        |
| `vim/`         | `vimrc`, `init.vim`, plugin submodules (pathogen-style)           |
| `tmux/`        | `tmux.conf`                                                        |
| `ssh/`         | `config` (per-host overrides; keys are git-ignored)               |
| `htop/`        | `htoprc`                                                           |
| `curl/wget/`   | rcfiles                                                            |
| `claude/`      | Claude Code config — agents, hooks, skills, settings              |
| `extra_bins/`  | Personal scripts dropped into `~/extra_bins` and added to `PATH`  |
| `shell/misc/`  | Small dotfiles like `hushlogin`, `urlview`                        |

## Per-host overrides

`bashrc` sources `~/.bashrc.local` if it exists. Use that file (not tracked)
for anything machine-specific: company proxies, work-only env vars, secrets,
exotic PATH entries.

```sh
# ~/.bashrc.local
export AWS_PROFILE=work
path_add "$HOME/work-tools/bin" before
```

## Quality gates

- **`./install`** — symlink everything; idempotent.
- **`./run-shellcheck.sh`** — shellchecks every `#!/usr/bin/env bash` script.
- **`pre-commit run --all-files`** — runs detect-secrets, gitleaks,
  shellcheck, trailing-whitespace, large-file checks, etc. (See
  `.pre-commit-config.yaml`.)

To enable pre-commit hooks locally:

```sh
pip install pre-commit  # or: brew install pre-commit
pre-commit install
```

## Optional packages

After `install`, run `install-optional` (in `extra_bins`) to set up tools
that aren't worth installing system-wide via apt — currently
[uv](https://docs.astral.sh/uv/).

## Notable bits

- `bash_functions` ships `path_add` / `path_remove` / `path_clean` for sane
  PATH hygiene, plus `gmb`/`gbd`/`gcm`/`gmm` for the `master`-vs-`main` mess,
  and helpers like `extract`, `bak`, `mkd`, `gho`, `targz`.
- `gitconfig` enables modern defaults: `init.defaultBranch=main`,
  `push.autoSetupRemote`, `fetch.prune`, `rerere`, `rebase.autoStash`,
  `diff.algorithm=histogram`, `merge.conflictStyle=zdiff3`.
- The bash prompt shows last exit code, user, host, OS, cwd and current git
  branch — themable via `set_prompt_colors <0-29>` in `.bashrc.local`.

## Adding a new tool

1. Create `<tool>/<configfile>` (no leading dot).
2. Add `<tool>` to the `dotfile_folders=(...)` list in `install`.
3. Add the toggle to `.config` if you want install-time gating.
4. Run `./install` to verify the symlink lands at `~/.<configfile>`.
