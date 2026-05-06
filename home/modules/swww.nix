{ config, lib, pkgs, ... }:

{
  # awww (formerly swww) - animated wallpaper daemon
  # Note: package renamed but binaries still called swww/swww-daemon
  home.packages = [ pkgs.awww ];

  # swww-daemon is started by niri spawn-at-startup
  # Wallpaper is set by theme-switch script
}
