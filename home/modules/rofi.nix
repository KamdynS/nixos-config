{ config, lib, pkgs, ... }:

{
  # rofi (Wayland-capable since the rofi-wayland merge): used by wallpaper-pick
  # (themed via theming.nix → rofi/themes/*.rasi).
  # imagemagick: pre-renders 300x200 wallpaper thumbnails for the carousel.
  home.packages = with pkgs; [
    rofi
    imagemagick
  ];
}
