{ config, lib, pkgs, ... }:

{
  # Mako is configured via themed conf files in theming.nix
  # The active config is symlinked to ~/.config/mako/config
  home.packages = with pkgs; [
    mako
    libnotify  # For notify-send
  ];
}
