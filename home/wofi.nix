{ config, pkgs, ... }:

{
  programs.wofi = {
    enable = true;
    
    settings = {
      width = 500;
      height = 400;
      location = "center";
      show = "drun";
      prompt = "Search...";
      filter_rate = 100;
      allow_markup = true;
      no_actions = true;
      halign = "fill";
      orientation = "vertical";
      content_halign = "fill";
      insensitive = true;
      allow_images = true;
      image_size = 24;
      gtk_dark = true;
    };
    
    style = ''
      window {
        margin: 0px;
        border: 2px solid #d79921;
        border-radius: 8px;
        background-color: #282828;
      }
      
      #input {
        margin: 12px;
        padding: 12px;
        border: none;
        border-radius: 4px;
        background-color: #3c3836;
        color: #ebdbb2;
        font-family: "JetBrainsMono Nerd Font";
        font-size: 14px;
      }
      
      #input:focus {
        outline: none;
      }
      
      #inner-box {
        margin: 0px 12px 12px 12px;
        background-color: transparent;
      }
      
      #outer-box {
        margin: 0px;
        background-color: transparent;
      }
      
      #scroll {
        margin: 0px;
        background-color: transparent;
      }
      
      #entry {
        padding: 8px 12px;
        margin: 0px;
        border-radius: 4px;
        background-color: transparent;
      }
      
      #entry:selected {
        background-color: #3c3836;
        outline: none;
      }
      
      #entry > * {
        margin: 0px 8px;
      }
      
      #text {
        color: #ebdbb2;
        font-family: "JetBrainsMono Nerd Font";
        font-size: 14px;
      }
      
      #text:selected {
        color: #fabd2f;
      }
    '';
  };
  
  # Power menu script
  home.file.".config/wofi/power-menu.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      
      entries="󰍃 Logout\n󰒲 Suspend\n󰜉 Reboot\n󰐥 Shutdown\n󰌾 Lock"
      
      selected=$(echo -e "$entries" | wofi --dmenu --prompt "Power Menu" --width 300 --height 250)
      
      case $selected in
        "󰍃 Logout")
          niri msg action quit --skip-confirmation
          ;;
        "󰒲 Suspend")
          # You said no suspend, but here if you change your mind
          systemctl suspend
          ;;
        "󰜉 Reboot")
          systemctl reboot
          ;;
        "󰐥 Shutdown")
          systemctl poweroff
          ;;
        "󰌾 Lock")
          swaylock
          ;;
      esac
    '';
  };
}
