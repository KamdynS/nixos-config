{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    cliphist
    wl-clipboard
  ];

  # cliphist is started by niri spawn-at-startup:
  # wl-paste --watch cliphist store
}
