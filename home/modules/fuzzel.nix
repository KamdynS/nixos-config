{ config, lib, pkgs, ... }:

{
  # Fuzzel is configured via themed ini files in theming.nix
  # The active config is symlinked to ~/.config/fuzzel/fuzzel.ini
  home.packages = [ pkgs.fuzzel ];
}
