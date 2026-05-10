{ config, lib, pkgs, ... }:

let
  # Flatpak Spotify install path (user install).
  # Spicetify needs a writable Spotify; /nix/store is read-only, so we use
  # the Flatpak install instead of pkgs.spotify.
  flatpakSpotifyDir =
    "${config.home.homeDirectory}/.local/share/flatpak/app/com.spotify.Client/current/active/files/extra/share/spotify";

  # `spotify` launcher used by niri (Mod+S) and any .desktop consumers.
  # Wraps `flatpak run` so the existing keybind keeps working.
  spotifyLauncher = pkgs.writeShellScriptBin "spotify" ''
    exec ${pkgs.flatpak}/bin/flatpak run com.spotify.Client "$@"
  '';
in
{
  home.packages = [
    pkgs.spicetify-cli
    spotifyLauncher
  ];

  # First-run bootstrap: if the Flatpak install exists and spicetify hasn't
  # backed up Spotify yet, run a one-time `backup apply` so subsequent
  # `spicetify apply` calls (from theme-switch) work. Safe to re-run.
  home.activation.spicetifyBootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    SPOTIFY_DIR="${flatpakSpotifyDir}"
    BACKUP_MARKER="$HOME/.cache/spicetify/Backup/xpui.bak"

    if [[ -d "$SPOTIFY_DIR" && ! -f "$BACKUP_MARKER" ]]; then
      echo "Spicetify: first-run backup+apply against Flatpak Spotify"
      $DRY_RUN_CMD ${pkgs.spicetify-cli}/bin/spicetify backup apply --no-restart || true
    fi
  '';
}
