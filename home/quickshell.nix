{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    quickshell
    brightnessctl  # For brightness control
    playerctl      # For media controls (MPRIS)
  ];

  # Quickshell config files
  xdg.configFile = {
    "quickshell/shell.qml".source = ./qml/shell.qml;
    "quickshell/Bar.qml".source = ./qml/Bar.qml;
    "quickshell/ControlCenter.qml".source = ./qml/ControlCenter.qml;
    "quickshell/components/VolumeSlider.qml".source = ./qml/components/VolumeSlider.qml;
    "quickshell/components/BrightnessSlider.qml".source = ./qml/components/BrightnessSlider.qml;
    "quickshell/components/WifiPanel.qml".source = ./qml/components/WifiPanel.qml;
    "quickshell/components/QuickToggle.qml".source = ./qml/components/QuickToggle.qml;
    "quickshell/theme/Gruvbox.qml".source = ./qml/theme/Gruvbox.qml;
    "quickshell/theme/qmldir".source = ./qml/theme/qmldir;
  };
}
