{ config, lib, pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      # Navigation
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      "....." = "cd ../../../..";

      # Git shortcuts
      "gs" = "git status";
      "ga" = "git add";
      "gc" = "git commit";
      "gp" = "git push";
      "gl" = "git pull";
      "gd" = "git diff";
      "gco" = "git checkout";
      "gb" = "git branch";
      "glog" = "git log --oneline --graph";

      # Common commands
      "ls" = "ls --color=auto";
      "ll" = "ls -la";
      "la" = "ls -a";

      # NixOS
      "nrs" = "sudo nixos-rebuild switch --flake /home/kamdyns/nixos-config#desktop";
      "nrt" = "sudo nixos-rebuild test --flake /home/kamdyns/nixos-config#desktop";
      "hms" = "home-manager switch --flake /home/kamdyns/nixos-config#kamdyns";
    };

    history = {
      size = 10000;
      path = "${config.xdg.dataHome}/zsh/history";
    };

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "docker"
      ];
    };

    initContent = ''
      # Zoxide initialization (replaces cd with z)
      eval "$(${pkgs.zoxide}/bin/zoxide init zsh)"

      # FZF integration
      source <(${pkgs.fzf}/bin/fzf --zsh)

      # Work-related paths (if needed)
      export PATH="$HOME/.local/bin:$PATH"
      export PATH="$HOME/go/bin:$PATH"
    '';
  };

  # Starship prompt (configured in theming.nix)
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  # Required packages
  home.packages = with pkgs; [
    zoxide
    fzf
  ];
}
