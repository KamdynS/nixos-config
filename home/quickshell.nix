{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    quickshell
    brightnessctl  # For brightness control
    playerctl      # For media controls (MPRIS)

    # Caelestia shell dependencies
    ddcutil        # DDC monitor brightness control
    lm_sensors     # System temperature/resource monitoring

    # Fonts for caelestia
    material-symbols
    nerd-fonts.caskaydia-cove
  ];

  # Caelestia shell config files
  xdg.configFile."quickshell" = {
    source = ./caelestia;
    recursive = true;
  };
}
