# herdr config - HM-managed via xdg.configFile.
# The TOML source stays at home/.config/herdr/config.toml (edit there, rebuild to apply).
# HM symlinks ~/.config/herdr/config.toml -> /nix/store/.../config.toml, which
# resolves inside bwrap (herdr runs inside bwrap, so /nix/store is visible).
# Changes require `./rebuild.sh` (standard HM tradeoff for declarative config).
{ ... }:

{
  xdg.configFile."herdr/config.toml".source = ./.config/herdr/config.toml;
}
