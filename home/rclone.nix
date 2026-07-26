{
  programs.rclone = {
    enable = true;
    # Do NOT set `settings` here - rclone.conf holds cloud credentials
    # and must not be in the flake (public GitHub repo).
    # The user's manual ~/.config/rclone/rclone.conf (if any) stays untouched.
  };
}
