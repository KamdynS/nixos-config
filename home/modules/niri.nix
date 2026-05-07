{ config, lib, pkgs, ... }:

{
  programs.niri.settings = {
    # Monitor configuration - both monitors configured, user can swap freely
    outputs = {
      "HDMI-A-1" = {
        position = { x = 0; y = 0; };
      };
      "DP-3" = {
        position = { x = 1920; y = 0; };
      };
    };

    # Disable client-side decorations
    prefer-no-csd = true;

    # Layout settings
    layout = {
      # Gaps between windows
      gaps = 8;

      # Enable window shadows
      shadow.enable = true;

      # Preset column widths for cycling with Mod+R
      preset-column-widths = [
        { proportion = 0.33333; }
        { proportion = 0.5; }
        { proportion = 0.66667; }
        { proportion = 1.0; }
      ];

      # Default column width
      default-column-width = { proportion = 0.5; };

      # Reserve space for waybar
      struts.top = 32;

      # Window borders
      border = {
        enable = true;
        width = 2;
        active.color = "#d79921";   # Gruvbox yellow (static - niri doesn't hot-reload)
        inactive.color = "#928374"; # Gruvbox gray
      };
    };

    # Window rules
    window-rules = [
      {
        matches = [];  # Match all windows
        border = {
          enable = true;
          width = 2;
          active.color = "#d79921";
          inactive.color = "#928374";
        };
        geometry-corner-radius = let r = 8.0; in {
          top-left = r;
          top-right = r;
          bottom-left = r;
          bottom-right = r;
        };
        clip-to-geometry = true;
      }
    ];

    # Screenshot path
    screenshot-path = "~/Pictures/Screenshots/%Y-%m-%d_%H-%M-%S.png";

    # Input settings
    input = {
      keyboard = {
        xkb.layout = "us";
        repeat-delay = 200;
        repeat-rate = 50;
      };
      touchpad = {
        tap = true;
        natural-scroll = true;
      };
    };

    # Disable workspace switch animation (instant)
    animations.workspace-switch.enable = false;

    # Keybindings
    binds = {
      # App launchers
      "Mod+Return".action.spawn = [ "ghostty" ];
      "Mod+B".action.spawn = [ "zen-beta" ];
      "Mod+S".action.spawn = [ "spotify" ];
      "Mod+D".action.spawn = [ "vesktop" ];
      "Mod+Space".action.spawn = [ "fuzzel" ];

      # Clipboard picker
      "Mod+V".action.spawn = [ "bash" "-c" "cliphist list | fuzzel --dmenu | cliphist decode | wl-copy" ];

      # Screenshot (region to clipboard)
      "Mod+Shift+S".action.spawn = [ "bash" "-c" "grim -g \"$(slurp)\" - | wl-copy" ];

      # Wallpaper picker (auto-switches theme)
      "Mod+T".action.spawn = [ "wallpaper-pick" ];

      # Power menu
      "Mod+Escape".action.spawn = [ "power-menu" ];

      # Window management
      "Mod+Q".action.close-window = [];
      "Mod+F".action.maximize-column = [];
      "Mod+Shift+F".action.fullscreen-window = [];

      # Cycle preset column widths
      "Mod+R".action.switch-preset-column-width = [];

      # Focus columns
      "Mod+H".action.focus-column-left = [];
      "Mod+L".action.focus-column-right = [];

      # Move columns
      "Mod+Ctrl+H".action.move-column-left = [];
      "Mod+Ctrl+L".action.move-column-right = [];

      # Workspace navigation (up/down for vertical workspaces)
      "Mod+J".action.focus-workspace-down = [];
      "Mod+K".action.focus-workspace-up = [];

      # Move window to adjacent workspace
      "Mod+Shift+H".action.move-column-to-workspace-up = [];
      "Mod+Shift+J".action.move-column-to-workspace-down = [];
      "Mod+Shift+K".action.move-column-to-workspace-up = [];
      "Mod+Shift+L".action.move-column-to-workspace-down = [];

      # Direct workspace switching
      "Mod+1".action.focus-workspace = 1;
      "Mod+2".action.focus-workspace = 2;
      "Mod+3".action.focus-workspace = 3;
      "Mod+4".action.focus-workspace = 4;
      "Mod+5".action.focus-workspace = 5;
      "Mod+6".action.focus-workspace = 6;
      "Mod+7".action.focus-workspace = 7;
      "Mod+8".action.focus-workspace = 8;
      "Mod+9".action.focus-workspace = 9;

      # Move window to workspace
      "Mod+Shift+1".action.move-column-to-workspace = 1;
      "Mod+Shift+2".action.move-column-to-workspace = 2;
      "Mod+Shift+3".action.move-column-to-workspace = 3;
      "Mod+Shift+4".action.move-column-to-workspace = 4;
      "Mod+Shift+5".action.move-column-to-workspace = 5;
      "Mod+Shift+6".action.move-column-to-workspace = 6;
      "Mod+Shift+7".action.move-column-to-workspace = 7;
      "Mod+Shift+8".action.move-column-to-workspace = 8;
      "Mod+Shift+9".action.move-column-to-workspace = 9;

      # Move between monitors
      "Mod+Shift+Period".action.move-column-to-monitor-right = [];
      "Mod+Shift+Comma".action.move-column-to-monitor-left = [];

      # Scroll through workspaces
      "Mod+WheelScrollDown".action.focus-workspace-down = [];
      "Mod+WheelScrollUp".action.focus-workspace-up = [];

      # Screenshots (save to file)
      "Print".action.screenshot = [];
      "Alt+Print".action.screenshot-window = [];

      # Exit niri
      "Mod+Shift+E".action.quit = [];

      # Power off monitors
      "Mod+Shift+P".action.power-off-monitors = [];
    };

    # Startup apps
    spawn-at-startup = [
      { command = [ "waybar" ]; }
      { command = [ "awww-daemon" ]; }
      { command = [ "mako" ]; }
      { command = [ "wl-paste" "--watch" "cliphist" "store" ]; }
    ];
  };
}
