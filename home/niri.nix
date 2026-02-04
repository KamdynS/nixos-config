{ config, lib, pkgs, ... }:

{
  # Niri border colors are static - changing themes requires a rebuild
  # Future: could use niri IPC if it adds runtime color changing support
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

    # Preset column widths for cycling (1/3 → 1/2 → 2/3 → full)
    layout.preset-column-widths = [
      { proportion = 0.33333; }
      { proportion = 0.5; }
      { proportion = 0.66667; }
      { proportion = 1.0; }
    ];

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
    binds = let
      qs = "${pkgs.quickshell}/bin/qs";
      niri = "${pkgs.niri}/bin/niri";
      jq = "${pkgs.jq}/bin/jq";

      # Helper script for column width cycling without wrap
      cycleColumnWidth = pkgs.writeShellScript "cycle-column-width" ''
        direction="$1"  # "next" or "prev"
        presets=(0.33333 0.5 0.66667 1.0)

        # Get focused window info
        window_json=$(${niri} msg -j focused-window 2>/dev/null)
        [ "$window_json" = "null" ] || [ -z "$window_json" ] && exit 0

        # Get window width from the window's size
        window_width=$(echo "$window_json" | ${jq} -r '.size.width // empty')
        [ -z "$window_width" ] && exit 0

        # Get the output (monitor) that the window is on
        workspace_id=$(echo "$window_json" | ${jq} -r '.workspace_id // empty')
        [ -z "$workspace_id" ] && exit 0

        # Get monitor width from the workspace's output
        output_name=$(${niri} msg -j workspaces 2>/dev/null | ${jq} -r ".[] | select(.id == $workspace_id) | .output")
        [ -z "$output_name" ] && exit 0

        monitor_width=$(${niri} msg -j outputs 2>/dev/null | ${jq} -r ".[] | select(.name == \"$output_name\") | .modes[] | select(.is_current) | .width")
        [ -z "$monitor_width" ] || [ "$monitor_width" = "0" ] && exit 0

        # Account for gaps and struts (approximate - 2*26 for left/right struts, 2*8 for gaps)
        usable_width=$((monitor_width - 52 - 16))

        # Calculate current proportion
        current=$(echo "scale=5; $window_width / $usable_width" | ${pkgs.bc}/bin/bc)

        # Find closest preset index
        closest_idx=0
        min_diff=999
        for i in "''${!presets[@]}"; do
          diff=$(echo "scale=5; x = ''${presets[$i]} - $current; if (x < 0) -x else x" | ${pkgs.bc}/bin/bc)
          is_smaller=$(echo "$diff < $min_diff" | ${pkgs.bc}/bin/bc)
          if [ "$is_smaller" = "1" ]; then
            min_diff=$diff
            closest_idx=$i
          fi
        done

        # Calculate target index based on direction
        if [ "$direction" = "next" ]; then
          target_idx=$((closest_idx + 1))
          [ $target_idx -ge ''${#presets[@]} ] && exit 0  # already at max
        else
          target_idx=$((closest_idx - 1))
          [ $target_idx -lt 0 ] && exit 0  # already at min
        fi

        # Set new width
        ${niri} msg action set-column-width "''${presets[$target_idx]}"
      '';
    in {
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

      # Resize columns (cycle through preset widths: 1/3 → 1/2 → 2/3 → full, no wrap)
      "Mod+O".action.spawn = [ "${cycleColumnWidth}" "next" ];
      "Mod+Y".action.spawn = [ "${cycleColumnWidth}" "prev" ];

      # Workspace navigation (creates new workspace if navigating past the last one)
      "Mod+J".action.focus-workspace-down = [];
      "Mod+K".action.focus-workspace-up = [];

      # Move window to workspace
      "Mod+Shift+J".action.move-column-to-workspace-down = [];
      "Mod+Shift+K".action.move-column-to-workspace-up = [];

      # Move windows between monitors
      "Mod+Shift+Period".action.move-column-to-monitor-right = [];
      "Mod+Shift+Comma".action.move-column-to-monitor-left = [];
      
      # Workspace switching via daemon (global index across all monitors)
      "Mod+1".action.spawn = [ "busctl" "--user" "call" "org.caelestia.Niri" "/org/caelestia/Niri" "org.caelestia.Niri" "FocusWorkspaceByGlobalIndex" "u" "1" ];
      "Mod+2".action.spawn = [ "busctl" "--user" "call" "org.caelestia.Niri" "/org/caelestia/Niri" "org.caelestia.Niri" "FocusWorkspaceByGlobalIndex" "u" "2" ];
      "Mod+3".action.spawn = [ "busctl" "--user" "call" "org.caelestia.Niri" "/org/caelestia/Niri" "org.caelestia.Niri" "FocusWorkspaceByGlobalIndex" "u" "3" ];
      "Mod+4".action.spawn = [ "busctl" "--user" "call" "org.caelestia.Niri" "/org/caelestia/Niri" "org.caelestia.Niri" "FocusWorkspaceByGlobalIndex" "u" "4" ];
      "Mod+5".action.spawn = [ "busctl" "--user" "call" "org.caelestia.Niri" "/org/caelestia/Niri" "org.caelestia.Niri" "FocusWorkspaceByGlobalIndex" "u" "5" ];
      "Mod+6".action.spawn = [ "busctl" "--user" "call" "org.caelestia.Niri" "/org/caelestia/Niri" "org.caelestia.Niri" "FocusWorkspaceByGlobalIndex" "u" "6" ];
      "Mod+7".action.spawn = [ "busctl" "--user" "call" "org.caelestia.Niri" "/org/caelestia/Niri" "org.caelestia.Niri" "FocusWorkspaceByGlobalIndex" "u" "7" ];
      "Mod+8".action.spawn = [ "busctl" "--user" "call" "org.caelestia.Niri" "/org/caelestia/Niri" "org.caelestia.Niri" "FocusWorkspaceByGlobalIndex" "u" "8" ];
      "Mod+9".action.spawn = [ "busctl" "--user" "call" "org.caelestia.Niri" "/org/caelestia/Niri" "org.caelestia.Niri" "FocusWorkspaceByGlobalIndex" "u" "9" ];

      # Move window to workspace via daemon (global index across all monitors)
      "Mod+Shift+1".action.spawn = [ "busctl" "--user" "call" "org.caelestia.Niri" "/org/caelestia/Niri" "org.caelestia.Niri" "MoveWindowToWorkspaceByGlobalIndex" "u" "1" ];
      "Mod+Shift+2".action.spawn = [ "busctl" "--user" "call" "org.caelestia.Niri" "/org/caelestia/Niri" "org.caelestia.Niri" "MoveWindowToWorkspaceByGlobalIndex" "u" "2" ];
      "Mod+Shift+3".action.spawn = [ "busctl" "--user" "call" "org.caelestia.Niri" "/org/caelestia/Niri" "org.caelestia.Niri" "MoveWindowToWorkspaceByGlobalIndex" "u" "3" ];
      "Mod+Shift+4".action.spawn = [ "busctl" "--user" "call" "org.caelestia.Niri" "/org/caelestia/Niri" "org.caelestia.Niri" "MoveWindowToWorkspaceByGlobalIndex" "u" "4" ];
      "Mod+Shift+5".action.spawn = [ "busctl" "--user" "call" "org.caelestia.Niri" "/org/caelestia/Niri" "org.caelestia.Niri" "MoveWindowToWorkspaceByGlobalIndex" "u" "5" ];
      "Mod+Shift+6".action.spawn = [ "busctl" "--user" "call" "org.caelestia.Niri" "/org/caelestia/Niri" "org.caelestia.Niri" "MoveWindowToWorkspaceByGlobalIndex" "u" "6" ];
      "Mod+Shift+7".action.spawn = [ "busctl" "--user" "call" "org.caelestia.Niri" "/org/caelestia/Niri" "org.caelestia.Niri" "MoveWindowToWorkspaceByGlobalIndex" "u" "7" ];
      "Mod+Shift+8".action.spawn = [ "busctl" "--user" "call" "org.caelestia.Niri" "/org/caelestia/Niri" "org.caelestia.Niri" "MoveWindowToWorkspaceByGlobalIndex" "u" "8" ];
      "Mod+Shift+9".action.spawn = [ "busctl" "--user" "call" "org.caelestia.Niri" "/org/caelestia/Niri" "org.caelestia.Niri" "MoveWindowToWorkspaceByGlobalIndex" "u" "9" ];
      
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
      "Mod+W".action.spawn = [ qs "ipc" "call" "keybinds" "toggle" ];
      
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
