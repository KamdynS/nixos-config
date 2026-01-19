{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    quickshell
    brightnessctl  # For brightness control
    playerctl      # For media controls (MPRIS)
  ];

  # Quickshell config files
  xdg.configFile."quickshell" = {
    source = ./qml;
    recursive = true;
  };
}
