# Paketler
## Hyprland
  - wl-clipboard  # Wayland kullanirken terminalde copy-paste yapabilmek icin. orn: `ls -al | wl-copy`
  - hyprland
  - sddm
  - uwsm
  - wireplumber # ses kontrolleri icin
  - swaync # notification
  - wlsunset # wayland geoloc tabanli mavi isik filtresi
  - hyprpolkitagent
    - `systemctl --user enable --now hyprpolkitagent.service`
  - hyperidle
    - `systemctl --user enable --now hyperidle.service`
  - kdeconnect # malum
  - NetworkManager
  - qt5-wayland
  - qt6-wayland
  - waybar
    - `cp /etc/xdg/waybar/* ~/.config/waybar`
    - `systemctl --user enable --now waybar.service`
  - hyprpaper # wallpaperhyprl
    - `systemctl --user enable --now hyprpaper.service`
  - hyprlock
    - `cp /usr/share/hypr/hyprlock.conf ~/.config/hypr`
  - pyperland
  - hyprland-per-window-layout # keyboard layout
  - bibata-cursor-theme-bin


## Key Bindings
  - walker `SUPER+SPACE`
