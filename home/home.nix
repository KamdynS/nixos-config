{ config, pkgs, ... }:

{
	home.username = "kamdyns";
	home.homeDirectory = "/home/kamdyns";
	home.stateVersion = "24.05";

	programs.home-manager.enable = true;

  fonts.fontconfig.enable = true;

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

	# Neovim dotfiles
	xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink "/home/kamdyns/nixos-config/dotfiles/nvim";

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

		] ++ [
    pkgs.nerd-fonts.jetbrains-mono
		pkgs.typescript-language-server
		pkgs.clang-tools
		pkgs.nodePackages.vscode-langservers-extracted
	];
}
