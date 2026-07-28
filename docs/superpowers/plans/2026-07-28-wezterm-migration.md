# WezTerm Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Ghostty with WezTerm as the terminal emulator, auto-booting herdr and enabling a `gssh` function that opens a dedicated SSH window with no local herdr layer.

**Architecture:** Add a plain `wezterm.lua` (Mac-only, no chezmoi template) replicating the Ghostty visual settings and auto-booting herdr via `default_prog` with an absolute home-resolved path. Add a `gssh` zsh function (runtime-guarded) that runs `wezterm start -- ssh -t "$@"` to open a fresh window running plain ssh. Remove the Ghostty config dir and swap the Brewfile cask. Update `docs/setup.md` references.

**Tech Stack:** chezmoi (dotfiles management), WezTerm (terminal, Lua config), Homebrew cask (install), zsh (gssh function), herdr (multiplexer, pre-existing).

## Global Constraints

- **Source of truth:** Edit `configs/` and `dot_config/` source files, never deployed files in `$HOME` (CLAUDE.md "configs/ is the single source of truth").
- **Deploy:** `chezmoi apply` after source edits; `chezmoi diff` before to check drift.
- **Runtime guards, not template-time:** Use `command -v` checks in zshrc, not chezmoi `lookPath` (CLAUDE.md principle).
- **Mac-only WezTerm:** Linux boxes are headless; WezTerm config deploys but is harmless there, gssh guard skips on Linux.
- **No commit without authorization:** Commits in this plan require the `COMMIT_AUTHORISED` sentinel in the executing task prompt. Do not commit unless authorized.
- **Surgical changes:** Touch only what each task requires; do not reformat or tidy adjacent code (CLAUDE.md code-editing discipline).

---

### Task 1: Create WezTerm config

**Files:**
- Create: `dot_config/wezterm/wezterm.lua`

**Interfaces:**
- Produces: `~/.config/wezterm/wezterm.lua` (via chezmoi apply) configuring WezTerm to auto-boot herdr with migrated visual settings.

- [ ] **Step 1: Create the wezterm.lua file**

Create `dot_config/wezterm/wezterm.lua` with this exact content:

```lua
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.color_scheme = 'rose-pine-moon'
config.font = wezterm.font('Hack Nerd Font')
config.font_size = 14
config.window_padding = { left = 8, right = 8, top = 4, bottom = 4 }
config.window_background_opacity = 0.95
config.macos_window_background_blur = 20
config.macos_option_as_alt = true
config.window_decorations = 'RESIZE'
-- Auto-boot herdr. Absolute path: GUI-launched wezterm doesn't source zprofile,
-- so ~/.local/bin isn't on PATH (same constraint as ghostty).
config.default_prog = { os.getenv('HOME') .. '/.local/bin/herdr' }

return config
```

- [ ] **Step 2: Verify lua syntax**

Run: `lua -e 'loadfile("dot_config/wezterm/wezterm.lua")()' 2>&1 || echo "syntax check done"`
Expected: no syntax error (note: `require 'wezterm'` will fail outside wezterm, but a pure syntax check via `luac -p` is cleaner if available).

Fallback if `lua` missing: run `chezmoi diff ~/.config/wezterm/wezterm.lua` which renders the template (none here) and confirms chezmoi can read the file without error.

- [ ] **Step 3: Verify chezmoi sees the new file**

Run: `chezmoi diff`
Expected: shows the new file as an addition (`--- /dev/null` -> `+++ .config/wezterm/wezterm.lua` with the content above).

- [ ] **Step 4: Commit (if COMMIT_AUTHORISED)**

```bash
git add dot_config/wezterm/wezterm.lua
git commit -m "Add WezTerm config (migrate from Ghostty)"
```

---

### Task 2: Swap Brewfile cask from Ghostty to WezTerm

**Files:**
- Modify: `Brewfile:25`

**Interfaces:**
- Produces: `Brewfile` declares `cask "wezterm"` instead of `cask "ghostty"` so `brew bundle` installs WezTerm on a fresh Mac.

- [ ] **Step 1: Edit the Brewfile**

In `Brewfile`, line 25, replace `cask "ghostty"` with `cask "wezterm"`. Keep surrounding lines unchanged. The line sits in the `--- GUI apps (casks) ---` block.

- [ ] **Step 2: Verify Brewfile is valid**

Run: `brew bundle check --file=Brewfile 2>&1 | head`
Expected: no syntax errors (it will report missing/extra installs but should parse cleanly).

- [ ] **Step 3: Verify only the one line changed**

Run: `git diff Brewfile`
Expected: exactly one line changed: `-cask "ghostty"` -> `+cask "wezterm"`.

- [ ] **Step 4: Commit (if COMMIT_AUTHORISED)**

```bash
git add Brewfile
git commit -m "Swap Brewfile cask: ghostty -> wezterm"
```

---

### Task 3: Add gssh function to zshrc

**Files:**
- Modify: `configs/zshrc` (insert after the fzf block, before the `# Plugins` comment)

**Interfaces:**
- Consumes: `wezterm` binary on PATH (Mac only; runtime guard handles absence on Linux).
- Produces: `gssh` shell function that opens a new WezTerm window running plain ssh.

- [ ] **Step 1: Insert the gssh block into configs/zshrc**

The fzf block ends at the line `fi` (currently around line 70). After that `fi` and a blank line, before the `# Plugins (git-cloned to ~/.local/share/zsh/, source with guards)` comment, insert this block:

```sh
# gssh: open a new WezTerm window running plain ssh (no local herdr layer).
# Remote auto-boots its own herdr; no nesting. Put ssh options before the host
# (e.g. `gssh -p 2222 user@host`), not after - ssh parses positionally.
if command -v wezterm >/dev/null 2>&1; then
    gssh() { wezterm start -- ssh -t "$@" }
fi
```

Use the Edit tool with the `# Plugins` comment line as the anchor for `old_string` and prepend the gssh block before it.

- [ ] **Step 2: Verify the insert**

Run: `grep -n -A5 "gssh" configs/zshrc`
Expected: shows the gssh comment, the `if command -v wezterm` guard, and the function definition.

Run: `grep -c "gssh" configs/zshrc`
Expected: `3` (one in comment, one in guard, one in function body - the `gssh()` definition).

- [ ] **Step 3: Verify zshrc still parses**

Run: `zsh -n configs/zshrc 2>&1 | head`
Expected: no output (no syntax errors). `-n` parses without executing.

- [ ] **Step 4: Commit (if COMMIT_AUTHORISED)**

```bash
git add configs/zshrc
git commit -m "Add gssh: open dedicated WezTerm ssh window (no local herdr)"
```

---

### Task 4: Remove Ghostty config

**Files:**
- Remove: `dot_config/ghostty/config.tmpl` (entire `dot_config/ghostty/` directory)

**Interfaces:**
- Produces: repo no longer contains ghostty config; `chezmoi apply` will leave the deployed `~/.config/ghostty/config` in place (chezmoi doesn't auto-delete managed files removed from source - see Step 3 note).

- [ ] **Step 1: Remove the ghostty config directory**

Run: `git rm -r dot_config/ghostty`
Expected: `rm 'dot_config/ghostty/config.tmpl'` and the directory gone.

- [ ] **Step 2: Verify removal**

Run: `ls dot_config/ghostty 2>&1`
Expected: "No such file or directory".

Run: `git status --short`
Expected: shows `D dot_config/ghostty/config.tmpl` staged for deletion.

- [ ] **Step 3: Note the deployed-file cleanup (manual, deferred)**

`chezmoi apply` will not delete `~/.config/ghostty/config` just because the source is gone. The user should manually `rm -rf ~/.config/ghostty` after the migration is verified, and `brew uninstall --cask ghostty` to remove the app. Do NOT run these in this task - they are destructive and belong to the final verification step once WezTerm is confirmed working.

- [ ] **Step 4: Commit (if COMMIT_AUTHORISED)**

```bash
git commit -m "Remove Ghostty config (superseded by WezTerm)"
```

(The `git rm -r` in Step 1 already staged the deletion.)

---

### Task 5: Update docs/setup.md references

**Files:**
- Modify: `docs/setup.md` at lines 77, 84-85, 125, 134, 137

**Interfaces:**
- Produces: setup guide reflects WezTerm instead of Ghostty so a fresh-Mac setup is accurate.

- [ ] **Step 1: Edit line 77 (chezmoi apply output comment)**

In `docs/setup.md`, the line:
`#    - Ghostty config deployed to ~/.config/ghostty/`
becomes:
`#    - WezTerm config deployed to ~/.config/wezterm/`

- [ ] **Step 2: Edit lines 84-85 (brew bundle installs comment)**

The line:
`#    This installs: ghostty, rectangle, alt-tab, scroll-reverser, betterdisplay,`
becomes:
`#    This installs: wezterm, rectangle, alt-tab, scroll-reverser, betterdisplay,`

- [ ] **Step 3: Edit line 125 (verification comment)**

The line:
`# Open Ghostty - should show rose-pine moon theme, Hack Nerd Font`
becomes:
`# Open WezTerm - should show rose-pine moon theme, Hack Nerd Font`

- [ ] **Step 4: Edit line 134 (GUI apps list)**

The line:
`- **GUI apps** (via Homebrew casks): ghostty, rectangle, alt-tab, scroll-reverser, betterdisplay, obsidian, cursor, visual-studio-code, docker-desktop, zotero, whatsapp, karabiner-elements`
becomes:
`- **GUI apps** (via Homebrew casks): wezterm, rectangle, alt-tab, scroll-reverser, betterdisplay, obsidian, cursor, visual-studio-code, docker-desktop, zotero, whatsapp, karabiner-elements`

- [ ] **Step 5: Edit line 137 (Configs list)**

The line:
`- **Configs** (via chezmoi): zsh, tmux, starship, herdr, git, nvim, ghostty, karabiner - real files in \`~\``
becomes:
`- **Configs** (via chezmoi): zsh, tmux, starship, herdr, git, nvim, wezterm, karabiner - real files in \`~\``

- [ ] **Step 6: Verify no ghostty references remain**

Run: `grep -rni "ghostty" docs/setup.md`
Expected: no output (all references replaced).

Run: `grep -rni "ghostty" . --include="*.md" --include="*.tmpl" --include="*.sh" --include="*.toml" 2>/dev/null | grep -v "/.git/"`
Expected: no output (no ghostty references anywhere in repo source after this task + Task 4).

- [ ] **Step 7: Commit (if COMMIT_AUTHORISED)**

```bash
git add docs/setup.md
git commit -m "docs/setup: replace ghostty with wezterm"
```

---

### Task 6: Install WezTerm, apply, and verify

**Files:**
- None (execution + verification only).

**Interfaces:**
- Consumes: all changes from Tasks 1-5.

- [ ] **Step 1: Install WezTerm via the updated Brewfile**

Run: `brew bundle --file=~/Brewfile`
Expected: installs `wezterm` cask (and any other missing declared casks). Ghostty is NOT auto-removed (no `cleanup` directive).

- [ ] **Step 2: Apply chezmoi changes**

Run: `chezmoi diff` first to confirm no unexpected drift, then `chezmoi apply`.
Expected: `chezmoi diff` shows wezterm.lua as a new file and the zshrc/Brewfile/setup.md edits. `chezmoi apply` deploys them.

- [ ] **Step 3: Verify wezterm binary is available**

Run: `command -v wezterm && wezterm --version`
Expected: a path under `/Applications/WezTerm.app/...` and a version string.

- [ ] **Step 4: Verify gssh function is defined in a fresh shell**

Run: `zsh -ic 'type gssh'`
Expected: `gssh is a shell function` (the runtime guard passed since wezterm is now installed).

- [ ] **Step 5: Manual GUI verification - primary window**

Quit Ghostty if running. Open WezTerm (Spotlight/Dock).
Expected:
- Window opens and auto-launches herdr (the herdr TUI appears, not bare zsh).
- Theme is rose-pine-moon (dark, purple-ish background `#232136`).
- Font is Hack Nerd Font at size 14.
- Window padding ~8px sides, ~4px top/bottom.
- Background slightly translucent (opacity 0.95) with blur.
- No macOS titlebar (window_decorations RESIZE).

- [ ] **Step 6: Manual GUI verification - Option as Alt**

In the WezTerm window running herdr, at a zsh prompt inside herdr, press `Option+f`.
Expected: cursor jumps forward one word (Option acts as Alt, not compose).

- [ ] **Step 7: Manual GUI verification - gssh**

In the WezTerm window, run: `gssh <a-real-remote-host>` (use an actual host the user has SSH access to).
Expected:
- A new WezTerm window opens.
- That window runs plain ssh (no local herdr layer - herdr is NOT the outer process).
- The remote shell loads; the remote auto-boots its own herdr.
- The remote herdr prefix (e.g. `ctrl+b` or whatever the remote config sets) works in that window.
- Closing that window does not affect the primary WezTerm window running local herdr.

- [ ] **Step 8: Manual GUI verification - Linux headless guard (optional)**

If a Linux headless box is available, `chezmoi apply` there and run `zsh -ic 'type gssh'`.
Expected: `gssh: not found` or no function (the `command -v wezterm` guard skipped the definition since wezterm isn't installed). No errors sourcing zshrc.

- [ ] **Step 9: Clean up Ghostty (destructive - user confirms)**

Only after Step 5-7 all pass (WezTerm confirmed working), and with explicit user confirmation:
Run: `brew uninstall --cask ghostty`
Run: `rm -rf ~/.config/ghostty`
Expected: Ghostty app and its deployed config removed. These are destructive - do not run without user confirmation.

- [ ] **Step 10: Final commit if any uncommitted changes remain**

Run: `git status`
If clean, done. If the execution step created any changes (e.g. `lazy-lock.json` from opening nvim - unrelated), leave them. Only commit the migration files if not already committed in Tasks 1-5.

---

## Self-Review Notes

- Spec coverage: every file in the spec's "Files" section (ADD wezterm.lua, REMOVE ghostty dir, MODIFY Brewfile, MODIFY zshrc, MODIFY setup.md) has a task. Known regressions (window-save-state, shell-integration) are documented in the spec and require no implementation. Verification (spec section) maps to Task 6 steps.
- Placeholder scan: no TBD/TODO. All steps have concrete commands or exact content.
- Type consistency: gssh definition is identical in Task 3 step 1 and the spec. wezterm.lua content is identical in Task 1 step 1 and the spec.
- Commits: each task ends with a conditional commit gated on `COMMIT_AUTHORISED` (per global constraint). The executor must have the sentinel to commit.
- Destructive ops: `brew uninstall --cask ghostty` and `rm -rf ~/.config/ghostty` are isolated in Task 6 Step 9 with explicit user-confirmation requirement.
