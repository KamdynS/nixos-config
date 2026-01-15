{ config, pkgs, ... }:

{
  programs.waybar = {
    enable = true;
    
    settings = [{
      layer = "top";
      position = "top";
      height = 30;
      
      modules-left = [ "niri/workspaces" ];
      modules-center = [ "clock" ];
      modules-right = [ "tray" "custom/theme-toggle" "custom/control-center" ];
      
      "niri/workspaces" = {
        format = "{index}";
        on-click = "activate";
      };
      
      clock = {
        format = "{:%a %b %d  %I:%M %p}";
        tooltip-format = "<tt>{calendar}</tt>";
      };
      
      tray = {
        spacing = 10;
        icon-size = 16;
      };
      
      "custom/theme-toggle" = {
        format = "󰔎";
        tooltip-format = "Toggle theme";
        on-click = "~/.config/waybar/scripts/toggle-theme.sh";
      };
      
      "custom/control-center" = {
        format = "󰍜";
        tooltip-format = "Control center";
        on-click = "swaync-client -t -sw";  # We'll set up swaync later
      };
    }];
    
    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
      }
      
      window#waybar {
        background-color: #282828;
        color: #ebdbb2;
      }
      
      #workspaces button {
        padding: 0 8px;
        color: #928374;
        background: transparent;
        border: none;
      }
      
      #workspaces button.active {
        color: #ebdbb2;
        background-color: #3c3836;
      }
      
      #workspaces button:hover {
        background-color: #504945;
      }
      
      #clock {
        padding: 0 12px;
        color: #ebdbb2;
      }
      
      #tray {
        padding: 0 12px;
      }
      
      #custom-theme-toggle,
      #custom-control-center {
        padding: 0 12px;
        color: #ebdbb2;
      }
      
      #custom-theme-toggle:hover,
      #custom-control-center:hover {
        background-color: #3c3836;
      }
    '';
  };
}
