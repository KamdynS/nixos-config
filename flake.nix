{
description = "NixOS config for LG Gram";

inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  home-manager = {
	url = "github:nix-community/home-manager";
	inputs.nixpkgs.follows = "nixpkgs";
	};
};

outputs = { self, nixpkgs, home-manager, ... }@inputs:
	let
		system = "x86_64-linux";
	in
	{
		nixosConfigurations.lg-gram = nixpkgs.lib.nixosSystem {
			inherit system;
			specialArgs = { inherit inputs; };
			modules = [
				./hosts/lg-gram/configuration.nix
				home-manager.nixosModules.home-manager
				{
					home-manager.useGlobalPkgs = true;
					home-manager.useUserPackages = true;
					home-manager.users.kamdyns = import ./home/home.nix;
				}
			];
		};
	};
}
