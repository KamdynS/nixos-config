{ config, lib, pkgs, nix-colors, ... }:

let
  # Import all theme definitions
  themes = {
    gruvbox-light = import ../../themes/gruvbox-light.nix { inherit nix-colors; };
    gruvbox-dark = import ../../themes/gruvbox-dark.nix { inherit nix-colors; };
    catppuccin-mocha = import ../../themes/catppuccin-mocha.nix { inherit nix-colors; };
    kanagawa = import ../../themes/kanagawa.nix { inherit nix-colors; };
    rose-pine = import ../../themes/rose-pine.nix { inherit nix-colors; };
    tokyonight = import ../../themes/tokyonight.nix { inherit nix-colors; };
  };

  themeNames = builtins.attrNames themes;
  defaultTheme = "gruvbox-light";

  # Powerline chevron glyphs (Nerd Font private-use area)
  # Decoded via fromJSON so the source file stays plain ASCII
  chevronR = builtins.fromJSON "\"\\ue0b0\"";  # right-pointing solid
  chevronL = builtins.fromJSON "\"\\ue0b2\"";  # left-pointing solid
  iconNixOS = builtins.fromJSON "\"\\uf313\"";
  iconBranch = builtins.fromJSON "\"\\uf418\"";
  iconRust = builtins.fromJSON "\"\\ue7a8\"";
  iconGo = builtins.fromJSON "\"\\ue65e\"";
  iconPython = builtins.fromJSON "\"\\ue235\"";
  iconNode = builtins.fromJSON "\"\\ue718\"";
  iconBun = builtins.fromJSON "\"\\ue76f\"";
  iconLua = builtins.fromJSON "\"\\ue620\"";
  iconNix = builtins.fromJSON "\"\\uf313\"";
  iconClock = builtins.fromJSON "\"\\uf017\"";
  iconTimer = builtins.fromJSON "\"\\uf252\"";
  iconC = builtins.fromJSON "\"\\ue61e\"";
  iconJava = builtins.fromJSON "\"\\ue256\"";
  iconKotlin = builtins.fromJSON "\"\\ue634\"";
  iconHaskell = builtins.fromJSON "\"\\ue777\"";
  iconDocker = builtins.fromJSON "\"\\uf308\"";
  iconConda = builtins.fromJSON "\"\\ue73c\"";
  iconPrompt = builtins.fromJSON "\"\\u276f\"";  # ❯

  # Generate waybar CSS for a theme
  mkWaybarCss = theme: ''
    /* Theme: ${theme.name} */
    * {
      font-family: "JetBrainsMono Nerd Font", monospace;
      font-size: 18px;
    }

    window#waybar {
      background-color: #${theme.palette.base00};
      color: #${theme.palette.base05};
      border-bottom: 2px solid #${theme.palette.base0D};
    }

    #clock {
      padding: 0 12px;
      color: #${theme.palette.base05};
    }

    #workspaces button {
      padding: 0 8px;
      color: #${theme.palette.base04};
      background: transparent;
      border: none;
      border-radius: 0;
    }

    #workspaces button.focused,
    #workspaces button.active {
      color: #${theme.palette.base00};
      background-color: #${theme.palette.base0D};
    }

    #workspaces button:hover {
      background-color: #${theme.palette.base02};
    }

    #network {
      padding: 0 12px;
      color: #${theme.palette.base0B};
    }

    #network.disconnected {
      color: #${theme.palette.base08};
    }
  '';

  # Generate ghostty theme file
  mkGhosttyTheme = theme: ''
    # Theme: ${theme.name}
    background = ${theme.palette.base00}
    foreground = ${theme.palette.base05}
    cursor-color = ${theme.palette.base05}
    selection-background = ${theme.palette.base02}
    selection-foreground = ${theme.palette.base05}

    # Normal colors
    palette = 0=#${theme.palette.base00}
    palette = 1=#${theme.palette.base08}
    palette = 2=#${theme.palette.base0B}
    palette = 3=#${theme.palette.base0A}
    palette = 4=#${theme.palette.base0D}
    palette = 5=#${theme.palette.base0E}
    palette = 6=#${theme.palette.base0C}
    palette = 7=#${theme.palette.base05}

    # Bright colors
    palette = 8=#${theme.palette.base03}
    palette = 9=#${theme.palette.base08}
    palette = 10=#${theme.palette.base0B}
    palette = 11=#${theme.palette.base0A}
    palette = 12=#${theme.palette.base0D}
    palette = 13=#${theme.palette.base0E}
    palette = 14=#${theme.palette.base0C}
    palette = 15=#${theme.palette.base07}
  '';

  # Generate mako config for a theme
  mkMakoConf = theme: ''
    # Theme: ${theme.name}
    font=JetBrainsMono Nerd Font 11
    background-color=#${theme.palette.base00}
    text-color=#${theme.palette.base05}
    border-color=#${theme.palette.base0D}
    border-size=2
    border-radius=8
    padding=12
    default-timeout=5000
    max-visible=3

    [urgency=low]
    border-color=#${theme.palette.base03}

    [urgency=high]
    border-color=#${theme.palette.base08}
    default-timeout=0
  '';

  # Generate fuzzel config for a theme
  mkFuzzelIni = theme: ''
    # Theme: ${theme.name}
    [main]
    font=JetBrainsMono Nerd Font:size=12
    prompt="❯ "
    icon-theme=Papirus
    layer=overlay

    [colors]
    background=${theme.palette.base00}ff
    text=${theme.palette.base05}ff
    match=${theme.palette.base0D}ff
    selection=${theme.palette.base02}ff
    selection-text=${theme.palette.base05}ff
    selection-match=${theme.palette.base0D}ff
    border=${theme.palette.base0D}ff

    [border]
    width=2
    radius=8
  '';

  # Generate starship palette section for a theme
  # fg_accent = the lightest color in the palette: base00 for light themes,
  # base07 for dark. Used as text color on saturated segments so it stays
  # readable across all six themes.
  mkStarshipPalette = theme:
    let
      fgAccent = if theme.polarity == "light" then theme.palette.base00 else theme.palette.base07;
    in ''
      [palettes.${theme.name}]
      base00 = "#${theme.palette.base00}"
      base01 = "#${theme.palette.base01}"
      base02 = "#${theme.palette.base02}"
      base03 = "#${theme.palette.base03}"
      base04 = "#${theme.palette.base04}"
      base05 = "#${theme.palette.base05}"
      base06 = "#${theme.palette.base06}"
      base07 = "#${theme.palette.base07}"
      base08 = "#${theme.palette.base08}"
      base09 = "#${theme.palette.base09}"
      base0a = "#${theme.palette.base0A}"
      base0b = "#${theme.palette.base0B}"
      base0c = "#${theme.palette.base0C}"
      base0d = "#${theme.palette.base0D}"
      base0e = "#${theme.palette.base0E}"
      base0f = "#${theme.palette.base0F}"
      fg_accent = "#${fgAccent}"
    '';

  # Generate one [<scheme>] section of the spicetify color.ini.
  # All six rice themes are emitted into a single color.ini under the
  # `base16` theme directory; theme-switch flips the active section via
  # `spicetify config color_scheme`.
  mkSpicetifyScheme = theme: ''
    [${theme.name}]
    text                 = ${theme.palette.base05}
    subtext              = ${theme.palette.base04}
    sidebar-text         = ${theme.palette.base05}
    main                 = ${theme.palette.base00}
    sidebar              = ${theme.palette.base01}
    player               = ${theme.palette.base01}
    card                 = ${theme.palette.base01}
    shadow               = ${theme.palette.base00}
    selected-row         = ${theme.palette.base02}
    button               = ${theme.palette.base0D}
    button-active        = ${theme.palette.base0C}
    button-disabled      = ${theme.palette.base03}
    tab-active           = ${theme.palette.base02}
    notification         = ${theme.palette.base0B}
    notification-error   = ${theme.palette.base08}
    misc                 = ${theme.palette.base02}
  '';

  spicetifyColorIni = lib.concatStringsSep "\n" (lib.mapAttrsToList (_: mkSpicetifyScheme) themes);

  # Generate rofi-wayland .rasi for the wallpaper-pick carousel.
  # Horizontal 3-column layout, 300px icon slot (thumbnails are 300x200 with
  # vertical breathing room inside the square slot), solid colors throughout.
  mkRofiCarousel = theme: ''
    /* Theme: ${theme.name} — generated by rice theming.nix, do not edit */

    * {
        bg:          #${theme.palette.base00};
        fg:          #${theme.palette.base05};
        accent:      #${theme.palette.base0D};
        selected-bg: #${theme.palette.base02};

        background-color: transparent;
        text-color:       @fg;
    }

    window {
        background-color: @bg;
        border:           2px;
        border-color:     @accent;
        border-radius:    12px;
        padding:          24px;
        width:            1200px;
        location:         center;
        anchor:           center;
        children:         [ mainbox ];
    }

    mainbox {
        children: [ listview ];
        spacing:  0;
    }

    listview {
        layout:    horizontal;
        lines:     1;
        columns:   3;
        spacing:   16px;
        cycle:     true;
        scrollbar: false;
    }

    element {
        orientation:   vertical;
        padding:       12px;
        spacing:       8px;
        background-color: @bg;
        text-color:    @fg;
        border-radius: 8px;
        children:      [ element-icon, element-text ];
    }

    element selected {
        background-color: @selected-bg;
        border:           2px;
        border-color:     @accent;
        border-radius:    8px;
    }

    element-icon {
        size:             300px;
        horizontal-align: 0.5;
    }

    element-text {
        horizontal-align: 0.5;
        vertical-align:   0.5;
        font:             "JetBrainsMono Nerd Font 14";
    }
  '';

  # Generate Zen Browser userChrome.css for a theme.
  # Variables-first (Firefox/Zen CSS vars) with a few explicit selectors that
  # the base CSS doesn't fully cover (tabs, urlbar). Symlinked into the Zen
  # profile by theme-switch.
  mkZenChrome = theme: ''
    /* Theme: ${theme.name} — generated by rice theming.nix, do not edit */

    :root {
      --base00: #${theme.palette.base00};
      --base01: #${theme.palette.base01};
      --base02: #${theme.palette.base02};
      --base03: #${theme.palette.base03};
      --base04: #${theme.palette.base04};
      --base05: #${theme.palette.base05};
      --base06: #${theme.palette.base06};
      --base07: #${theme.palette.base07};
      --base08: #${theme.palette.base08};
      --base09: #${theme.palette.base09};
      --base0A: #${theme.palette.base0A};
      --base0B: #${theme.palette.base0B};
      --base0C: #${theme.palette.base0C};
      --base0D: #${theme.palette.base0D};
      --base0E: #${theme.palette.base0E};
      --base0F: #${theme.palette.base0F};

      /* Firefox/Zen toolbar variables */
      --toolbar-bgcolor: var(--base00) !important;
      --toolbar-color: var(--base05) !important;
      --lwt-accent-color: var(--base0D) !important;
      --lwt-text-color: var(--base05) !important;
      --lwt-toolbarbutton-icon-fill: var(--base05) !important;

      /* Zen-specific accents (newer Zen versions) */
      --zen-colors-primary: var(--base0D) !important;
      --zen-colors-secondary: var(--base0C) !important;
      --zen-colors-tertiary: var(--base0E) !important;
    }

    /* Explicit element styling that variables alone don't cover */
    #TabsToolbar { background-color: var(--base00) !important; }
    .tab-background { background-color: var(--base00) !important; }
    .tab-background[selected="true"] { background-color: var(--base02) !important; }
    #urlbar-background { background-color: var(--base01) !important; }
    #urlbar-input { color: var(--base05) !important; }
  '';

  # Generate nvim active-theme.lua for a theme
  mkNvimTheme = theme: ''
    -- Theme: ${theme.name}
    -- This file is generated by theming.nix and symlinked by theme-switch
    return {
      name = "${theme.name}",
      polarity = "${theme.polarity}",
      palette = {
        base00 = "#${theme.palette.base00}",
        base01 = "#${theme.palette.base01}",
        base02 = "#${theme.palette.base02}",
        base03 = "#${theme.palette.base03}",
        base04 = "#${theme.palette.base04}",
        base05 = "#${theme.palette.base05}",
        base06 = "#${theme.palette.base06}",
        base07 = "#${theme.palette.base07}",
        base08 = "#${theme.palette.base08}",
        base09 = "#${theme.palette.base09}",
        base0A = "#${theme.palette.base0A}",
        base0B = "#${theme.palette.base0B}",
        base0C = "#${theme.palette.base0C}",
        base0D = "#${theme.palette.base0D}",
        base0E = "#${theme.palette.base0E}",
        base0F = "#${theme.palette.base0F}",
      }
    }
  '';

  # Generate all per-theme config files
  themeConfigs = lib.mapAttrs' (name: theme: {
    name = "waybar/themes/${name}.css";
    value = { text = mkWaybarCss theme; };
  }) themes // lib.mapAttrs' (name: theme: {
    name = "ghostty/themes/${name}";
    value = { text = mkGhosttyTheme theme; };
  }) themes // lib.mapAttrs' (name: theme: {
    name = "mako/themes/${name}.conf";
    value = { text = mkMakoConf theme; };
  }) themes // lib.mapAttrs' (name: theme: {
    name = "fuzzel/themes/${name}.ini";
    value = { text = mkFuzzelIni theme; };
  }) themes // lib.mapAttrs' (name: theme: {
    name = "nvim-theme/${name}.lua";
    value = { text = mkNvimTheme theme; };
  }) themes // lib.mapAttrs' (name: theme: {
    name = "zen-chrome/${name}.css";
    value = { text = mkZenChrome theme; };
  }) themes // lib.mapAttrs' (name: theme: {
    name = "rofi/themes/${name}.rasi";
    value = { text = mkRofiCarousel theme; };
  }) themes // {
    # Spicetify uses a single theme dir with all six schemes as sections.
    # color.ini is read by `spicetify apply`; user.css is required but unused.
    "spicetify/Themes/base16/color.ini".text = spicetifyColorIni;
    "spicetify/Themes/base16/user.css".text = "/* base16 theme — colors only */\n";
  };

  # Build starship.toml with all palette definitions
  starshipConfig = ''
    # Starship prompt configuration
    # Palettes are defined per-theme, palette_name is set by theme-switch

    # Gruvbox-rainbow preset, ported to base16 so it works with all themes.
    # Color flow:
    #   base09 (orange) → base0A (yellow) → base0C (aqua)
    #   → base0D (blue) → base02 (gray) → base01 (deeper gray)
    format = """
    [${chevronR}](fg:base09)\
    $os\
    $username\
    [${chevronR}](fg:base09 bg:base0a)\
    $directory\
    [${chevronR}](fg:base0a bg:base0c)\
    $git_branch\
    $git_status\
    [${chevronR}](fg:base0c bg:base0d)\
    $c\
    $rust\
    $golang\
    $nodejs\
    $bun\
    $python\
    $lua\
    $java\
    $kotlin\
    $haskell\
    $nix_shell\
    [${chevronR}](fg:base0d bg:base02)\
    $docker_context\
    $conda\
    [${chevronR}](fg:base02 bg:base01)\
    $cmd_duration\
    $time\
    [${chevronR} ](fg:base01)\
    $line_break\
    $character"""

    palette = "${defaultTheme}"

    [os]
    disabled = false
    style = "bg:base09 fg:fg_accent"
    format = "[ $symbol ]($style)"

    [os.symbols]
    NixOS = "${iconNixOS}"
    Macos = ""
    Linux = "${iconNixOS}"

    [username]
    show_always = true
    style_user = "bg:base09 fg:fg_accent"
    style_root = "bg:base09 fg:fg_accent"
    format = "[ $user ]($style)"

    [directory]
    style = "fg:fg_accent bg:base0a"
    format = "[ $path ]($style)"
    truncation_length = 3
    truncation_symbol = "…/"

    [git_branch]
    symbol = "${iconBranch}"
    style = "bg:base0c"
    format = "[[ $symbol $branch ](fg:fg_accent bg:base0c)]($style)"

    [git_status]
    style = "bg:base0c"
    format = "[[($all_status$ahead_behind )](fg:fg_accent bg:base0c)]($style)"
    ahead = "↑"
    behind = "↓"
    modified = "!"
    untracked = "?"
    staged = "+"

    [c]
    symbol = "${iconC}"
    style = "bg:base0d"
    format = "[[ $symbol( $version) ](fg:fg_accent bg:base0d)]($style)"

    [rust]
    symbol = "${iconRust}"
    style = "bg:base0d"
    format = "[[ $symbol( $version) ](fg:fg_accent bg:base0d)]($style)"

    [golang]
    symbol = "${iconGo}"
    style = "bg:base0d"
    format = "[[ $symbol( $version) ](fg:fg_accent bg:base0d)]($style)"

    [nodejs]
    symbol = "${iconNode}"
    style = "bg:base0d"
    format = "[[ $symbol( $version) ](fg:fg_accent bg:base0d)]($style)"

    [bun]
    symbol = "${iconBun}"
    style = "bg:base0d"
    format = "[[ $symbol( $version) ](fg:fg_accent bg:base0d)]($style)"

    [python]
    symbol = "${iconPython}"
    style = "bg:base0d"
    format = "[[ $symbol( $version)$virtualenv ](fg:fg_accent bg:base0d)]($style)"

    [lua]
    symbol = "${iconLua}"
    style = "bg:base0d"
    format = "[[ $symbol( $version) ](fg:fg_accent bg:base0d)]($style)"

    [java]
    symbol = "${iconJava}"
    style = "bg:base0d"
    format = "[[ $symbol( $version) ](fg:fg_accent bg:base0d)]($style)"

    [kotlin]
    symbol = "${iconKotlin}"
    style = "bg:base0d"
    format = "[[ $symbol( $version) ](fg:fg_accent bg:base0d)]($style)"

    [haskell]
    symbol = "${iconHaskell}"
    style = "bg:base0d"
    format = "[[ $symbol( $version) ](fg:fg_accent bg:base0d)]($style)"

    [nix_shell]
    symbol = "${iconNix}"
    style = "bg:base0d"
    format = "[[ $symbol $state ](fg:fg_accent bg:base0d)]($style)"

    [docker_context]
    symbol = "${iconDocker}"
    style = "bg:base02"
    format = "[[ $symbol( $context) ](fg:base0d bg:base02)]($style)"

    [conda]
    symbol = "${iconConda}"
    style = "bg:base02"
    format = "[[ $symbol( $environment) ](fg:base0d bg:base02)]($style)"

    [cmd_duration]
    min_time = 500
    style = "bg:base01"
    format = "[[ ${iconTimer} $duration ](fg:base05 bg:base01)]($style)"

    [time]
    disabled = false
    time_format = "%R"
    style = "bg:base01"
    format = "[[ ${iconClock} $time ](fg:base05 bg:base01)]($style)"

    [line_break]
    disabled = false

    [character]
    success_symbol = "[λ](bold fg:base0b)"
    error_symbol = "[λ](bold fg:base08)"
    vimcmd_symbol = "[${iconPrompt}](bold fg:base0b)"
    vimcmd_replace_symbol = "[${iconPrompt}](bold fg:base0e)"
    vimcmd_visual_symbol = "[${iconPrompt}](bold fg:base0a)"

    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: theme: mkStarshipPalette theme) themes)}
  '';

  # Theme metadata for scripts
  themeMetaJson = builtins.toJSON (lib.mapAttrs (name: theme: {
    inherit (theme) name polarity wallpaper;
  }) themes);

  # theme-switch script
  themeSwitchScript = pkgs.writeShellScriptBin "theme-switch" ''
    set -euo pipefail

    THEME="''${1:-}"
    THEMES=(${lib.concatStringsSep " " themeNames})
    CONFIG_DIR="$HOME/.config"

    if [[ -z "$THEME" ]]; then
      echo "Usage: theme-switch <theme-name>"
      echo "Available themes: ''${THEMES[*]}"
      exit 1
    fi

    # Validate theme exists
    VALID=0
    for t in "''${THEMES[@]}"; do
      if [[ "$t" == "$THEME" ]]; then
        VALID=1
        break
      fi
    done

    if [[ $VALID -eq 0 ]]; then
      echo "Error: Unknown theme '$THEME'"
      echo "Available themes: ''${THEMES[*]}"
      exit 1
    fi

    echo "Switching to theme: $THEME"

    # Update symlinks
    ln -sf "$CONFIG_DIR/waybar/themes/$THEME.css" "$CONFIG_DIR/waybar/colors.css"
    ln -sf "$CONFIG_DIR/ghostty/themes/$THEME" "$CONFIG_DIR/ghostty/theme"
    ln -sf "$CONFIG_DIR/mako/themes/$THEME.conf" "$CONFIG_DIR/mako/config"
    ln -sf "$CONFIG_DIR/fuzzel/themes/$THEME.ini" "$CONFIG_DIR/fuzzel/fuzzel.ini"
    ln -sf "$CONFIG_DIR/nvim-theme/$THEME.lua" "$CONFIG_DIR/nvim-theme/active.lua"
    ln -sf "$CONFIG_DIR/rofi/themes/$THEME.rasi" "$CONFIG_DIR/rofi/wallpaper-picker.rasi"

    # Update starship palette
    ${pkgs.gnused}/bin/sed -i "s/^palette = .*/palette = \"$THEME\"/" "$CONFIG_DIR/starship.toml"

    # Reload services
    ${pkgs.procps}/bin/pkill -SIGUSR2 waybar || true
    ${pkgs.mako}/bin/makoctl reload || true
    ${pkgs.procps}/bin/pkill -SIGUSR2 ghostty || true

    # Best-effort nvim reload
    NVIM_SOCKET="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/nvim.sock"
    if [[ -S "$NVIM_SOCKET" ]]; then
      ${pkgs.neovim}/bin/nvim --server "$NVIM_SOCKET" --remote-send ':luafile ~/.config/nvim-theme/active.lua<CR>' 2>/dev/null || true
    fi

    # Spicetify: switch color scheme and re-apply (no-op if Flatpak Spotify
    # isn't installed yet). `spicetify apply` will restart Spotify if running.
    SPOTIFY_DIR="$HOME/.local/share/flatpak/app/com.spotify.Client/current/active/files/extra/share/spotify"
    if [[ -d "$SPOTIFY_DIR" ]]; then
      ${pkgs.spicetify-cli}/bin/spicetify config color_scheme "$THEME" >/dev/null 2>&1 || true
      ${pkgs.spicetify-cli}/bin/spicetify apply >/dev/null 2>&1 || true
    fi

    # Zen Browser: flip userChrome.css symlink in the active profile.
    # Profile dir name has a random prefix and a space; glob into an array
    # to handle the spaces safely. Theme applies on next Zen launch.
    shopt -s nullglob
    zen_profiles=("$HOME"/.zen/*.Default*/chrome)
    shopt -u nullglob
    if [[ ''${#zen_profiles[@]} -gt 0 ]]; then
      ln -sf "$CONFIG_DIR/zen-chrome/$THEME.css" "''${zen_profiles[0]}/userChrome.css"
    fi

    echo "Theme switched to: $THEME"
  '';

  # theme-pick script (fuzzel menu) - switches theme only, no wallpaper
  themePickScript = pkgs.writeShellScriptBin "theme-pick" ''
    THEMES="${lib.concatStringsSep "\\n" themeNames}"
    SELECTED=$(printf "$THEMES" | ${pkgs.fuzzel}/bin/fuzzel --dmenu --prompt "Theme: ")

    if [[ -n "$SELECTED" ]]; then
      ${themeSwitchScript}/bin/theme-switch "$SELECTED"
    fi
  '';

  # wallpaper-switch script - sets wallpaper and auto-switches theme
  wallpaperSwitchScript = pkgs.writeShellScriptBin "wallpaper-switch" ''
    set -euo pipefail

    WALLPAPER_NAME="''${1:-}"
    WALLPAPER_CONFIG="/home/kamdyns/nixos-config/wallpapers/config.json"

    if [[ -z "$WALLPAPER_NAME" ]]; then
      echo "Usage: wallpaper-switch <wallpaper-name>"
      echo "Available wallpapers:"
      ${pkgs.jq}/bin/jq -r 'keys[]' "$WALLPAPER_CONFIG"
      exit 1
    fi

    if [[ ! -f "$WALLPAPER_CONFIG" ]]; then
      echo "Error: Wallpaper config not found at $WALLPAPER_CONFIG"
      exit 1
    fi

    # Get wallpaper path and theme
    WALLPAPER_PATH=$(${pkgs.jq}/bin/jq -r ".[\"$WALLPAPER_NAME\"].path // empty" "$WALLPAPER_CONFIG")
    THEME=$(${pkgs.jq}/bin/jq -r ".[\"$WALLPAPER_NAME\"].theme // empty" "$WALLPAPER_CONFIG")

    if [[ -z "$WALLPAPER_PATH" ]]; then
      echo "Error: Unknown wallpaper '$WALLPAPER_NAME'"
      echo "Available wallpapers:"
      ${pkgs.jq}/bin/jq -r 'keys[]' "$WALLPAPER_CONFIG"
      exit 1
    fi

    echo "Wallpaper: $WALLPAPER_NAME → $THEME"

    # Set wallpaper
    if [[ -f "$WALLPAPER_PATH" ]]; then
      ${pkgs.awww}/bin/awww img "$WALLPAPER_PATH" --transition-type wipe --transition-duration 1
    else
      echo "Warning: Wallpaper file not found at $WALLPAPER_PATH"
    fi

    # Switch theme
    ${themeSwitchScript}/bin/theme-switch "$THEME"
  '';

  # wallpaper-pick script (rofi-wayland carousel) - primary interface.
  # Emits rofi dmenu entries with the image-as-icon protocol so each entry
  # shows its wallpaper thumbnail. Thumbnails are pre-rendered in the
  # activation script.
  wallpaperPickScript = pkgs.writeShellScriptBin "wallpaper-pick" ''
    WALLPAPER_CONFIG="/home/kamdyns/nixos-config/wallpapers/config.json"
    THUMBS_DIR="$HOME/.cache/rice/wallpaper-thumbs"
    ROFI_THEME="$HOME/.config/rofi/wallpaper-picker.rasi"

    if [[ ! -f "$ROFI_THEME" ]]; then
      echo "rofi theme not found at $ROFI_THEME (did you rebuild?)" >&2
      exit 1
    fi

    SELECTED=$(${pkgs.jq}/bin/jq -r 'keys[]' "$WALLPAPER_CONFIG" \
      | while IFS= read -r key; do
          printf '%s\0icon\x1f%s/%s.png\n' "$key" "$THUMBS_DIR" "$key"
        done \
      | ${pkgs.rofi}/bin/rofi -dmenu -show-icons -theme "$ROFI_THEME" -p "Wallpaper")

    if [[ -n "$SELECTED" ]]; then
      ${wallpaperSwitchScript}/bin/wallpaper-switch "$SELECTED"
    fi
  '';

  # power-menu script
  powerMenuScript = pkgs.writeShellScriptBin "power-menu" ''
    OPTIONS="logout\nreboot\nshutdown\nsuspend\ncancel"
    SELECTED=$(printf "$OPTIONS" | ${pkgs.fuzzel}/bin/fuzzel --dmenu --prompt "Power: ")

    case "$SELECTED" in
      logout)
        ${pkgs.niri}/bin/niri msg action quit
        ;;
      reboot)
        systemctl reboot
        ;;
      shutdown)
        systemctl poweroff
        ;;
      suspend)
        systemctl suspend
        ;;
      cancel|"")
        ;;
    esac
  '';

in
{
  # Generate all themed config files
  # NOTE: starship.toml is intentionally NOT managed via xdg.configFile because
  # theme-switch must `sed -i` it to update the active palette, which would
  # break a nix-store symlink. It's seeded as a regular file via activation
  # script below.
  xdg.configFile = themeConfigs;

  # Add scripts to PATH
  home.packages = [
    themeSwitchScript
    themePickScript
    wallpaperSwitchScript
    wallpaperPickScript
    powerMenuScript
  ];

  # Create initial symlinks for default theme on activation
  home.activation.setupThemeSymlinks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p $HOME/.config/waybar
    $DRY_RUN_CMD mkdir -p $HOME/.config/ghostty
    $DRY_RUN_CMD mkdir -p $HOME/.config/mako
    $DRY_RUN_CMD mkdir -p $HOME/.config/fuzzel
    $DRY_RUN_CMD mkdir -p $HOME/.config/nvim-theme
    $DRY_RUN_CMD mkdir -p $HOME/.config/rofi

    # Only create symlinks if they don't exist (preserve user's current theme choice)
    if [[ ! -L $HOME/.config/waybar/colors.css ]]; then
      $DRY_RUN_CMD ln -sf $HOME/.config/waybar/themes/${defaultTheme}.css $HOME/.config/waybar/colors.css
    fi
    if [[ ! -L $HOME/.config/ghostty/theme ]]; then
      $DRY_RUN_CMD ln -sf $HOME/.config/ghostty/themes/${defaultTheme} $HOME/.config/ghostty/theme
    fi
    if [[ ! -L $HOME/.config/mako/config ]]; then
      $DRY_RUN_CMD ln -sf $HOME/.config/mako/themes/${defaultTheme}.conf $HOME/.config/mako/config
    fi
    if [[ ! -L $HOME/.config/fuzzel/fuzzel.ini ]]; then
      $DRY_RUN_CMD ln -sf $HOME/.config/fuzzel/themes/${defaultTheme}.ini $HOME/.config/fuzzel/fuzzel.ini
    fi
    if [[ ! -L $HOME/.config/nvim-theme/active.lua ]]; then
      $DRY_RUN_CMD ln -sf $HOME/.config/nvim-theme/${defaultTheme}.lua $HOME/.config/nvim-theme/active.lua
    fi
    if [[ ! -L $HOME/.config/rofi/wallpaper-picker.rasi ]]; then
      $DRY_RUN_CMD ln -sf $HOME/.config/rofi/themes/${defaultTheme}.rasi $HOME/.config/rofi/wallpaper-picker.rasi
    fi

    # Pre-render wallpaper thumbnails (300x200, center-cropped) for the
    # rofi carousel. Idempotent: regenerates only when source is newer.
    WALLPAPER_CONFIG=/home/kamdyns/nixos-config/wallpapers/config.json
    THUMBS_DIR=$HOME/.cache/rice/wallpaper-thumbs
    if [[ -f "$WALLPAPER_CONFIG" ]]; then
      $DRY_RUN_CMD mkdir -p "$THUMBS_DIR"
      while IFS=$'\t' read -r key src; do
        dst="$THUMBS_DIR/$key.png"
        if [[ -f "$src" ]] && [[ ! -f "$dst" || "$src" -nt "$dst" ]]; then
          $DRY_RUN_CMD ${pkgs.imagemagick}/bin/magick "$src" -resize 300x200^ -gravity center -extent 300x200 "$dst" 2>/dev/null || true
        fi
      done < <(${pkgs.jq}/bin/jq -r 'to_entries[] | "\(.key)\t\(.value.path)"' "$WALLPAPER_CONFIG")
    fi

    # Seed starship.toml as a writable regular file (theme-switch sed-edits it).
    # If it already exists, refresh contents but preserve the active palette.
    STARSHIP_SRC="${pkgs.writeText "starship-template.toml" starshipConfig}"
    STARSHIP_DST="$HOME/.config/starship.toml"
    CURRENT_PALETTE="${defaultTheme}"
    if [[ -f "$STARSHIP_DST" && ! -L "$STARSHIP_DST" ]]; then
      EXISTING=$(${pkgs.gnused}/bin/sed -n 's/^palette = "\(.*\)"/\1/p' "$STARSHIP_DST" | head -1)
      [[ -n "$EXISTING" ]] && CURRENT_PALETTE="$EXISTING"
    fi
    $DRY_RUN_CMD rm -f "$STARSHIP_DST"
    $DRY_RUN_CMD install -m 644 "$STARSHIP_SRC" "$STARSHIP_DST"
    $DRY_RUN_CMD ${pkgs.gnused}/bin/sed -i "s/^palette = .*/palette = \"$CURRENT_PALETTE\"/" "$STARSHIP_DST"

    # Seed spicetify config-xpui.ini as a writable file (spicetify-cli rewrites
    # it via `spicetify config`). Preserve active color_scheme on rebuild.
    $DRY_RUN_CMD mkdir -p $HOME/.config/spicetify
    SPICETIFY_CONFIG="$HOME/.config/spicetify/config-xpui.ini"
    SPICETIFY_SCHEME="${defaultTheme}"
    if [[ -f "$SPICETIFY_CONFIG" ]]; then
      EXISTING=$(${pkgs.gnused}/bin/sed -n 's/^color_scheme[[:space:]]*=[[:space:]]*\(.*\)/\1/p' "$SPICETIFY_CONFIG" | head -1)
      [[ -n "$EXISTING" ]] && SPICETIFY_SCHEME="$EXISTING"
    fi
    # Zen Browser: symlink default userChrome.css into the active profile.
    # Backs up any pre-existing userChrome.css (e.g., from Caelestia) once.
    shopt -s nullglob
    zen_profiles=("$HOME"/.zen/*.Default*/chrome)
    shopt -u nullglob
    if [[ ''${#zen_profiles[@]} -gt 0 ]]; then
      ZEN_USERCHROME="''${zen_profiles[0]}/userChrome.css"
      if [[ ! -L "$ZEN_USERCHROME" ]]; then
        if [[ -f "$ZEN_USERCHROME" && ! -f "$ZEN_USERCHROME.pre-rice" ]]; then
          $DRY_RUN_CMD cp "$ZEN_USERCHROME" "$ZEN_USERCHROME.pre-rice"
        fi
        $DRY_RUN_CMD rm -f "$ZEN_USERCHROME"
        $DRY_RUN_CMD ln -sf "$HOME/.config/zen-chrome/${defaultTheme}.css" "$ZEN_USERCHROME"
      fi
    fi

    $DRY_RUN_CMD rm -f "$SPICETIFY_CONFIG"
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/tee "$SPICETIFY_CONFIG" > /dev/null <<EOF
[Setting]
spotify_path           = $HOME/.local/share/flatpak/app/com.spotify.Client/current/active/files/extra/share/spotify
prefs_path             = $HOME/.var/app/com.spotify.Client/config/spotify/prefs
current_theme          = base16
color_scheme           = $SPICETIFY_SCHEME
spotify_launch_flags   =
check_spicetify_update = 0
inject_css             = 1
inject_theme_js        = 1
replace_colors         = 1
overwrite_assets       = 0

[Preprocesses]
disable_sentry         = 1
disable_ui_logging     = 1
remove_rtl_rule        = 1
expose_apis            = 1

[AdditionalOptions]
extensions             =
custom_apps            =
sidebar_config         = 1
home_config            = 1
experimental_features  = 0
EOF
  '';
}
