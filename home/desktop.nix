{
  config,
  pkgs,
  inputs,
  nix-colors,
  ...
}:

{
  imports = [
    ./modules/theming.nix
    ./modules/niri.nix
    ./modules/waybar.nix
    ./modules/fuzzel.nix
    ./modules/rofi.nix
    ./modules/mako.nix
    ./modules/cliphist.nix
    ./modules/swww.nix
    ./modules/ghostty.nix
    ./modules/apps.nix
    ./modules/spicetify.nix
    ./modules/shell.nix
    ./modules/editor.nix
  ];

  home.username = "kamdyns";
  home.homeDirectory = "/home/kamdyns";
  home.stateVersion = "24.05";

  programs.home-manager.enable = true;

  # Session variables for Wayland/GTK apps
  home.sessionVariables = {
    MOZ_GTK_TITLEBAR_DECORATION = "none";
    # Fcitx5 input method (Japanese)
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
  };

  # Japanese input method
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-mozc
      fcitx5-gtk
    ];
  };

  # Fonts
  fonts.fontconfig.enable = true;

  # Git (using new 26.05 option names)
  programs.git = {
    enable = true;
    settings = {
      user.name = "Kamdyn Shaeffer";
      user.email = "kamdynshaefferbusiness@gmail.com";
      url."git@github.com:".insteadOf = "https://github.com/";
    };
  };

  # Lazygit
  programs.lazygit.enable = true;

  # SSH
  programs.ssh = {
    enable = true;
    matchBlocks = {
      "*" = {
        addKeysToAgent = "yes";
      };
      "github.com" = {
        host = "github.com";
        user = "git";
        identityFile = "~/.ssh/id_ed25519";
      };
    };
  };
  services.ssh-agent.enable = true;

  # Packages
  home.packages = with pkgs; [
    # Fonts
    nerd-fonts.jetbrains-mono

    # System utilities
    networkmanagerapplet
    pavucontrol
    thunar
    htop
    fastfetch

    # CLI tools
    git
    gh
    jq
    curl
    wget

    # Claude Code
    claude-code
    inputs.codex.packages.${pkgs.system}.default
  ];

  # Create Pictures/Screenshots directory
  home.file."Pictures/Screenshots/.keep".text = "";
}
