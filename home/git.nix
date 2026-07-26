{
  programs.git = {
    enable = true;
    settings = {
      push.autoSetupRemote = true;
      rerere.enabled = true;
    };
  };
}
