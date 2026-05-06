{ config, lib, pkgs, ... }:

{
  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      font-family = "JetBrainsMono Nerd Font";
      font-size = 14;

      # Theme loaded from symlink (managed by theme-switch)
      # `?` prefix makes it optional (won't fail if missing during activation)
      config-file = "?~/.config/ghostty/theme";

      window-padding-x = 8;
      window-padding-y = 8;

      # Disable title bar (niri handles window decoration)
      window-decoration = false;
    };
  };
}
