{ config, lib, pkgs, ... }:

{
  # Use neovim as package, not programs.neovim (avoids home-manager managing ~/.config/nvim)
  home.sessionVariables.EDITOR = "nvim";

  # nvim config symlinked via activation script (avoids home-manager conflicts)
  # Theme files go to ~/.config/nvim-theme/
  home.activation.linkNvimConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    NVIM_CONFIG="$HOME/.config/nvim"
    NVIM_SOURCE="/home/kamdyns/nixos-config/dotfiles/nvim"
    if [[ -L "$NVIM_CONFIG" || ! -e "$NVIM_CONFIG" ]]; then
      $DRY_RUN_CMD ln -sfnT "$NVIM_SOURCE" "$NVIM_CONFIG"
    else
      echo "Not replacing existing non-symlink Neovim config: $NVIM_CONFIG" >&2
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

    # On-demand Cargo utilities
    cargo-expand
    cargo-machete
    cargo-deny
    # Upstream's test suite fails inside the nix build sandbox (llvm-profdata
    # merge step); skip checks, the binary itself works fine.
    (cargo-llvm-cov.overrideAttrs (_: { doCheck = false; }))

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

    # Required by nvim-treesitter main branch (compiles parsers from source)
    tree-sitter
    nodejs  # some grammars use node-gyp during install
  ];
}
