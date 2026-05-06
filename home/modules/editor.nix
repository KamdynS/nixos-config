{ config, lib, pkgs, ... }:

{
  # Use neovim as package, not programs.neovim (avoids home-manager managing ~/.config/nvim)
  home.sessionVariables.EDITOR = "nvim";

  # nvim config symlinked via activation script (avoids home-manager conflicts)
  # Theme files go to ~/.config/nvim-theme/
  home.activation.linkNvimConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [[ ! -L $HOME/.config/nvim ]]; then
      $DRY_RUN_CMD rm -rf $HOME/.config/nvim 2>/dev/null || true
      $DRY_RUN_CMD ln -sf /home/kamdyns/nixos-config/dotfiles/nvim $HOME/.config/nvim
    fi
  '';

  # LSPs and dev tools
  home.packages = with pkgs; [
    # Editor
    neovim

    # Language toolchains
    go
    cargo
    rustc
    rustfmt
    clippy

    # LSPs
    gopls
    pyright
    rust-analyzer
    typescript-language-server
    vscode-langservers-extracted
    clang-tools
    lua-language-server
    nil  # Nix LSP

    # Formatters
    stylua
    prettierd
    nixfmt
    black

    # CLI tools for nvim
    ripgrep
    fd
    gcc
    gnumake
    unzip
    tree
  ];
}
