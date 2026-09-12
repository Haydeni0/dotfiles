# Cheatsheet

Daily-use keybinds and commands this dotfiles repo sets up.

## What this is (and how to maintain it)

- **Audience**: future-you, months later, forgetting a keybind. Lookup-first -
  keybind tables grouped by tool, not prose.
- **Add an entry when**: a change introduces a keybind, command, or default a
  user interacts with (new fzf binding, new shell function, new wezterm key).
  Add it in the same change - a cheatsheet entry lagging the config is a lie.
- **Don't add**: install steps (docs/setup.md), architecture/philosophy
  (README.md), machine-local stuff (not in this repo), the full alias list
  (self-evident from `configs/zsh/aliases.zsh`), or anything a user can't
  invoke.
- **Format**: `key | action | note` tables. One line per entry. No history,
  no rationale - that lives in the config file's comments or the commit.
- **Facts must match the configs**. Every entry should be verifiable in
  `configs/`, `dot_config/`, or the tool's documented defaults. If testing a
  zero-config built-in (e.g. a wezterm default), note that it's a default.

## Shell (zsh)

### fzf

| Key | Action | Note |
|-----|--------|------|
| ctrl+t | Insert file path at prompt | Preview shows file via bat, dirs via `ls`; ctrl+d toggles preview |
| alt+c | cd into directory | Preview shows `ls -la` of highlighted dir; ctrl+d toggles preview |
| ctrl+r | History search | Same popup chrome: 40% height, reverse layout, purple border |

### Word and line editing

| Key | Action | Note |
|-----|--------|------|
| ctrl+backspace | Delete word backwards | Word = alphanumerics only - stops at `/` `.` `-` `_` |
| ctrl+delete | Delete word forwards | Same boundary as ctrl+backspace |
| ctrl+left/right | Jump word left/right | opt+left/right equivalent on Mac (via Karabiner) |
| cmd+backspace | Delete to line start | WezTerm maps to ctrl+u |
| cmd+left/right | Line start/end | WezTerm maps to ctrl+a / ctrl+e |
| up/down arrows | History substring search | Type a substring, walk unique matches only |
| right-arrow / End | Accept autosuggestion ghost text | Dim gray suggestion from history |

### zoxide + misc

| Command | Action | Note |
|-----|--------|------|
| `z <dir>` | Frecency-weighted cd | `zi` = interactive picker |
| `cat` | bat (paged) when stdout is a terminal | Pipes/redirects get real cat |
| `gssh <host>` | New WezTerm window, ssh with auto-reconnect | Retry loop survives dropped connections; ctrl+c stops retries |
| `sshh <host>` | Plain ssh in current terminal | Sets SKIP_HERDR on remote - no herdr auto-boot there |
| `lg` | lazygit | Stacked diff view (delta without side-by-side) |
| `gdifft` | git diff via difftastic | Syntax-aware, one-off; core pager (delta) untouched |
| `nvchad` | Secondary nvim config | Fully separate via NVIM_APPNAME |
| `SKIP_HERDR=1` | Drop to plain shell on startup | |
| `USE_TMUX=1` | Auto-start tmux instead of herdr | |

## Multiplexers

| Key | Action | Note |
|-----|--------|------|
| ctrl+space | herdr prefix | Primary multiplexer |
| prefix+d | herdr detach | |
| ctrl+b | tmux prefix | tmux is backup multiplexer |
| ctrl+shift+arrows | tmux: switch pane | No prefix needed |
| shift+left/right | tmux: prev/next window | No prefix needed |
| F11 | tmux: toggle all bindings off | For nested/remote tmux |

## WezTerm (Mac)

| Key | Action | Note |
|-----|--------|------|
| cmd+\ / cmd+\` | Cycle WezTerm windows | Both directions with shift |
| cmd+w | Close tab, no confirmation | |
| cmd+click | Open link under cursor | Works inside mouse-grabbing TUIs (claude code, vim) |
| opt+3 | `#` | UK layout: Karabiner routes backslash key here |
| ctrl+shift+space | Quick-select | Default. Regex-labels paths/urls in pane, type label to copy |
| ctrl+shift+f | Scrollback search | Default |

## Neovim

Leader is space; which-key popup lists leader binds after a pause.

| Key | Action |
|-----|--------|
| `<space>e` | Oil file browser (hidden files shown) |
| `<space>f` | Find files (snacks picker) |
| `<space>s` | Grep text |
| `<space>b` | Buffers |
| `<space>g` | Neogit |
| `gd` | LSP definition |
| ctrl+a | Select all |

Current-line git blame is on by default (gitsigns).

## Git

| Key/Command | Action | Note |
|-----|--------|------|
| h / n | Jump between diff hunks | In delta pager (any git diff) |
| `~60 aliases` | `g` = git, `gst`, `gcm`, `gsw`, ... | Full list: `configs/zsh/aliases.zsh` |

## Karabiner (Mac)

| Key | Action | Note |
|-----|--------|------|
| f12 | Forward delete | Laptops lack a delete-forward key |
| ctrl+f12 | Delete word forward | |
| ctrl+left/right | Re-mapped to opt+left/right | Makes ctrl+word-nav work like Mac standard |
| @ / " | Swapped | UK ISO: shift+2 = `"` |
| backtick/pipe/backslash/tilde | Reshuffled to UK positions | ` § \| # ~ layout fix |

## Prompt (starship)

| Feature | Behavior |
|-----|------|
| Dir display | First segment + last 3 full, middles truncated to 1 char |
| Transient prompt | After a command runs, its prompt collapses to `❯` |
| Command duration | Shown when > 2s |
| Git branch + status | Ahead/behind counts, stash count |

## Repo upkeep

| Command | Action |
|-----|--------|
| `mise run test` | Syntax/format/template/parity checks |
| `mise run sync` | git pull + chezmoi apply + test |
| `mise run doctor` | chezmoi doctor + drift summary |

Edit workflow: change `configs/` or `dot_config/` in the repo, `chezmoi apply`,
test in a new shell. Machine-local aliases: `~/.zsh/aliases.local.zsh` (never
in the repo).
