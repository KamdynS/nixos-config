{
description = "NixOS config for LG Gram";

inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  home-manager = {
	url = "github:nix-community/home-manager";
	inputs.nixpkgs.follows = "nixpkgs";
	};

  niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
};

outputs = { self, nixpkgs, home-manager, niri, zen-browser, ... }@inputs:
	let
		system = "x86_64-linux";
	in
	{
		nixosConfigurations.lg-gram = nixpkgs.lib.nixosSystem {
			inherit system;
			specialArgs = { inherit inputs; };
			modules = [
        {
          nixpkgs.overlays = [ niri.overlays.niri ];
        }

				./hosts/lg-gram/configuration.nix

        niri.nixosModules.niri

				home-manager.nixosModules.home-manager
				{
					home-manager.useGlobalPkgs = true;
					home-manager.useUserPackages = true;
					home-manager.users.kamdyns = import ./home/home.nix;
          home-manager.extraSpecialArgs = { inherit inputs; };
				}
			];
		};
	};
}
