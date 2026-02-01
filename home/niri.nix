{ config, lib, pkgs, ... }:

let
  # Settings template for ThemePropagator to read and inject colors
  niriTemplate = {
    outputs = {
      "HDMI-A-1" = { position = { x = 0; y = 0; }; };
      "DP-3" = { position = { x = 1920; y = 0; }; };
    };
    preferNoCsd = true;
    screenshotPath = "~/Pictures/Screenshots/%Y-%m-%d_%H-%M-%S.png";
    input = {
      keyboard.xkb.layout = "us";
      touchpad = { tap = true; naturalScroll = true; };
    };
    layout = {
      gaps = 8;
      shadow = { enable = true; };
      struts = { top = 42; left = 26; right = 26; bottom = 26; };
      border = { width = 2; };  # Colors injected by ThemePropagator
    };
    windowRules = [
      { geometryCornerRadius = 12.0; clipToGeometry = true; }
    ];
    animations = {
      workspaceSwitch = { enable = false; };
    };
    binds = let qs = "${pkgs.quickshell}/bin/qs"; in {
      "Mod+T" = { action.spawn = [ qs "ipc" "call" "themePicker" "toggle" ]; };
      "Mod+D" = { action.spawn = [ qs "ipc" "call" "drawers" "toggle" "launcher" ]; };
      "Mod+X" = { action.spawn = [ qs "ipc" "call" "drawers" "toggle" "session" ]; };
      "Mod+A" = { action.spawn = [ qs "ipc" "call" "drawers" "toggle" "dashboard" ]; };
      "Mod+Return" = { action.spawn = [ "ghostty" ]; };
      "Mod+Q" = { action.close-window = []; };
      "Mod+F" = { action.maximize-column = []; };
      "Mod+Shift+F" = { action.fullscreen-window = []; };
      "Mod+H" = { action.focus-column-left = []; };
      "Mod+L" = { action.focus-column-right = []; };
      "Mod+Shift+H" = { action.move-column-left = []; };
      "Mod+Shift+L" = { action.move-column-right = []; };
      "Mod+J" = { action.focus-workspace-down = []; };
      "Mod+K" = { action.focus-workspace-up = []; };
      "Mod+Shift+J" = { action.move-column-to-workspace-down = []; };
      "Mod+Shift+K" = { action.move-column-to-workspace-up = []; };
      "Mod+Shift+Period" = { action.move-column-to-monitor-right = []; };
      "Mod+Shift+Comma" = { action.move-column-to-monitor-left = []; };
      "Mod+1" = { action.focus-workspace = [ 1 ]; };
      "Mod+2" = { action.focus-workspace = [ 2 ]; };
      "Mod+3" = { action.focus-workspace = [ 3 ]; };
      "Mod+4" = { action.focus-workspace = [ 4 ]; };
      "Mod+5" = { action.focus-workspace = [ 5 ]; };
      "Mod+6" = { action.focus-workspace = [ 6 ]; };
      "Mod+7" = { action.focus-workspace = [ 7 ]; };
      "Mod+8" = { action.focus-workspace = [ 8 ]; };
      "Mod+9" = { action.focus-workspace = [ 9 ]; };
      "Mod+Shift+1" = { action.move-column-to-workspace = [ 1 ]; };
      "Mod+Shift+2" = { action.move-column-to-workspace = [ 2 ]; };
      "Mod+Shift+3" = { action.move-column-to-workspace = [ 3 ]; };
      "Mod+Shift+4" = { action.move-column-to-workspace = [ 4 ]; };
      "Mod+Shift+5" = { action.move-column-to-workspace = [ 5 ]; };
      "Mod+Shift+6" = { action.move-column-to-workspace = [ 6 ]; };
      "Mod+Shift+7" = { action.move-column-to-workspace = [ 7 ]; };
      "Mod+Shift+8" = { action.move-column-to-workspace = [ 8 ]; };
      "Mod+Shift+9" = { action.move-column-to-workspace = [ 9 ]; };
      "Mod+WheelScrollDown" = { action.focus-workspace-down = []; };
      "Mod+WheelScrollUp" = { action.focus-workspace-up = []; };
      "Print" = { action.screenshot = []; };
      "Alt+Print" = { action.screenshot-window = []; };
      "Ctrl+Print" = { action.spawn = [ "bash" "-c" "grim -g \"$(slurp)\" - | wl-copy" ]; };
      "Ctrl+Alt+Print" = { action.spawn = [ "bash" "-c" "grim - | wl-copy" ]; };
      "Mod+F1" = { action.spawn = [ qs "ipc" "call" "keybinds" "toggle" ]; };
      "Mod+Shift+E" = { action.quit = []; };
      "Mod+Shift+P" = { action.power-off-monitors = []; };
    };
    spawnAtStartup = [
      { command = [ "quickshell" "-p" "/home/kamdyns/.config/quickshell" ]; }
    ];
  };
in
{
  # Export template for ThemePropagator to read
  xdg.configFile."niri/config-template.json".text = builtins.toJSON niriTemplate;

  programs.niri.settings = {
    # Monitor configuration
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
    
    # Enable window shadows
    layout.shadow.enable = true;

    # Gaps between windows
    layout.gaps = 8;

    # Struts to reserve space for quickshell panels
    # These values must match Layout.qml: totalBorderWidth=16, barHeight=32
    layout.struts = {
      top = 42;     # barHeight
      left = 26;    # totalBorderWidth (screenBorderWidth + windowGap)
      right = 26;
      bottom = 26;
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
        # Rounded corners for windows - should harmonize with frame inner corners
        geometry-corner-radius = let r = 12.0; in {
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
    binds = let qs = "${pkgs.quickshell}/bin/qs"; in {
      # Theme picker
      "Mod+T".action.spawn = [ qs "ipc" "call" "themePicker" "toggle" ];

      # Caelestia drawers
      "Mod+D".action.spawn = [ qs "ipc" "call" "drawers" "toggle" "launcher" ];
      "Mod+X".action.spawn = [ qs "ipc" "call" "drawers" "toggle" "session" ];
      "Mod+A".action.spawn = [ qs "ipc" "call" "drawers" "toggle" "dashboard" ];

      # App launchers
      "Mod+Return".action.spawn = [ "ghostty" ];
      
      # Window management
      "Mod+Q".action.close-window = [];
      "Mod+F".action.maximize-column = [];        # Respects struts/border
      "Mod+Shift+F".action.fullscreen-window = []; # True fullscreen (covers border)
      
      # Focus columns
      "Mod+H".action.focus-column-left = [];
      "Mod+L".action.focus-column-right = [];

      # Move columns
      "Mod+Shift+H".action.move-column-left = [];
      "Mod+Shift+L".action.move-column-right = [];

      # Workspace navigation (creates new workspace if navigating past the last one)
      "Mod+J".action.focus-workspace-down = [];
      "Mod+K".action.focus-workspace-up = [];

      # Move window to workspace
      "Mod+Shift+J".action.move-column-to-workspace-down = [];
      "Mod+Shift+K".action.move-column-to-workspace-up = [];

      # Move windows between monitors
      "Mod+Shift+Period".action.move-column-to-monitor-right = [];
      "Mod+Shift+Comma".action.move-column-to-monitor-left = [];
      
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
      
      # Screenshots (save to file)
      "Print".action.screenshot = [];
      "Alt+Print".action.screenshot-window = [];

      # Screenshots to clipboard
      "Ctrl+Print".action.spawn = [ "bash" "-c" "grim -g \"$(slurp)\" - | wl-copy" ];
      "Ctrl+Alt+Print".action.spawn = [ "bash" "-c" "grim - | wl-copy" ];

      # Keybinding help (Mod+F1)
      "Mod+F1".action.spawn = [ qs "ipc" "call" "keybinds" "toggle" ];
      
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
