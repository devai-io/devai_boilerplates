{
  description = "NixOS desktop with KDE Plasma 6";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }@inputs: {
    nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/desktop/configuration.nix

        home-manager.nixosModules.home-manager
        {
          # Reuse the system's pkgs for home-manager instead of instantiating
          # a second nixpkgs (faster eval, one config).
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "bkp";
          home-manager.users.user = ./home/user.nix;
        }
      ];
    };
  };
}
