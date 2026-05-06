{ config, lib, pkgs, ... }:

{
  programs.waybar = {
    enable = true;
    systemd.enable = false;  # Started by niri spawn-at-startup

    settings = [{
      layer = "top";
      position = "top";
      height = 32;

      modules-left = [ "niri/workspaces" ];
      modules-center = [ "clock" ];
      modules-right = [ "network" ];

      "niri/workspaces" = {
        format = "{icon}";
        format-icons = {
          active = "";
          default = "";
        };
      };

      clock = {
        format = "{:%H:%M}";
        format-alt = "{:%Y-%m-%d %H:%M}";
        tooltip-format = "<tt>{calendar}</tt>";
      };

      network = {
        format-wifi = "  {essid}";
        format-ethernet = "󰈀  {ifname}";
        format-disconnected = "󰖪  Disconnected";
        tooltip-format = "{ifname}: {ipaddr}";
      };
    }];

    # Import theme colors from symlinked file
    style = ''
      @import "colors.css";
    '';
  };
}
