# Dotfiles

Personal `~/` configuration, managed with [chezmoi](https://www.chezmoi.io/).
Heavily inspired by [Dave Eddy's dotfiles](https://github.com/bahamas10/dotfiles)
and the patterns at [dotfiles.github.io](https://dotfiles.github.io/).

## Install

```sh
git clone --recurse-submodules git@github.com:<you>/dotfiles ~/repos/dotfiles
cd ~/repos/dotfiles
./install
```

`install` is a thin bootstrap: it installs `chezmoi` (if missing), points it at
this checkout via `--source=$PWD`, and runs `chezmoi apply`.

After bootstrap, manage everything with chezmoi directly:

```sh
chezmoi diff             # preview pending changes
chezmoi apply            # apply changes
chezmoi edit ~/.bashrc   # edit the source file
chezmoi update           # git pull + apply
chezmoi managed          # list everything chezmoi controls
```

To uninstall a single file: `chezmoi forget <target>` then delete the file
yourself. To uninstall everything: `chezmoi purge`.

## Layout

| Source path                                | What it produces                              |
|--------------------------------------------|-----------------------------------------------|
| `home/dot_bashrc`, `dot_bash_*`, …         | Real files at `~/.bashrc`, `~/.bash_*`, etc.  |
| `home/dot_gitconfig`, `dot_git*`           | `~/.gitconfig` etc.                           |
| `home/dot_tmux.conf`, `dot_curlrc`, …      | One file per name.                            |
| `home/symlink_dot_claude.tmpl`             | `~/.claude` → `<repo>/claude` (symlink)       |
| `home/symlink_dot_ssh.tmpl`                | `~/.ssh` → `<repo>/ssh` (symlink)             |
| `home/symlink_dot_vim.tmpl`                | `~/.vim` → `<repo>/vim/vim_folder` (symlink)  |
| `home/symlink_extra_bins.tmpl`             | `~/extra_bins` → `<repo>/extra_bins`          |
| `home/.chezmoiscripts/run_once_after_*`    | Locale, mac-bash, vim-plug, optional pkgs.    |
| `claude/`, `ssh/`, `vim/`, `extra_bins/`   | Live targets of the symlinks above.           |

`.chezmoiroot` makes chezmoi treat `home/` as the source dir while keeping the
working tree at the repo root, so the symlink templates can reach `claude/`,
`ssh/`, etc. via `{{ .chezmoi.workingTree }}`.

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

- **`./install`** — bootstrap chezmoi and apply.
- **`chezmoi diff`** — preview before apply.
- **`./run-shellcheck.sh`** — shellchecks every `#!/usr/bin/env bash` script.
- **`pre-commit run --all-files`** — detect-secrets, gitleaks, shellcheck,
  trailing-whitespace, large-file checks. (See `.pre-commit-config.yaml`.)

To enable pre-commit hooks locally:

```sh
pip install pre-commit  # or: brew install pre-commit
pre-commit install
```

## Optional packages

After `install`, run `install-optional` (in `extra_bins`) to set up tools
that aren't worth installing system-wide via apt — currently
[uv](https://docs.astral.sh/uv/).

The first interactive `chezmoi apply` also prompts whether to install a set
of useful packages (`ripgrep`, `jq`, `fzf`, …) via apt or Homebrew. Re-run
`chezmoi state delete-bucket --bucket=scriptState` if you want to be asked
again.

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

For a single file:

1. Drop it at `home/dot_<name>` (chezmoi will manage `~/.<name>`).
2. `chezmoi diff && chezmoi apply`.

For a whole directory you want to keep editing in-repo (like `claude/`):

1. Put the directory at the repo root.
2. Add `home/symlink_dot_<name>.tmpl` containing
   `{{ .chezmoi.workingTree }}/<dir>`.
3. `chezmoi apply`.

See the [chezmoi reference](https://www.chezmoi.io/reference/source-state-attributes/)
for the full list of source-state attributes (`private_`, `executable_`,
`encrypted_`, `run_onchange_`, etc.).
