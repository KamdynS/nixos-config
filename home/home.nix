{ config, pkgs, inputs, ... }:

{
  imports = [
    ./niri.nix
    ./waybar.nix
    ./wofi.nix
    ./quickshell.nix
  ];

	home.username = "kamdyns";
	home.homeDirectory = "/home/kamdyns";
	home.stateVersion = "24.05";

  # Session variables for Wayland/GTK apps
  home.sessionVariables = {
    # Tell Firefox to not draw its own titlebar (allows niri borders to show)
    MOZ_GTK_TITLEBAR_DECORATION = "none";
  };

	programs.home-manager.enable = true;

  fonts.fontconfig.enable = true;

  programs.wofi = {
    enable = true;
  };

  programs.waybar = {
      enable = true;
  };

  programs.ssh = {
    enable = true;  # This installs openssh and creates ~/.ssh/config
    addKeysToAgent = "yes";
    matchBlocks = {
      "github.com" = {
        host = "github.com";
        user = "git";
        identityFile = "~/.ssh/github";
      };
    };
  };

  services.ssh-agent.enable = true;
	
  # Neovim 
	programs.neovim = {
		enable = true;
		defaultEditor = true;
		vimAlias = true;
		viAlias = true;
	};

  # ghostty
  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      font-family = "JetBrains Mono";
      font-size = 14;
      theme = "Gruvbox Light";
      window-padding-x = 8;
      window-padding-y = 8;
    };
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    
    history = {
      size = 10000;
      path = "${config.xdg.dataHome}/zsh/history";
    };

    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];

    initContent = ''
      # Powerlevel10k instant prompt
      if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
        source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
      fi
      
      # Load p10k config
      [[ -f /home/kamdyns/nixos-config/dotfiles/zsh/p10k.zsh ]] && source /home/kamdyns/nixos-config/dotfiles/zsh/p10k.zsh
    '';
  };

	# Neovim dotfiles
	xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink "/home/kamdyns/nixos-config/dotfiles/nvim";

  # Niri keybinding help script
  xdg.configFile."niri/keybinds-help.sh" = {
    executable = true;
    text = ''
      #!/bin/bash
      yad --title="Niri Keybindings" \
          --text-info \
          --width=500 \
          --height=600 \
          --fontname="JetBrains Mono 11" \
          --button="Close:0" \
          --center \
          <<EOF
      ═══════════════════════════════════════
               NIRI KEYBINDINGS
      ═══════════════════════════════════════

      GENERAL
        Mod+Return        Terminal (Ghostty)
        Mod+D             App Launcher (Wofi)
        Mod+Q             Close Window
        Mod+Shift+E       Exit Niri
        Mod+X             Power Menu
        Mod+Shift+?       This Help

      WINDOWS
        Mod+F             Maximize
        Mod+Shift+F       Fullscreen
        Mod+H/J/K/L       Focus Left/Down/Up/Right
        Mod+Shift+H/J/K/L Move Window

      WORKSPACES
        Mod+1-9           Go to Workspace
        Mod+Shift+1-9     Move Window to Workspace
        Mod+Scroll        Scroll Workspaces

      SCREENSHOTS
        Print             Screenshot (save)
        Alt+Print         Window Screenshot (save)
        Ctrl+Print        Region to Clipboard
        Ctrl+Alt+Print    Screen to Clipboard

      OTHER
        Mod+Shift+P       Power Off Monitors
      EOF
    '';
  };

	# Dev tools needed in PATH
	home.packages = with pkgs; [
		# language toolchains
		go
		rustup

		# LSPs
		gopls
		pyright

		# Formatters
		stylua
		prettierd
		sqlfluff
		
		# CLI tools
		ripgrep
		fd
		git
		lazygit
		gcc
		gnumake
		unzip
    tree
    claude-code

    # Fun stuff
    neofetch

    # Important for da 'puter
    networkmanagerapplet
    pavucontrol

    # File manager
    xfce.thunar

    # Clipboard support
    wl-clipboard

    # Screenshots
    grim
    slurp

    # Screen locker
    swaylock

    # Keybinding help
    yad

    ] ++ [
    # Zen browser
    inputs.zen-browser.packages.${pkgs.system}.default
    ] ++ [
    pkgs.nerd-fonts.jetbrains-mono
		pkgs.typescript-language-server
		pkgs.clang-tools
		pkgs.nodePackages.vscode-langservers-extracted
	];
}
