{ config, lib, pkgs, ... }:

{
  # rofi-wayland: used by wallpaper-pick (themed via theming.nix → rofi/themes/*.rasi).
  # imagemagick: pre-renders 300x200 wallpaper thumbnails for the carousel.
  home.packages = with pkgs; [
    rofi-wayland
    imagemagick
  ];
}
