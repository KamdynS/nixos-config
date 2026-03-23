# Cross-Platform Nix Setup (NixOS + macOS)

This document outlines how to set up a unified Nix configuration that works across NixOS (home machines) and macOS (work laptop) while keeping work-specific and secret configurations separate.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│  Your public dotfiles (github.com/kamdyns/nixos-config) │
│  - Shared across all your machines                      │
│  - Safe to publish                                      │
└─────────────────────┬───────────────────────────────────┘
                      │ imports (on work Mac only)
                      ▼
┌─────────────────────────────────────────────────────────┐
│  Company work flake (github.com/company/nix-work-tools) │
│  - Private repo, coworkers can pull                     │
│  - Work CLIs, k8s configs, shared tooling               │
└─────────────────────┬───────────────────────────────────┘
                      │ imports (on your work Mac only)
                      ▼
┌─────────────────────────────────────────────────────────┐
│  Local secrets (~/.config/nix-local/secrets.nix)        │
│  - Never in any git repo                                │
│  - Your SSH keys, personal tokens                       │
└─────────────────────────────────────────────────────────┘
```

## Directory Structure

```
nixos-config/
├── flake.nix
├── home/
│   ├── home.nix              # shared home-manager config
│   ├── niri.nix              # NixOS-only (Wayland compositor)
│   ├── waybar.nix
│   └── ...
├── hosts/
│   ├── lg-gram/              # NixOS laptop
│   │   ├── configuration.nix
│   │   └── hardware-configuration.nix
│   ├── desktop/              # NixOS desktop
│   │   ├── configuration.nix
│   │   └── hardware-configuration.nix
│   └── work-macbook/         # macOS work laptop
│       └── darwin.nix
├── docs/
└── dotfiles/
    ├── nvim/
    └── ...
```

## Flake Configuration

```nix
# flake.nix
{
  description = "Cross-platform Nix config for NixOS and macOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Niri (NixOS only)
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Work flake - only fetched on machines with SSH access to this repo
    # Comment out or remove on home machines if it causes issues
    work-tools = {
      url = "git+ssh://git@github.com/your-company/nix-work-tools";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nix-darwin, niri, work-tools, ... }@inputs:
    let
      # Shared home-manager config that works on both OSes
      sharedHomeConfig = { pkgs, config, ... }: {
        imports = [ ./home/home-shared.nix ];
      };
    in
    {
      # ══════════════════════════════════════════════════════════
      # NixOS Configurations (Home machines)
      # ══════════════════════════════════════════════════════════

      nixosConfigurations.lg-gram = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.overlays = [ niri.overlays.niri ]; }
          ./hosts/lg-gram/configuration.nix
          niri.nixosModules.niri
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.kamdyns = import ./home/home.nix;
            home-manager.extraSpecialArgs = { inherit inputs; };
          }
        ];
      };

      nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.overlays = [ niri.overlays.niri ]; }
          ./hosts/desktop/configuration.nix
          niri.nixosModules.niri
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.kamdyns = import ./home/home.nix;
            home-manager.extraSpecialArgs = { inherit inputs; };
          }
        ];
      };

      # ══════════════════════════════════════════════════════════
      # macOS Configuration (Work laptop)
      # ══════════════════════════════════════════════════════════

      darwinConfigurations.work-macbook = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";  # Apple Silicon; use "x86_64-darwin" for Intel
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/work-macbook/darwin.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.kamdyns = { config, pkgs, ... }: {
              imports = [
                ./home/home-macos.nix                  # macOS-specific home config
                work-tools.homeManagerModules.default  # company shared tools
              ] ++ (
                # Local secrets - only exists on this physical machine
                if builtins.pathExists /Users/kamdyns/.config/nix-local/secrets.nix
                then [ /Users/kamdyns/.config/nix-local/secrets.nix ]
                else []
              );
            };
            home-manager.extraSpecialArgs = { inherit inputs; };
          }
        ];
      };
    };
}
```

## Home Manager Split

### Shared Config (home-shared.nix)

Config that works identically on both OSes:

```nix
# home/home-shared.nix
{ config, pkgs, ... }:
{
  home.stateVersion = "24.05";
  programs.home-manager.enable = true;

  # Git (works everywhere)
  programs.git = {
    enable = true;
    userName = "Kamdyn Shaeffer";
    userEmail = "kamdynshaefferbusiness@gmail.com";
  };

  # Neovim (symlinked dotfiles work everywhere)
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
  };

  # Zsh with Oh My Zsh
  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "docker" ];
    };
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
  };

  # Cross-platform packages
  home.packages = with pkgs; [
    ripgrep
    fd
    jq
    tree
  ];
}
```

### NixOS-specific (home.nix)

```nix
# home/home.nix (NixOS)
{ config, pkgs, inputs, ... }:
{
  imports = [
    ./home-shared.nix
    ./niri.nix      # Wayland compositor config
    ./waybar.nix
    ./wofi.nix
  ];

  home.username = "kamdyns";
  home.homeDirectory = "/home/kamdyns";

  # Linux-specific packages
  home.packages = with pkgs; [
    wl-clipboard
    grim
    slurp
  ];
}
```

### macOS-specific (home-macos.nix)

```nix
# home/home-macos.nix
{ config, pkgs, ... }:
{
  imports = [
    ./home-shared.nix
  ];

  home.username = "kamdyns";
  home.homeDirectory = "/Users/kamdyns";

  # macOS-specific packages
  home.packages = with pkgs; [
    coreutils  # GNU coreutils on Mac
  ];

  # Homebrew paths (if still using some Homebrew packages)
  home.sessionPath = [
    "/opt/homebrew/bin"
  ];
}
```

## Company Work Flake

Shared with coworkers, contains non-secret work tooling:

```nix
# github.com/your-company/nix-work-tools/flake.nix
{
  description = "Company shared Nix tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }: {
    homeManagerModules.default = { pkgs, ... }: {
      home.packages = with pkgs; [
        kubectl
        kubernetes-helm
        vault
        terraform
        awscli2
        google-cloud-sdk
        # Add company-specific CLIs here
      ];

      # Shared work git config (non-secret)
      programs.git.extraConfig = {
        # Company git settings
      };

      # Shared shell aliases for work
      programs.zsh.shellAliases = {
        k = "kubectl";
        tf = "terraform";
        # etc
      };
    };
  };
}
```

## Local Secrets File

Create this file manually on your work laptop. **Never commit to git.**

```nix
# ~/.config/nix-local/secrets.nix (NEVER IN GIT)
{ config, ... }:
{
  # Work SSH configuration
  programs.ssh = {
    enable = true;
    matchBlocks = {
      # Work GitHub (if using separate key)
      "github.com" = {
        host = "github.com";
        user = "git";
        identityFile = "~/.ssh/work_ed25519";
      };

      # Internal servers
      "*.internal.company.com" = {
        user = "kshaeffer";
        identityFile = "~/.ssh/work_ed25519";
        proxyJump = "bastion.company.com";
      };

      # Bastion/jump host
      "bastion.company.com" = {
        user = "kshaeffer";
        identityFile = "~/.ssh/work_ed25519";
      };
    };
  };

  # Work-specific environment variables
  home.sessionVariables = {
    VAULT_ADDR = "https://vault.internal.company.com";
    AWS_PROFILE = "company-dev";
    # Other secrets/tokens loaded from elsewhere
  };

  # Any other personal-to-this-machine config
}
```

## Commands Reference

### NixOS (home machines)

```bash
# Rebuild system
sudo nixos-rebuild switch --flake /home/kamdyns/nixos-config#lg-gram
sudo nixos-rebuild switch --flake /home/kamdyns/nixos-config#desktop

# Test without switching
sudo nixos-rebuild test --flake /home/kamdyns/nixos-config#lg-gram
```

### macOS (work laptop)

```bash
# First time setup (install nix-darwin)
nix run nix-darwin -- switch --flake ~/nixos-config#work-macbook

# Subsequent rebuilds
darwin-rebuild switch --flake ~/nixos-config#work-macbook
```

### Update all inputs

```bash
nix flake update --flake /path/to/nixos-config
# Then rebuild on each machine
```

## Workflow

1. **Make changes** to shared config on any machine
2. **Commit and push** to git
3. **Pull on other machine** and rebuild
4. Both machines now have the same config (minus OS-specific and secret parts)

## Notes

- The `work-tools` input will fail to fetch on machines without SSH access to the company repo. You may need to conditionally include it or comment it out for home machines.
- The local secrets file path is absolute (`/Users/kamdyns/...`) so it only resolves on the work Mac.
- Keep the company flake focused on tools/config that all team members need. Personal preferences go in your public dotfiles.
