{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    quickshell
    brightnessctl  # For brightness control
    playerctl      # For media controls (MPRIS)
    app2unit       # Launch apps as systemd units

    # Caelestia shell dependencies
    ddcutil        # DDC monitor brightness control
    lm_sensors     # System temperature/resource monitoring
    swaybg         # Wallpaper setter

    # Fonts for caelestia
    material-symbols
    nerd-fonts.jetbrains-mono
  ];

  # Caelestia shell config files
  xdg.configFile."quickshell" = {
    source = ./caelestia;
    recursive = true;
  };

  # Quickshell/Caelestia shell service
  systemd.user.services.quickshell = {
    Unit = {
      Description = "Caelestia Quickshell";
      After = [ "graphical-session.target" "niri-shell-ipc.service" ];
      PartOf = [ "graphical-session.target" ];
      Requires = [ "niri-shell-ipc.service" ];
    };
    Service = {
      Type = "simple";
      Environment = [
        "QML_IMPORT_PATH=${config.xdg.configHome}/quickshell"
      ];
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/.local/state/caelestia/wallpaper %h/.config/caelestia";
      ExecStart = "${pkgs.quickshell}/bin/quickshell -p ${config.xdg.configHome}/quickshell/shell.qml";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
