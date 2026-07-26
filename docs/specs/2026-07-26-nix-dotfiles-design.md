# Nix dotfiles setup - design

- **Date:** 2026-07-26 (revised after reviewing the reference video's config)
- **Status:** Baseline plan, **remote-first**. Mac deferred to a later session (with another agent, which can read this spec).
- **Repo:** `~/gitrepos/dotfiles` (GitHub: `Haydeni0/dotfiles`, SSH host `github-haydeni0`). Working tree currently empty (`Fresh start with nothing`) - clean slate to build into.
- **Reference (the video's config):** `github.com/kunchenguid/dotfiles` (walkthrough: youtu.be/5N-okeDdIuI). Mac-only nix-darwin + home-manager setup. We adopt its `home.nix`/`home/` content as the template; we do NOT adopt its nix-darwin/Mac layer (deferred).

## Goal

A declarative, reproducible coding/terminal environment via **home-manager + flakes**, built **on this remote first**, with Mac to follow later in a separate session.

- **Remote (this box, `slurm-b200-201-219`)** - Ubuntu 22.04 on CoreWeave, x86_64, **no root**. Existing: zsh (a **manual `~/.local/bin/zsh` binary - no system zsh; Nix will replace it**) + oh-my-zsh + powerlevel10k (`.p10k.zsh`), tmux (`.tmux.conf`), git (`.gitconfig`), conda/mamba. Login shell `$SHELL=bash`. **Boot chain:** bash → `exec zsh -l` → `exec tmux new-session -A -s main` → zsh inside tmux. Tools `bat gh rg fzf fd` already in `~/.local/bin`; `tmux jq` from system.
- **Mac (later)** - deferred. That session decides nix-darwin vs standalone home-manager and adds a host module to this same repo.

## Settled decisions

1. **Scope (remote):** home-manager standalone manages packages + dotfiles. No system layer (nix-darwin is Mac-only and we have no root anyway).
2. **Remote Nix install:** rootless userspace Nix (Approach A) - lives in `$HOME`, no `/nix`, no daemon. **Exact tool to verify at implementation** (e.g. nix-portable or equivalent; these projects' status shifts - confirm current maintenance before relying on one). **Fallback:** Approach C (dotfiles-only on remote, no package management) if the rootless tooling proves too fragile on this cluster.
3. **Structure:** shared `home/` module + per-host `hosts/<host>.nix`. Forward-compatible: only `hosts/remote.nix` exists for now; `hosts/mac.nix` added later.
4. **Migration:** back up existing configs (and `~/.local/bin` tool copies) first, then port the good bits. User not attached to current configs but must not lose things.
5. **Repo:** existing `~/gitrepos/dotfiles` (GitHub `Haydeni0/dotfiles`), currently empty - ready to rebuild.

## Adopted from the video's config

- **Shell:** zsh + `autosuggestion` + `syntaxHighlighting` (lean home-manager plugins, **drop oh-my-zsh**). Aliases ported from the video's set + the user's `.zshrc`.
- **Prompt:** **starship** (simple `❯`), **not** powerlevel10k. User's `.p10k.zsh` backed up, not used.
- **Editor:** **Neovim** with lazy.nvim + rose-pine moon theme. Config files live in the repo (`home/.config/nvim/`), symlinked into `~/.config/nvim` via `mkOutOfStoreSymlink` (edit-in-place, no rebuild for nvim edits). Adopt the video's nvim config as the starting point; customize later.
- **Packages:** the video's set (ripgrep, fd, fzf, jq, lazygit, neovim) + delta + starship + the ones the user already uses (bat, gh, taken over from `~/.local/bin`).
- **herdr** (agent multiplexer - the video uses it instead of tmux for agent work): installed via its **Nix flake** input (herdr is not in nixpkgs at v0.7.5; herdr.dev lists "Nix flake" as an install method, x86_64-linux bottle confirmed available). The video installs it via Homebrew (`brews = [ "herdr" ]` in `configuration.nix`), but we have no Homebrew/root on the remote, so the flake path is the route. **herdr and tmux coexist** - tmux keeps the user's SSH-session persistence + custom hotkeys; herdr adds agent orchestration (blocked/working/done/idle state at a glance for claude/codex/opencode, which the user runs via `cc`/`oc` aliases). Exact flake URL/rev to confirm at implementation.
- **`mkOutOfStoreSymlink` pattern** for nvim config (and any future large config files that aren't worth expressing in Nix).
- **zoxide** (replaces the oh-my-zsh `z` plugin - the user's `.zshrc:88` had `plugins=(git z docker)`): home-manager's `programs.zoxide.enable = true` (verified in HM `modules/programs/zoxide.nix`) installs zoxide (nixpkgs v0.10.0, verified in `pkgs/by-name/zo/zoxide/package.nix`, builds on Linux x86_64) and auto-wires the zsh integration - drops `z` (and `zi` for interactive) into the shell, replacing the oh-my-zsh `z` plugin seamlessly. No `home.packages` entry needed - the module handles it. **History migration:** zoxide uses its own DB at `~/.local/share/zoxide/db.zo`; the old oh-my-zsh `z` history does not carry over. zoxide learns fresh from `cd` habits. Optional one-line import if the user wants to seed it.
- **yazi** (terminal file manager, Rust): `home.packages = [ pkgs.yazi ]` (verified in nixpkgs `pkgs/by-name/ya/yazi/package.nix`). No separate HM module - the nixpkgs package wraps `yazi` with its optional deps on PATH (jq, poppler, 7zz, ffmpeg, fd, ripgrep, fzf, zoxide, imagemagick, chafa, resvg) so previews + zoxide integration work out of the box. Optional: shell function `y()` to cd on quit (`~/.config/yazi/init.lua` or a zsh function) - decide at implementation. Note: upstream repo moved (yazi-rs org 404 on github) but nixpkgs tracks via `yazi-unwrapped` - non-issue.
- **btop** (resource monitor): `programs.btop.enable = true` (HM module verified at `modules/programs/btop.nix`; nixpkgs v1.4.7, verified at `pkgs/by-name/bt/btop/package.nix`, Linux + Darwin). **Replaces** the user's current `bpytop` (the older Python predecessor, installed via `uv tool install bpytop`, aliased as `btop` in `.bashrc:95`). The real btop (C++) is much faster. The `alias btop='bpytop'` line drops out. After Nix btop is verified, uninstall bpytop: `uv tool uninstall bpytop`. **GPU monitoring TBD:** nixpkgs btop supports `cudaSupport` and `rocmSupport` flags; the box is `slurm-b200-*` (NVIDIA B200s) so `cudaSupport` would add GPU stats - but it pulls in CUDA deps and complicates the build. Start without GPU support (default), add later if wanted.
- **gdu** (disk usage analyzer, Go-based, parallel for SSDs): `home.packages = [ pkgs.gdu ]` (nixpkgs v5.36.1, verified at `pkgs/by-name/gd/gdu/package.nix`; no HM module, just the package). Replaces the user's current `~/.local/bin/gdu` (manual install, moved aside like the other `~/.local/bin` tools).
- **rclone** (cloud storage sync, "rsync for cloud"): `programs.rclone.enable = true` (HM module verified at `modules/programs/rclone.nix`; nixpkgs v1.74.4, verified at `pkgs/by-name/rc/rclone/package.nix`). Currently not installed on the box. **Security: the HM module can manage `~/.config/rclone/rclone.conf`, but that file holds cloud-storage credentials (S3 keys, OAuth tokens, etc.) - per our "no secrets in the flake" rule, the config file stays MANUAL and gitignored.** The HM module is used only for the binary + shell completion. If the module requires a config attr, pass `null`/empty so HM does not write a config file; the user's manual `~/.config/rclone/rclone.conf` (if any) stays untouched.
- **rsync** (incremental file transfer): `home.packages = [ pkgs.rsync ]` (nixpkgs v3.4.4, verified at `pkgs/by-name/rs/rsync/package.nix`; no HM module). Currently `/usr/bin/rsync` (system, root-owned) - the Nix version shadows it via PATH (Nix bin precedes `/usr/bin`). No need to remove the system binary.

## NOT adopted from the video (skipped)

- **nix-darwin + nix-homebrew + macOS defaults** (`configuration.nix`) - Mac-only, deferred to the Mac session.
- **WezTerm** - GUI terminal, Mac-only (irrelevant over SSH).
- **nerd-fonts.hack** - fonts render on the client terminal, not the remote; useless over SSH.
- **AGENTS.md symlink trick** (`.claude/CLAUDE.md`, `.codex/AGENTS.md`, `.config/opencode/AGENTS.md` → one `AGENTS.md`) - **skip**. The user has their own elaborate agent-policy setup, separately sync'd (`~/.claude` is source of truth, `~/.config/opencode` is derived). Nix must not touch those.
- **Git identity omission** - the video deliberately omits `[user]`; the user explicitly wants the same here (see git below).

## Architecture

```
~/gitrepos/dotfiles/
├── flake.nix            # inputs: nixpkgs + home-manager + herdr (flake); defines homeConfigurations."hayden@remote"
│                        # (a darwinConfiguration / mac homeConfiguration is added later by the Mac session)
├── flake.lock           # pinned versions -> reproducible
├── home/                # shared module (will apply on Mac too, later)
│   ├── default.nix      # imports the shared modules below
│   ├── shell.nix        # zsh + starship + lean HM plugins + aliases
│   ├── packages.nix     # home.packages: ripgrep, fd, fzf, jq, lazygit, neovim, bat, gh, delta, herdr, uv, yazi, gdu, rsync
│   ├── btop.nix         # programs.btop (resource monitor - replaces the bpytop uv-tool + `alias btop=bpytop`)
│   ├── zoxide.nix       # programs.zoxide (replaces oh-my-zsh `z` plugin - "Fast cd that learns your habits")
│   ├── rclone.nix       # programs.rclone (binary + completion only - config/credentials stay manual, gitignored)
│   ├── git.nix          # push.autoSetupRemote + rerere.enabled ONLY (no user, no credential)
│   ├── tmux.nix         # port .tmux.conf via programs.tmux
│   └── editor.nix       # neovim: mkOutOfStoreSymlink ~/.config/nvim -> home/.config/nvim
├── home/.config/nvim/   # neovim config (adopted from video: lazy.nvim + rose-pine moon)
├── hosts/
│   └── remote.nix       # remote-specific: conda interop, no GUI, ~/.local/bin dup handling, PATH order
│   # hosts/mac.nix      # added later
├── docs/specs/          # this design doc
└── .gitignore           # excludes stray local files (backups live OUTSIDE the repo - see Migration)
```

**Apply on the remote:** `home-manager switch --flake ~/gitrepos/dotfiles#hayden@remote`. One command makes the box match the config.

`flake.nix` exposes (for now):
- `homeConfigurations."hayden@remote"` = `home/` + `hosts/remote.nix`
  - `home.username = "hayden.dorahy"`, `home.homeDirectory = "/mnt/home/hayden.dorahy"`, `home.stateVersion = "24.11"` (verify against chosen home-manager release at implementation).

## Components - what home-manager manages (remote)

- `shell.nix` - zsh (`programs.zsh`) with `autosuggestion.enable` + `syntaxHighlighting.enable`; aliases (video's set + user's). starship (`programs.starship`) with the video's simple format. Drops oh-my-zsh and powerlevel10k.
- `packages.nix` - `home.packages`: ripgrep, fd, fzf, jq, lazygit, neovim, bat, gh, delta, **herdr** (herdr pulled from the herdr flake input, not nixpkgs - passed via `specialArgs`/`inputs`), **uv** (from nixpkgs - `pkgs.uv`, v0.11.28; verified in `pkgs/by-name/uv/uv/package.nix`; builds on Linux x86_64), **yazi** (from nixpkgs - `pkgs.yazi`; verified in `pkgs/by-name/ya/yazi/package.nix`; auto-wraps optional deps incl. zoxide, fd, ripgrep, fzf for previews), **gdu** (from nixpkgs - `pkgs.gdu`, v5.36.1, verified at `pkgs/by-name/gd/gdu/package.nix`; no HM module, just the package), **rsync** (from nixpkgs - `pkgs.rsync`, v3.4.4, verified at `pkgs/by-name/rs/rsync/package.nix`; shadows `/usr/bin/rsync` via PATH; no HM module). tmux handled via `programs.tmux`.
- `rclone.nix` - `programs.rclone.enable = true` (binary + shell completion only). **Config stays manual/gitignored** - `~/.config/rclone/rclone.conf` holds cloud credentials, must not be in the flake. Pass empty/null config to the HM module so it does not write the file; user's manual rclone.conf (if any) stays untouched.
- `git.nix` - `programs.git` with **only** `push.autoSetupRemote = true` and `rerere.enabled = true`. **No `[user]`, no `[credential]`** (per user). Note: git will prompt for name/email on first commit - intentional.
- `tmux.nix` - `programs.tmux`: structured settings (prefix `C-Space`, mouse on, base-index 1, vi mode, escape-time 50, etc.) as Nix attrs; **all keybindings ported verbatim into `extraConfig`** (Ctrl-Space prefix, pane/window/session switching, `"`/`%` splits, `c`/`R`/`r`, F11 nested-session toggle, mouse-drag copy - nothing lost); dracula-theme + tmux-sensible via `programs.tmux.plugins` (Nix-managed, **replaces TPM** - no `git clone`). Dracula `@dracula-*` options + VSCode colors in `extraConfig`. The `~/.tmux/plugins/` (TPM) dir is removed after Nix plugins are verified.
- `editor.nix` - neovim: `home.file.".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/home/.config/nvim"`. The nvim config files themselves (lazy.nvim + rose-pine moon) are adopted from the video and live in the repo at `home/.config/nvim/`. Edit-in-place - no `switch` needed for nvim lua edits. See "How Nix links config files" for the `~/.dotfiles` symlink.
- `zoxide.nix` - `programs.zoxide.enable = true` (auto-installs zoxide + wires zsh `z`/`zi`). Replaces the oh-my-zsh `z` plugin from the user's `.zshrc`. See "Adopted" section for version verification.
- `btop.nix` - `programs.btop.enable = true` (resource monitor). Replaces the `bpytop` uv-tool + the `alias btop='bpytop'` workaround. Real btop (C++) is much faster than bpytop (Python). See "Adopted" section for details.
- `rclone.nix` - `programs.rclone.enable = true` (binary + completion only; config stays manual/gitignored - see "Adopted" section).
- `hosts/remote.nix` - remote extras: no GUI packages, no brew; ensure `~/.nix-profile/bin` precedes `~/.local/bin` on PATH; `home.sessionPath` adds `~/.local/bin` (for uv-managed tools - see uv below). **No conda/mamba mention** - user deleted conda entirely (see Migration).

## Shell startup handling (preserving the bash -> zsh -> tmux bridge)

The user's boot chain is `ssh -> bash (login) -> exec zsh -l -> exec tmux new-session -A -s main -> zsh inside tmux`. This must keep working unchanged. Strategy: **home-manager manages ONLY zsh; `~/.bashrc` and `~/.profile` stay manual.**

**`~/.bashrc` (stays manual, slimmed):** since bash immediately execs zsh, most of the current ~170 lines are dead code (prompt, history, aliases, completions run in bash and are then thrown away). Slim to env-setup + bridge only:
- **Keep:** non-interactive guard; `source ~/.local/bin/env` + envman; ssh-agent + add keys; `AWS_PROFILE=coreweave`; `exec zsh -l` (with cursor/remote-container guards) + tmux fallback.
- **Drop:** the plaintext `AGENTS_ANTHROPIC_API_KEY` (**deleted per user - not ported anywhere; it's old**), `EDITOR=micro` (-> nvim via Nix), all aliases (move to zsh), PS1/prompt, history settings, completions, dircolors/colors, lesspipe, `debian_chroot`, `force_color_prompt`, all commented lines.
- Result: ~170 lines -> ~20.

**`~/.zshrc` (fully Nix-managed, lean):** home-manager writes it. Ports: tmux auto-start (`exec tmux new-session -A -s main` with the same guards, first in `initContent`), starship (replaces p10k), zsh autosuggestion + syntaxHighlighting (replaces oh-my-zsh), aliases (`cc`=local-claude, `oc`=local-opencode, `ll`/`la`/`l`/`cat=bat -p`/`btop` + the video's set), Cursor Ctrl+Left/Right keybinds, PATH via `home.sessionPath` (adds `opencode`, `pi-node`, `~/.local/bin` - replaces the old `source ~/.local/bin/env` line; `~/.local/bin` stays for uv-managed tools like `uv tool install ruff`), envman sourcing (defensive), compinit. Drops: oh-my-zsh, p10k, commented template cruft, the `source ~/.local/bin/env` line (replaced by `home.sessionPath`).

**Aliases - keep user's, not the video's:** `cc`=local-claude (user's, `~/.local/bin/local-claude`), `oc`=local-opencode (user's, `~/.local/bin/local-opencode`). **Do NOT adopt** the video's `cc`=claude / `co`=codex - the user doesn't use codex, and their `cc`/`oc` target local model proxies on CoreWeave, not the upstream binaries.

**Nix installs zsh (no sudo):** `programs.zsh.enable = true` makes home-manager install zsh into `~/.nix-profile/bin/zsh` (all in `$HOME`). The manual `~/.local/bin/zsh` binary becomes redundant - moved aside like the other tools. The `exec zsh` bridge finds Nix's zsh via PATH.

**EDITOR:** `nvim` (set via `home.sessionVariables.EDITOR`). The old `micro` binary at `~/.local/bin/micro` is **kept as a fallback** (not removed) - user wants it just in case. EDITOR points at nvim; micro stays invokable directly.

**Stays as uv-tools (not added to Nix):** `task` (go-task), `nvitop`, `hf`/`huggingface-cli`, `evo`/`evo-dashboard`/`evo-drain`, `graphify`, `bpytop` (until uninstalled after btop verified). These are Python-based or already well-managed by `uv tool install` - Nix leaves them alone. `~/.local/bin` stays on PATH (via `home.sessionPath`) so they keep working.

**Security:** the plaintext `AGENTS_ANTHROPIC_API_KEY` in `.bashrc` is **deleted, not ported** (user confirmed it's old). No secrets go in the flake (public GitHub repo). If a real secret is needed later, use a gitignored local file sourced by zsh, or sops-nix (out of scope for now).

**Leftover files to remove after Nix is verified:** `~/.oh-my-zsh/`, `~/.p10k.zsh`, `~/.local/bin/zsh`, `~/.local/bin/{bat,gh,rg,fzf,fd}` (the last five moved aside/restorable, not deleted), `~/.local/bin/env` (redundant - `home.sessionPath` replaces it).

## Python tooling (uv installed by Nix, conda deleted)

- **uv installed via Nix:** `home.packages` includes `pkgs.uv` (v0.11.28, verified in nixpkgs `pkgs/by-name/uv/uv/package.nix`, builds on Linux x86_64). The uv binary lives at `~/.nix-profile/bin/uv`. uv-managed Python interpreters (`uv python install`) go to `~/.local/share/uv/python/` (uv's default, outside Nix). uv-managed tools (`uv tool install ruff`) go to `~/.local/bin/ruff` - hence `~/.local/bin` stays on PATH via `home.sessionPath`. The old `source ~/.local/bin/env` line is **dropped** (its only function was adding `~/.local/bin` to PATH, now done by `home.sessionPath`).
- **conda deleted entirely:** user does not use conda. Nix makes no reference to conda/mamba. The `~/.conda` (1.5K - just `aau_token`, `aau_token_host`, `environments.txt`) and `~/.mamba` (empty `pkgs/` dir) directories are deleted. **Flag:** `~/.conda/aau_token` and `aau_token_host` look like auth tokens, not standard conda files - user should glance at them before deletion (they're tiny text files). Deletion is an explicit step the user runs (not auto-run): `rm -rf ~/.conda ~/.mamba`.

## How Nix links config files (the symlink mechanism)

home-manager uses two patterns to put config in the right place (`~/.zshrc`, `~/.config/starship.toml`, `~/.config/nvim/`, `~/.tmux.conf`, etc.):

**Mechanism 1 - standard `home.file` / `programs.<x>` (config in the Nix store, immutable):**
- You express the config *in Nix* (e.g. `programs.starship.settings = { ... };`).
- home-manager writes the generated file into the Nix store at an immutable, content-addressed path (e.g. `<store>/a1b2...-starship.toml`).
- It symlinks `~/.config/starship.toml` → that store path.
- To change the config, edit the Nix expression and run `home-manager switch` again. The store is read-only - you can't edit `starship.toml` directly.
- Used in our spec for: zsh (`programs.zsh` → `~/.zshrc`), starship (`programs.starship` → `~/.config/starship.toml`), tmux (`programs.tmux` → `~/.tmux.conf`), git (`programs.git` → `~/.gitconfig`), btop, zoxide, rclone.

**Mechanism 2 - `mkOutOfStoreSymlink` (config in the repo, edit-in-place):**
- The real file lives in the git repo (e.g. `~/gitrepos/dotfiles/home/.config/nvim/init.lua`).
- home-manager symlinks `~/.config/nvim` → the repo path (the "out of store" target - *not* in the Nix store).
- Editing the file in the repo = editing your live config. No rebuild needed. You only `switch` when you change packages or Nix-expressed settings.
- Used in our spec for: nvim config (`editor.nix` → `home/.config/nvim/` - lazy.nvim lua files, edit-in-place).
- Matches the video's pattern (`home.nix:56-71` uses `mkOutOfStoreSymlink` for wezterm, nvim, herdr, `.claude/settings.json`, AGENTS.md).

**The `~/.dotfiles` symlink (stabilises mechanism 2 paths):**
- The video's `bootstrap.sh` symlinks the repo to `~/.dotfiles` (`ln -sfn "$DIR" ~/.dotfiles`) so `mkOutOfStoreSymlink` paths resolve stably even if the repo moves.
- We adopt the same: `ln -sfn ~/gitrepos/dotfiles ~/.dotfiles` (added to install flow below). `editor.nix` references `${config.home.homeDirectory}/.dotfiles/home/.config/nvim` (not the `~/gitrepos/dotfiles` path directly), so the flake keeps working if the repo is ever relocated.

## Install + apply flow (remote)

1. Install rootless userspace Nix (exact tool verified at implementation - I will not pipe-to-shell; user runs the installer or I provide a safe command).
2. `~/gitrepos/dotfiles` already cloned on this box.
3. **Symlink the repo to `~/.dotfiles`** (stabilises `mkOutOfStoreSymlink` paths - matches the video): `ln -sfn ~/gitrepos/dotfiles ~/.dotfiles`. Run once before the first `switch`.
4. `home-manager switch --flake ~/gitrepos/dotfiles#hayden@remote`.
5. If the rootless tooling is too fragile here, fall back to Approach C: skip Nix on the remote, just `git pull` the repo and source the dotfiles directly (no package management; lose reproducibility).

## How Nix installs the tools (mechanism, rootless)

1. Each package is built or fetched (binary cache) into an immutable, content-addressed path in a store that lives in `$HOME` (no `/nix`, no daemon, no root).
2. home-manager builds a profile at `~/.nix-profile/bin/` of symlinks pointing at those store paths; dotfiles (`.zshrc`, `.config/starship.toml`, nvim config) are symlinked into the store (or, for nvim, `mkOutOfStoreSymlink` points at the repo).
3. home-manager injects `~/.nix-profile/bin` at the front of PATH via shell init it manages, so `bat`/`rg`/etc. resolve to the Nix versions.
4. Existing `~/.local/bin` copies (`bat`, `gh`, `rg`, `fzf`, `fd`) are moved aside (renamed, restorable) - not archived, not in the repo. Nix owns them. One source of truth. (Leaving them + PATH-ordering also works but is messier.)
5. Versions pinned by `flake.lock` (identical on every machine). Each `switch` makes a generation; roll back to restore previous versions instantly.

## Migration, rollback, verification

- **Backup first (before any `switch`), OUTSIDE the repo:** copy `.zshrc .p10k.zsh .tmux.conf .gitconfig .bashrc` to `~/dotfiles-backup-20260726/`. The `~/.local/bin` tool copies (`bat gh rg fzf fd`) are **not** archived - just moved aside to `~/.local/bin/.pre-nix-disabled/` (renamed, restorable) after the Nix versions are verified working. **Binaries never go in the git repo.**
- **Collisions:** home-manager refuses to overwrite existing files by default - safe. Port content into modules, then let HM own the files.
- **Login shell:** **no `chsh` needed** - the existing bash->`exec zsh -l` bridge in `.bashrc` is kept (see Shell startup handling). home-manager manages zsh's config but does not change the login shell. Behavior is identical to today.
- **Rollback:** `home-manager generations` lists generations; roll back instantly. `nix flake update` updates inputs deliberately.
- **Verify (remote):** shell starts as zsh, starship prompt renders, `rg`/`fzf`/`fd`/`bat`/`gh`/`delta`/`lazygit`/`nvim`/`herdr`/`uv`/`zoxide`/`yazi`/`btop`/`gdu`/`rclone`/`rsync` resolve to Nix versions (`which bat` → `~/.nix-profile/bin/bat`, `which uv` → `~/.nix-profile/bin/uv`, `which zoxide` → `~/.nix-profile/bin/zoxide`, `which yazi` → `~/.nix-profile/bin/yazi`, `which btop` → `~/.nix-profile/bin/btop`, `which gdu` → `~/.nix-profile/bin/gdu`, `which rclone` → `~/.nix-profile/bin/rclone`, `which rsync` → `~/.nix-profile/bin/rsync` - shadows `/usr/bin/rsync`), `herdr --version` works, `uv --version` works, `uv python install` (a test interpreter) works, `z foo` jumps to a previously-cd'd dir (zoxide learned), `yazi` launches with previews working, `btop` launches (real C++ btop, not bpytop), `gdu` launches, `rclone version` works, `rsync --version` works, tmux loads with ported config, `git config --global --get push.autoSetupRemote` → `true`, `git config --global --get rerere.enabled` → `true`, `git config --global --get user.name` → empty (intentional), nvim launches with rose-pine theme, `~/.conda` and `~/.mamba` are gone.

## Open TBDs (resolve at implementation)

1. **Exact rootless-Nix tool** - verify and pick (nix-portable or equivalent). This is the main implementation risk; verify early.
2. **home-manager stateVersion** - confirm against the chosen home-manager release.
3. **herdr flake input** - confirm the exact flake URL/rev (herdr.dev lists "Nix flake" as an install method; not in nixpkgs at v0.7.5). Verify it builds under the rootless Nix setup.
4. **uv on rootless Nix** - confirm `uv python install` works (uv downloads self-contained Python builds; on Ubuntu with rootless Nix the system `/lib` exists, so dynamic linking should be fine - but the nixpkgs uv package flags a NixOS-specific issue pointing to `nixos.org/manual/nixpkgs/unstable/#sec-uv`; verify it's a non-issue on Ubuntu). If problematic, fallback: keep uv's standalone installer alongside Nix (uv self-updates).
5. **Aliases** - finalize the port list (draft in Shell startup handling: `cc`=local-claude, `oc`=local-opencode, `ll`/`la`/`l`/`cat=bat -p`/`btop` + the video's non-conflicting set like `..`/`add`/`push`/`pull`/`m`). Video's `cc`/`co` NOT adopted.
6. **eza** (modern `ls`) - not included now; add later if wanted.

**Decided (recorded in Shell startup handling + Python tooling):** EDITOR = `nvim`; login shell = keep the bash->`exec zsh` bridge (no `chsh`); the `AGENTS_ANTHROPIC_API_KEY` is deleted, not ported; uv installed via Nix (in nixpkgs); conda deleted entirely (dirs `~/.conda` `~/.mamba` removed - user runs it, not auto-run; flag the `aau_token*` files first).

## Mac (deferred to a later session)

A separate session (with another agent) will:
- Read this spec.
- Decide: nix-darwin + home-manager (full, like the video) vs home-manager standalone (lighter) on the Mac.
- Add a `hosts/mac.nix` (and, if nix-darwin, a `darwinConfiguration` + macOS defaults + Homebrew casks/brews) to this same repo.
- Reuse the shared `home/` module as-is.
- Handle Mac-specifics: WezTerm, nerd-fonts, GUI apps (Cursor), the AGENTS.md symlink question (likely still skip - user's sync setup).

## Out of scope (for now)

- **SSH** - `~/.ssh/` (keys: `git_cluster`, `github_haydeni0`, `id_cluster`; `config`; `authorized_keys`) and the SSH agent setup (`.bashrc:121-128` - finds all `*.pub` keys and ssh-adds them) are **not managed by Nix**. The agent stays in the manual `.bashrc` (which we keep, slimmed). SSH keeps working exactly as today. The video's config doesn't touch SSH either.
- nix-darwin / macOS system management (Mac session).
- NixOS.
- Managing GUI apps via Nix (Cursor stays on brew on Mac).
- Multi-user/daemon Nix on the remote (no root).
- Secrets management in the flake (sops-nix / agenix) - add only if a real need appears.
