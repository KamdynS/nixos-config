{ lib
, rustPlatform
, pkg-config
, dbus
}:

rustPlatform.buildRustPackage rec {
  pname = "niri-shell-ipc";
  version = "0.1.0";

  src = ./.;

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    dbus
  ];

  meta = with lib; {
    description = "DBus daemon for niri IPC integration with Quickshell";
    homepage = "https://github.com/kamdyns/nixos-config";
    license = licenses.mit;
    maintainers = [];
    mainProgram = "niri-shell-ipc";
  };
}
