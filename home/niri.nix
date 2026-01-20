{ config, lib, pkgs, ... }:

{
  programs.niri.settings = {
    # Disable client-side decorations
    prefer-no-csd = true;
    
    # Enable window shadows
    layout.shadow.enable = true;

    # Gaps between windows
    layout.gaps = 8;

    # Struts to reserve space for quickshell panels
    # These values must match Layout.qml: totalBorderWidth=16, barHeight=32
    layout.struts = {
      top = 32;     # barHeight
      left = 16;    # totalBorderWidth (screenBorderWidth + windowGap)
      right = 16;
      bottom = 16;
    };

    # Window borders
    layout.border = {
      enable = true;
      width = 2;
      active.color = "#d79921";   # Gruvbox yellow
      inactive.color = "#928374"; # Gruvbox gray
    };

    # Window rules for all windows
    window-rules = [
      {
        matches = [];  # empty = match all windows
        border = {
          enable = true;
          width = 2;
          active.color = "#d79921";
          inactive.color = "#928374";
        };
        # Rounded corners for windows (inner radius, border outer radius computed automatically)
        geometry-corner-radius = let r = 8.0; in {
          top-left = r;
          top-right = r;
          bottom-left = r;
          bottom-right = r;
        };
        clip-to-geometry = true;  # Clip window contents to the corner radius
      }
    ];
    
    # Screenshot path
    screenshot-path = "~/Pictures/Screenshots/%Y-%m-%d_%H-%M-%S.png";
    
    # Input settings
    input = {
      keyboard.xkb = {
        layout = "us";
      };
      touchpad = {
        tap = true;
        natural-scroll = true;
      };
    };
    
    # Workspace switching - instant, no animation
    animations = {
      workspace-switch.enable = false;
    };
    
    # Keybindings
    binds = {
      # Power menu
      "Mod+X".action.spawn = [ "bash" "-c" "~/.config/wofi/power-menu.sh" ];

      # App launchers
      "Mod+Return".action.spawn = [ "ghostty" ];
      "Mod+D".action.spawn = [ "wofi" "--show" "drun" ];
      
      # Window management
      "Mod+Q".action.close-window = [];
      "Mod+F".action.maximize-column = [];        # Respects struts/border
      "Mod+Shift+F".action.fullscreen-window = []; # True fullscreen (covers border)
      
      # Focus
      "Mod+H".action.focus-column-left = [];
      "Mod+J".action.focus-window-down = [];
      "Mod+K".action.focus-window-up = [];
      "Mod+L".action.focus-column-right = [];
      
      # Move windows
      "Mod+Shift+H".action.move-column-left = [];
      "Mod+Shift+J".action.move-window-down = [];
      "Mod+Shift+K".action.move-window-up = [];
      "Mod+Shift+L".action.move-column-right = [];
      
      # Workspace switching (instant - animation disabled above)
      "Mod+1".action.focus-workspace = [ 1 ];
      "Mod+2".action.focus-workspace = [ 2 ];
      "Mod+3".action.focus-workspace = [ 3 ];
      "Mod+4".action.focus-workspace = [ 4 ];
      "Mod+5".action.focus-workspace = [ 5 ];
      "Mod+6".action.focus-workspace = [ 6 ];
      "Mod+7".action.focus-workspace = [ 7 ];
      "Mod+8".action.focus-workspace = [ 8 ];
      "Mod+9".action.focus-workspace = [ 9 ];
      
      # Move window to workspace
      "Mod+Shift+1".action.move-column-to-workspace = [ 1 ];
      "Mod+Shift+2".action.move-column-to-workspace = [ 2 ];
      "Mod+Shift+3".action.move-column-to-workspace = [ 3 ];
      "Mod+Shift+4".action.move-column-to-workspace = [ 4 ];
      "Mod+Shift+5".action.move-column-to-workspace = [ 5 ];
      "Mod+Shift+6".action.move-column-to-workspace = [ 6 ];
      "Mod+Shift+7".action.move-column-to-workspace = [ 7 ];
      "Mod+Shift+8".action.move-column-to-workspace = [ 8 ];
      "Mod+Shift+9".action.move-column-to-workspace = [ 9 ];
      
      # Scrolling through workspaces
      "Mod+WheelScrollDown".action.focus-workspace-down = [];
      "Mod+WheelScrollUp".action.focus-workspace-up = [];
      
      # Screenshots
      "Print".action.screenshot = [];
      "Alt+Print".action.screenshot-window = [];
      
      # Exit
      "Mod+Shift+E".action.quit = [];
      
      # Power off monitors (not suspend)
      "Mod+Shift+P".action.power-off-monitors = [];
    };
    
    # Start apps with niri
    spawn-at-startup = [
      { command = [ "quickshell" "-p" "/home/kamdyns/.config/quickshell" ]; }
    ];
  };
}
