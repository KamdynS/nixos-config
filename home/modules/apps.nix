{ config, lib, pkgs, inputs, ... }:

{
  home.packages = with pkgs; [
    # Browser - Zen (Firefox-based)
    # DRM note: Zen doesn't support DRM. Use Spotify desktop app for music.
    # First launch: import bookmarks/passwords from Chrome via Zen's import wizard
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default

    # Music: Spotify installed via Flatpak (see modules/spicetify.nix)

    # Chat (Vesktop = Vencord + Discord, better Wayland support)
    vesktop

    # Screenshots
    grim
    slurp
  ];
}
