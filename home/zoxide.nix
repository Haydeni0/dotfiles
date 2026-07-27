{ pkgs, ... }:

{
  programs.zoxide = {
    enable = true;
    # Disabled: HM places the zoxide eval at mkOrder 851 (after HM's compinit
    # at 570), but our manual compinit runs in initContent at a later order,
    # so HM's eval runs BEFORE our compinit. compdef fails silently without
    # compinit, so z <tab> completion never registers. Instead, run
    # `zoxide init zsh` manually in shell.nix after our compinit.
    enableZshIntegration = false;
  };
}
