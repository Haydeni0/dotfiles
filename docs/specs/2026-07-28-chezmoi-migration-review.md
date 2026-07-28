# Review: chezmoi Migration Design Spec

**Spec**: `docs/specs/2026-07-28-chezmoi-migration-design.md`
**Reviewer**: opencode (glm-5.2)
**Date**: 2026-07-28

---

## Critical Issues (must fix before implementation)

### C1. `configs/` directory not in `.chezmoiignore` - would deploy to `~/configs/`

The spec's `.chezmoiignore` (lines 396-413) ignores `flake.nix`, `flake.lock`, `home/`, `hosts/`, `rebuild.sh`, and platform-specific files. It does NOT ignore `configs/`, `docs/`, `AGENTS.md`, `README.md`, `MEMORY.md`, or `CLAUDE.md`.

Since chezmoi's source directory is the repo root (after `chezmoi init`), every file without a recognized chezmoi prefix (`dot_`, `private_`, etc.) is still deployed as a plain file. `configs/` (no prefix) deploys to `~/configs/`. `docs/` deploys to `~/docs/`. `README.md` deploys to `~/README.md`. `AGENTS.md` deploys to `~/AGENTS.md`.

The `configs/` directory is meant to be a data store for `{{ include }}` in templates, NOT deployed directly. It MUST be in `.chezmoiignore`.

**Fix**: Add to `.chezmoiignore`:
```
configs/
docs/
AGENTS.md
README.md
MEMORY.md
CLAUDE.md
```

Note: `{{ include "configs/..." }}` still works when `configs/` is in `.chezmoiignore` - `include` reads from the source state, ignore only prevents deployment to the target.

### C2. Missing `.tmpl` suffix on chezmoi wrapper files - `include` won't work

The spec's architecture says `configs/` is "THE source of truth" and the `dot_*` files are wrappers (e.g., `dot_zshrc # chezmoi: -> configs/zshrc`). But `dot_zshrc`, `dot_tmux.conf`, `private_dot_gitconfig`, `dot_config/starship.toml`, `dot_config/herdr/config.toml`, and `dot_zsh/aliases.zsh` are all shown WITHOUT `.tmpl` suffix.

Without `.tmpl`, chezmoi treats these as plain files (no template processing). They cannot use `{{ include "configs/..." }}`. They would deploy as empty files or whatever literal content they contain.

Only `dot_bashrc.tmpl` (line 56) has the `.tmpl` suffix and shows the include pattern (lines 192-198).

**Fix**: Either:
- (a) Add `.tmpl` to all wrapper files and use `{{ include "configs/..." }}` - this makes `configs/` the true single source of truth. All wrapper files become `dot_zshrc.tmpl`, `dot_tmux.conf.tmpl`, `private_dot_gitconfig.tmpl`, `dot_config/starship.toml.tmpl`, `dot_config/herdr/config.toml.tmpl`, `dot_zsh/aliases.zsh.tmpl`.
- (b) Put the content directly in the `dot_*` files and drop `configs/` entirely. But this contradicts the "configs/ is THE source of truth" architecture.

Option (a) is consistent with the spec's stated architecture. The content in the "Config file contents" section (lines 78-394) would go into `configs/`, and each `dot_*.tmpl` file would be a one-liner include.

### C3. No PATH setup for Mac (login shell is zsh, not bash)

The spec puts PATH setup (`export PATH="$HOME/.local/bin:$PATH"`) only in `configs/bashrc.linux` (line 160) and `configs/bashrc.darwin` (line 179).

On Mac, the login shell is zsh (the spec acknowledges this at line 178: "zsh is default shell on macOS"). `.bashrc` does not run for zsh login shells. So `~/.local/bin` never gets added to PATH on Mac. Tools installed there (`local-claude`, `local-opencode`, etc.) would be unreachable.

On Linux, the flow works: bash login -> `.bashrc` sets PATH -> `exec zsh -l` -> zsh inherits PATH.

**Fix**: Add a `dot_zprofile.tmpl` (or `dot_zshenv`) that sets PATH on both platforms, or add PATH setup to `configs/zshrc`. A `.zprofile` runs for login shells; `.zshenv` runs for all shells. For PATH, `.zprofile` is conventional:
```zsh
# .zprofile
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"
```
This runs on both Mac (zsh login) and Linux (zsh -l from bashrc). Then `.bashrc`'s PATH setup becomes redundant but harmless.

### C4. Linux install script incomplete - 11 of 17 tools missing

The spec's package list (lines 24-26) includes: ripgrep, fd, fzf, jq, lazygit, neovim, bat, gh, delta, yazi, gdu, rsync, starship, zoxide, btop, rclone, herdr, uv.

The `run_once_install-linux.sh.tmpl` (lines 231-280) only installs: starship, zoxide, fzf, nvim, herdr, zsh plugins. It has a comment for bat/ripgrep/fd (line 263: `# bat, ripgrep, fd - static binaries from GitHub releases`) but doesn't implement it.

Missing from the Linux install script: `bat`, `ripgrep`, `fd`, `jq`, `lazygit`, `gh`, `delta`, `yazi`, `gdu`, `rsync`, `btop`, `rclone`, `uv`.

The Brewfile (lines 202-227) includes all of these for Mac. But Linux gets no equivalent.

**Fix**: The install script needs to install all listed tools, or the spec needs to document which tools are expected to be system-provided on the HPC cluster (e.g., `rsync` is likely pre-installed). For each missing tool, add a download+install block (static binary from GitHub releases, or conda, or build from source). The spec should be explicit about the install method for each.

### C5. nvim appimage requires FUSE - may not work on HPC cluster

The Linux install script downloads nvim as an appimage (line 258):
```sh
curl -L -o ~/.local/bin/nvim https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
chmod u+x ~/.local/bin/nvim
```

AppImages require FUSE to mount the squashfs filesystem. On a no-root HPC cluster, FUSE is often unavailable (requires `/dev/fuse` and `fusermount`, which need root or specific group membership). The cluster currently uses bwrap (user namespaces), but FUSE is a separate kernel feature.

**Fix**: Either:
- (a) Extract the appimage: `./nvim.appimage --appimage-extract` and symlink to the extracted binary. Slower startup but no FUSE needed.
- (b) Build neovim from source (requires build tools).
- (c) Use conda if available on the cluster.
- (d) Download the static Linux binary from neovim's GitHub releases (if available for the target arch).

The spec should verify FUSE availability on the cluster and pick the approach that works without root.

### C6. Migration plan doesn't address removing HM-managed symlinks

The current setup has HM-managed symlinks in `$HOME` pointing to `/nix/store/...`:
- `~/.zshrc` -> `/nix/store/.../.zshrc`
- `~/.gitconfig` -> `/nix/store/.../.gitconfig`
- `~/.config/starship.toml` -> `/nix/store/.../starship.toml`
- `~/.config/herdr/config.toml` -> `/nix/store/.../config.toml`
- `~/.zshenv` (if HM creates one)
- `~/.profile` (if HM creates one)

Plus manually-created symlinks:
- `~/.tmux.conf` -> `~/.dotfiles/home/.tmux.conf`
- `~/.bashrc` -> `~/.dotfiles/home/.bashrc`
- `~/.dotfiles` -> `~/dotfiles`

When Nix is removed, the HM symlinks dangle (target doesn't exist). `chezmoi apply` would refuse to overwrite existing files (even dangling symlinks) by default.

The migration plan (lines 486-505) creates new files and removes old Nix files, but never addresses cleaning up the existing HM symlinks or manual symlinks before `chezmoi apply`.

**Fix**: Add a pre-`chezmoi apply` step:
```sh
# Remove HM-managed symlinks (dangling without /nix/store)
rm -f ~/.zshrc ~/.gitconfig ~/.config/starship.toml ~/.config/herdr/config.toml
# Remove manual symlinks (chezmoi will replace with real files)
rm -f ~/.tmux.conf ~/.bashrc ~/.dotfiles
# Remove HM profile (if exists)
rm -rf ~/.nix-profile ~/.local/state/nix
# Remove nix-portable
rm -rf ~/.nix-portable
```

Or run `home-manager uninstall` first (if nix is still functional), then clean up residuals.

Also: `chezmoi apply` has a `--force` flag (`chezmoi apply --force`) that overwrites existing files. But dangling symlinks might cause issues. Manual removal is safer.

### C7. Migration plan removes old files (step 15) before testing (steps 16-17)

Migration plan step 15 (line 502): "Remove old Nix files: `flake.nix`, `flake.lock`, `home/`, `hosts/`, `rebuild.sh`"
Migration plan steps 16-17 (lines 503-504): "Test on Linux", "Test on Mac"

If testing fails, the old files are already gone. There's no rollback path.

**Fix**: Reorder - test first, then remove:
```
15. Test on Linux (SSH to login node, `chezmoi init --apply`, verify)
16. Test on Mac (`chezmoi init --apply`, `brew bundle`, verify)
17. Remove old Nix files: `flake.nix`, `flake.lock`, `home/`, `hosts/`, `rebuild.sh`
18. Commit + push
```

Or keep old files in a branch/tag for rollback.

---

## Important Issues (should fix)

### I1. zsh plugins not installed on Mac

The zsh plugins (zsh-autosuggestions, zsh-syntax-highlighting, zsh-history-substring-search) are git-cloned by `run_once_install-linux.sh.tmpl` (lines 266-271). This script is Linux-only (guarded by `{{ if eq .chezmoi.os "linux" -}}`).

There is no Mac equivalent. The Brewfile doesn't include them (Homebrew has `zsh-autosuggestions` and `zsh-syntax-highlighting` formulae, but they install to Homebrew paths, not `~/.local/share/zsh/`).

The zshrc sources plugins from `~/.local/share/zsh/` (lines 137-145) with `[[ -r ... ]]` guards. On Mac, these guards silently fail, and the user loses autosuggestions and syntax highlighting.

**Fix**: Either:
- (a) Create a `run_once_install-plugins.sh.tmpl` (not platform-guarded) that clones zsh plugins on both platforms.
- (b) Add a `run_once_install-darwin.sh.tmpl` for Mac-specific installs.
- (c) Use Homebrew for zsh plugins on Mac and adjust the zshrc source paths (but Homebrew plugin paths differ from `~/.local/share/zsh/`).

Option (a) is simplest and maintains zero drift (same plugin source paths on both platforms).

### I2. `EDITOR=nvim` missing from zshrc

Current `shell.nix` line 89-91 sets `EDITOR = "nvim"` via HM sessionVariables. The spec's `configs/zshrc` (lines 82-146) does not set `EDITOR`. This would be lost in migration.

**Fix**: Add to `configs/zshrc`:
```zsh
export EDITOR=nvim
```

### I3. `_ZO_EXCLUDE_DIRS` missing from zshrc

Current `zoxide.nix` lines 12-15 set:
```nix
_ZO_EXCLUDE_DIRS = "$HOME:$HOME/.cache/*:$HOME/.local/share/*:/tmp/*";
_ZO_RESOLVE_SYMLINKS = "1";
```

The spec's zshrc doesn't set `_ZO_EXCLUDE_DIRS`. Without it, zoxide indexes `$HOME`, `.cache/`, `.local/share/`, `/tmp/` - polluting the frecency database with junk directories.

`_ZO_RESOLVE_SYMLINKS` was set because of Nix store symlinks; without Nix, it may not be needed. But `_ZO_EXCLUDE_DIRS` is still important.

**Fix**: Add to `configs/zshrc`, before the zoxide block:
```zsh
export _ZO_EXCLUDE_DIRS="$HOME:$HOME/.cache/*:$HOME/.local/share/*:/tmp/*"
```

### I4. herdr not installed on Mac

The Brewfile comments out herdr (lines 225-226):
```ruby
# herdr (if available via brew, otherwise manual install)
# brew "herdr"  # may not be in homebrew - use curl install if needed
```

There's no Mac install script for herdr. The Linux install script has `curl -fsSL https://herdr.dev/install.sh | sh` (line 275), but it's inside the Linux-only block.

herdr is listed as a package for "both platforms" (line 27), but it's only installed on Linux.

**Fix**: Either:
- (a) Verify if herdr is in Homebrew. If yes, uncomment the Brewfile line.
- (b) Create a `run_once_install-darwin.sh.tmpl` with the curl install.
- (c) Move the herdr curl install to a platform-agnostic `run_once_install-herdr.sh.tmpl`.

### I5. `cat` aliased to `bat -p` unconditionally - breaks if bat missing

The spec's `configs/zsh/aliases.zsh` line 314: `alias cat='bat -p'`.

This is set unconditionally (aliases.zsh is sourced without guards, line 105). If bat isn't installed (e.g., fresh Linux before install script runs, or install failed), `cat` breaks - a fundamental command becomes unusable.

The current setup uses `${pkgs.bat}/bin/bat -p` which always exists in the Nix namespace. Without Nix, it's PATH-dependent.

**Fix**: Guard the alias:
```zsh
if command -v bat >/dev/null 2>&1; then
    alias cat='bat -p'
fi
```
Or move it out of aliases.zsh into the zshrc where other `command -v` guards live.

### I6. `run_once_` script uses `command -v` checks that are PATH-dependent

The install script uses `if ! command -v starship &>/dev/null` (line 241) to check if starship is already installed. But `~/.local/bin` may not be on PATH when the script runs (chezmoi runs the script with the current environment, not a fresh shell with `.bashrc`/`.zshrc` sourced).

If `~/.local/bin` isn't on PATH, `command -v starship` fails even if starship is installed at `~/.local/bin/starship`. The script would reinstall every time it's force-run.

**Fix**: Use file existence checks instead:
```sh
[[ -x ~/.local/bin/starship ]] || curl -sS https://starship.rs/install.sh | sh -s -- -y -b ~/.local/bin
```

The zsh plugin checks already use `[[ -d ... ]]` (lines 266-271) which is correct. Apply the same pattern to all tool checks.

### I7. nvim `lazy-lock.json` conflict with chezmoi

The nvim config includes `lazy-lock.json` (currently at `home/.config/nvim/lazy-lock.json`). This file is auto-updated by lazy.nvim when plugins are added/updated.

If chezmoi manages this file, every `chezmoi apply` would revert it to the committed version, potentially undoing plugin updates. Conversely, if the user updates plugins (nvim writes a new `lazy-lock.json`), `chezmoi diff` would show a diff, and the next `chezmoi apply` would revert it.

**Fix**: Exclude `lazy-lock.json` from chezmoi management. Add to `.chezmoiignore`:
```
.config/nvim/lazy-lock.json
```
Or use chezmoi's `lazy-lock.json` as a template that's only written once. The simplest approach: ignore it.

### I8. bashrc.linux missing interactive shell check

Current `.bashrc` lines 4-7:
```bash
case $- in
    *i*) ;;
      *) return;;
esac
```

This returns early for non-interactive bash (e.g., `bash script.sh`). The spec's `configs/bashrc.linux` (lines 150-173) omits this check. The SSH agent block (lines 152-157), `AWS_PROFILE` export (line 159), and PATH export (line 160) would run for all bash invocations, including non-interactive scripts. Starting an SSH agent for a script is unwanted side effects.

**Fix**: Add the interactive check at the top of `configs/bashrc.linux`:
```bash
case $- in
    *i*) ;;
      *) return;;
esac
```

### I9. uv env script not sourced in bashrc.linux

Current `.bashrc` line 18: `. "$HOME/.local/bin/env" 2>/dev/null`

This sources uv's environment script (sets up `~/.local/bin` and uv-related PATH). The spec's `configs/bashrc.linux` omits it.

The spec's Brewfile includes `brew "uv"` (line 223) for Mac, but `uv` is NOT in the Linux install script. So on Linux, uv won't be installed, and the env script won't exist. On Mac, Homebrew's uv doesn't create `~/.local/bin/env`.

**Fix**: Either:
- (a) Add uv to the Linux install script (`curl -LsSf https://astral.sh/uv/install.sh | sh` installs to `~/.local/bin` and creates `~/.local/bin/env`).
- (b) Remove the uv env source line (if uv's PATH setup is handled elsewhere).
- (c) Document that uv is installed separately on each platform.

The spec's "What stays manual" section mentions "uv-managed tools" (line 524) but uv itself needs to be installed first. Add uv to both the Brewfile (already done) and the Linux install script.

### I10. herdr `default_shell = "zsh"` - verify herdr supports PATH resolution

The spec changes herdr's `default_shell` from `/mnt/home/hayden.dorahy/.local/bin/nix-zsh` (absolute path) to `"zsh"` (bare name, line 369).

The spec's comment says "zsh resolved via PATH (works on both platforms without hardcoding paths)". But if herdr expects an absolute path and doesn't do PATH resolution, panes would fail to spawn.

The current config uses an absolute path. The spec should verify herdr's behavior with a bare command name before committing to this change.

**Fix**: Test `default_shell = "zsh"` with herdr on both platforms. If herdr requires an absolute path, use a template:
```toml
{{ if eq .chezmoi.os "darwin" -}}
default_shell = "/bin/zsh"
{{ else -}}
default_shell = "/usr/bin/zsh"
{{ end -}}
```
Or use `which zsh` at install time to determine the path and write it to the config.

But this breaks "zero drift" (different config files on each platform). The better approach: verify herdr supports PATH resolution, or file a feature request.

### I11. pi-node and `.opencode/bin` PATH entries not addressed

Current `hosts/remote.nix` sets `sessionPath`:
```nix
home.sessionPath = [
    "$HOME/.nix-profile/bin"
    "$HOME/.local/bin"
    "$HOME/.local/share/pi-node/node-v22.23.1-linux-x64/bin"
    "$HOME/.opencode/bin"
];
```

The spec drops `$HOME/.nix-profile/bin` (Nix is gone) but doesn't address `$HOME/.local/share/pi-node/...` or `$HOME/.opencode/bin`. These are user-specific PATH entries that need to be in `.zshrc` or `.zprofile` for the new setup.

**Fix**: Add to `.zprofile` or `.zshrc`:
```zsh
export PATH="$HOME/.local/bin:$HOME/.local/share/pi-node/node-v22.23.1-linux-x64/bin:$HOME/.opencode/bin:$PATH"
```

Or document them in the "make it yours" section of the README.

---

## Minor Issues (nice to fix)

### M1. `SHARE_HISTORY` added without documentation

The spec's zshrc line 87 adds `SHARE_HISTORY` to `setopt`:
```zsh
setopt HIST_IGNORE_ALL_DUPS HIST_FIND_NO_DUPS EXTENDED_HISTORY HIST_REDUCE_BLANKS SHARE_HISTORY
```

Current `shell.nix` line 54 does NOT include `SHARE_HISTORY`:
```nix
setopt HIST_IGNORE_ALL_DUPS HIST_FIND_NO_DUPS EXTENDED_HISTORY HIST_REDUCE_BLANKS
```

`SHARE_HISTORY` shares history between concurrent shells (each command is immediately available in other shells). This is a behavioral change. If intentional, document it. If accidental, remove it.

### M2. `private_dot_gitconfig` overly restrictive

The spec uses `private_dot_gitconfig` (line 58) which sets `~/.gitconfig` to mode 0600. The current HM-managed `.gitconfig` has normal permissions (0644). The gitconfig contains no secrets (just `push.autoSetupRemote` and `rerere.enabled`). Mode 0600 is overly restrictive but harmless.

**Fix**: Use `dot_gitconfig.tmpl` (or `dot_gitconfig` if not a template) instead of `private_dot_gitconfig.tmpl`.

### M3. `alias btop='btop'` is a no-op

The spec's aliases.zsh line 315: `alias btop='btop'`. This is a no-op (aliasing a command to itself). The current `shell.nix` line 66 has `btop = "${pkgs.btop}/bin/btop"` which was meaningful (pointing to the Nix path). Without Nix, `btop` resolves via PATH, so the alias is pointless.

**Fix**: Remove `alias btop='btop'` from aliases.zsh.

### M4. gitignore listed but no content, no chezmoi mapping, no `core.excludesFile`

The spec's repo structure (line 54) shows `configs/gitignore` (global gitignore), but:
- No content is provided (unlike every other config file)
- No `dot_gitignore` chezmoi file is listed (lines 55-65)
- The gitconfig (lines 353-358) doesn't set `core.excludesFile` to point at it
- The current setup has no global gitignore (git.nix only sets push and rerere)

This is a new feature that's incompletely specified.

**Fix**: Either provide the gitignore content and a chezmoi mapping (`dot_gitignore.tmpl` with `{{ include "configs/gitignore" }}`), and add `core.excludesFile = ~/.gitignore` to the gitconfig. Or remove `gitignore` from the structure entirely.

### M5. `.chezmoi.toml.tmpl` listed but contents not shown

The spec lists `.chezmoi.toml.tmpl` (line 69) in the repo structure and in migration plan step 4 (line 491), but never shows its contents. If there are no custom chezmoi data variables (the spec only uses `.chezmoi.os` which is built-in), this file may not be needed. If it defines custom variables (e.g., `.chezmoi.data.username`), the contents should be shown.

**Fix**: Either show the contents or remove it from the structure if unnecessary.

### M6. fzf `--zsh` flag requires fzf 0.48+

The zshrc line 133: `source <(fzf --zsh)`. The `--zsh` flag was introduced in fzf 0.48.0 (2024). If the system has an older fzf, this fails. The guard `command -v fzf` (line 132) only checks existence, not version.

On Linux, fzf is installed via the install script (latest from git), so this is fine. On Mac, Homebrew provides current fzf. On systems with old system fzf, this would break.

**Fix**: Add a version check or use the older `fzf --init` approach with a fallback. Or document the minimum fzf version requirement.

### M7. TPM (tmux plugin manager) not mentioned

The tmux config (current `.tmux.conf` lines 133-139) auto-installs TPM on first launch. The spec deploys `.tmux.conf` via chezmoi but doesn't mention TPM as a dependency or include it in the install script.

TPM auto-installs from the tmux config, so this works, but the spec should document it (especially since it requires network on first launch).

### M8. nvim edit-in-place workflow change not documented

Currently, nvim config is edit-in-place (symlinked to the repo via `mkOutOfStoreSymlink`). Changes to `home/.config/nvim/*.lua` take effect immediately.

With chezmoi, nvim config would be in `configs/nvim/` (source) and deployed to `~/.config/nvim/` (target). Editing the source requires `chezmoi apply` (or `chezmoi edit --apply`) to deploy. This is a workflow change for nvim config editing.

**Fix**: Document in the README that nvim config edits require `chezmoi apply` (or use `chezmoi edit` which opens source files, then `chezmoi apply`). Or use `chezmoi edit --watch` for auto-apply on save.

### M9. MEMORY.md not addressed in migration plan

The current MEMORY.md has Nix/bwrap-specific learnings (proot orphans, bwrap compinit, herdr segfault, etc.). After migration, these are irrelevant. The migration plan doesn't mention rewriting MEMORY.md.

**Fix**: Add a migration step to rewrite MEMORY.md (remove Nix/bwrap entries, add chezmoi-specific learnings).

### M10. `.dotfiles` symlink cleanup not mentioned

The current setup creates `~/.dotfiles -> ~/dotfiles` (README step 2). This was needed for `mkOutOfStoreSymlink` in editor.nix. After migration, chezmoi manages nvim directly, so this symlink is no longer needed. The spec doesn't mention cleaning it up.

**Fix**: Add to the migration cleanup step: `rm -f ~/.dotfiles`.

---

## Missing Content (spec doesn't cover but should)

### X1. Full aliases list truncated

The spec's `configs/zsh/aliases.zsh` (lines 286-335) says "full ~90 alias set" but truncates at line 326 with "# ... (full set - see current aliases.nix for the complete list)". The implementation agent would need to manually copy from `aliases.nix`.

The full set should be in the spec (or the spec should explicitly say "copy all entries from `home/aliases.nix` and `home/shell.nix` shellAliases, converting from Nix attrset to `alias name='value'`").

### X2. New README.md content not specified

Migration plan step 13 (line 500): "Rework `README.md` (remove all Nix/bwrap/proot docs, add chezmoi setup)". No content or outline is provided. The current README is 226 lines of Nix/bwrap documentation.

The spec should at least provide an outline of the new README sections.

### X3. New AGENTS.md content not specified

Migration plan step 14 (line 501): "Rework `AGENTS.md` (remove Nix/bwrap rules, add chezmoi guidance)". No content is provided. The current AGENTS.md has Nix-specific principles (never reintroduce proot, tmux outside bwrap, nix-zsh wrapper, etc.).

The spec should provide the new AGENTS.md content or outline (chezmoi workflow, how to add packages, how to test, etc.).

### X4. `.chezmoi.toml.tmpl` contents

As noted in M5, the contents of this file are not shown. If it exists, its content should be specified.

### X5. gitignore content

As noted in M4, the gitignore content is not provided. If it's a new addition, the content should be specified (or the feature should be dropped).

### X6. Backup strategy before migration

The spec doesn't mention backing up the current working setup before starting the migration. The current README (lines 107-117) has a backup step. The migration plan should include a backup step.

### X7. Rollback plan

The migration plan has no rollback path. If the migration fails midway, there's no documented way to return to the working Nix setup. At minimum, the spec should say: "Keep the old Nix files in a git branch until the new setup is verified."

### X8. Verification checklist for migration

The migration plan steps 16-17 say "test on Linux/Mac" but don't specify what to test. A verification checklist would help:
- zsh starts with starship prompt
- `z <tab>` shows zoxide completions
- `alias g` shows `git`
- fzf Ctrl+R works
- tmux launches, prefix key works
- herdr launches, panes spawn
- nvim launches, plugins load
- `which starship` / `which zoxide` / `which bat` resolve correctly
- Same config files on both platforms (`diff` key files)

---

## chezmoi Syntax Corrections

### S1. `.chezmoiignore` pattern for `run_once_` script may be wrong

The spec's `.chezmoiignore` (line 411):
```
{{ if ne .chezmoi.os "linux" -}}
run_once_install-linux.sh
{{ end -}}
```

`.chezmoiignore` patterns match against **target paths** (paths in the destination directory, i.e., `$HOME`). For `run_once_` scripts, chezmoi computes the target path by stripping chezmoi attributes:
- `run_once_install-linux.sh.tmpl` -> strip `run_once_` -> `install-linux.sh.tmpl` -> strip `.tmpl` -> `install-linux.sh`

So the target path is `install-linux.sh`, and the ignore pattern should be `install-linux.sh`, not `run_once_install-linux.sh`.

However, this needs verification - chezmoi's exact behavior for `run_once_` script target paths in `.chezmoiignore` may differ. The safer approach: since the script already has a template conditional `{{ if eq .chezmoi.os "linux" -}}` (line 235), the script produces empty output on Mac. The `run_once_` hash tracking would record this and not re-run. The `.chezmoiignore` entry may be unnecessary entirely.

**Fix**: Either:
- (a) Remove the `run_once_install-linux.sh` entry from `.chezmoiignore` (the template conditional handles platform selection).
- (b) Change to `install-linux.sh` (if the pattern matching works this way).
- (c) Test which pattern actually works.

### S2. `.chezmoiignore` entries for `home/` and `hosts/` use trailing slash

The spec has `home/` and `hosts/` in `.chezmoiignore` (lines 403-404). In chezmoi, patterns follow glob matching. `home/` with a trailing slash matches the directory. Without the trailing slash, `home` would also match `home/` and any `home*` file. The trailing slash is correct for directories. ✓

But after migration, `home/` and `hosts/` are deleted (step 15). So these entries are temporary. They could be removed after migration. Not a syntax error, just a note.

### S3. Template whitespace in `dot_bashrc.tmpl`

The spec's `dot_bashrc.tmpl` (lines 192-198):
```go
{{ if eq .chezmoi.os "darwin" -}}
{{   include "configs/bashrc.darwin" -}}
{{ else -}}
{{   include "configs/bashrc.linux" -}}
{{ end -}}
```

The `-}}` trims trailing whitespace (including newlines). The `{{` without `-` does not trim leading whitespace. But since the template action `{{ ... }}` consumes everything between the braces (including the spaces before `include`), no leading whitespace is output. The output is clean: just the content of the included file. ✓

This syntax is correct.

### S4. `include` function path is relative to source directory

The spec uses `{{ include "configs/bashrc.linux" }}`. In chezmoi, `include` reads from the source directory. The path `configs/bashrc.linux` is relative to the source root. This is correct IF `configs/` is in the source directory (which it is - the repo root is the source directory). ✓

But `configs/bashrc.linux` must exist in the source state. If `configs/` is in `.chezmoiignore`, it's still in the source state (`.chezmoiignore` only prevents deployment, not source state access). So `include` still works. ✓

---

## Overall Assessment

**Not ready for implementation.** The spec has a solid architecture (drop Nix, use chezmoi, runtime guards) and correctly identifies the root cause of the current problems. But it has 7 critical issues that would cause an implementation agent to produce a broken setup:

1. `configs/` would be deployed to `~/configs/` (C1)
2. Template `include`s won't work without `.tmpl` suffixes (C2)
3. Mac has no PATH setup (C3)
4. 11 of 17 tools missing from Linux install script (C4)
5. nvim appimage needs FUSE which may not exist on the cluster (C5)
6. HM symlinks not cleaned up before `chezmoi apply` (C6)
7. Old files removed before testing (C7)

Additionally, 11 important issues (zsh plugins on Mac, EDITOR, zoxide env vars, herdr on Mac, cat alias, install script checks, lazy-lock.json, bashrc interactive check, uv env, herdr default_shell, missing PATH entries) would cause a degraded or incorrect experience.

The chezmoi syntax is mostly correct (the `dot_bashrc.tmpl` template is well-formed), but the `.chezmoiignore` for `run_once_` scripts needs verification (S1), and the fundamental architecture of `configs/` as source-of-truth with `dot_*.tmpl` wrappers needs to be made consistent (C2).

**Recommendation**: Address all critical issues and most important issues before handing to an implementation agent. The minor issues and missing content can be addressed during implementation with guidance from this review.
