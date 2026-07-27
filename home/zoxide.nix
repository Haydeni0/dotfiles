{ pkgs, lib, ... }:

{
  programs.zoxide = {
    enable = true;
    # HM's default order (851) places zoxide before plugins/syntax-highlighting,
    # which can clobber its chpwd hook. Source manually with mkAfter instead.
    enableZshIntegration = false;
  };

  # Must be set before `zoxide init` runs (sessionVariables is sourced early).
  home.sessionVariables = {
    _ZO_EXCLUDE_DIRS = "$HOME:$HOME/.cache/*:$HOME/.local/share/*:/tmp/*";
    _ZO_RESOLVE_SYMLINKS = "1";  # follow symlinks - common on Nix (store paths, HM links)
  };

  # Must be sourced LAST: compinit (570) must have run for compdef, and nothing
  # after this can reassign chpwd_functions or the cd-tracking hook is lost.
  programs.zsh.initContent = lib.mkAfter ''
    eval "$(${pkgs.zoxide}/bin/zoxide init zsh)"

    # Override zoxide completion to show frecency db entries (like omz z plugin)
    # instead of local subdirectories. Based on @ijcd's snippet from
    # https://github.com/ajeetdsouza/zoxide/issues/513 - the proven fix for:
    # - z<tab> showing local subdirs (zoxide default is _cd -/)
    # - the slash prefix issue when compadding absolute paths (fixed by -M empty)
    # - losing frecency order (fixed by -o nosort)
    # - no menu cycling (fixed by compstate[insert]=menu)
    _zoxide_complete() {
        [[ "''${#words[@]}" -eq "''${CURRENT}" ]] || return 0
        local -a dirs expl
        dirs=("''${(@f)$(\command zoxide query -l -- ''${words[2,-1]} 2>/dev/null | head -15)}")
        if (( ''${#dirs} )); then
            compstate[insert]=menu
            compstate[list]=list
            _wanted directories expl 'zoxide' compadd -M ''' -U -o nosort -a dirs
        fi
    }
    compdef _zoxide_complete z
  '';
}
