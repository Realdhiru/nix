{
  description = "realdhiru's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      specialArgs = {
        inherit inputs;
      };

      modules = [
        ({ pkgs, ... }: {
          nixpkgs.overlays = [
            (final: prev: {
              buuf-nestort-icon-theme =
                prev.callPackage ./pkgs/buuf-nestort.nix { };

              hyprexpo-plugin =
                prev.callPackage ./pkgs/hyprexpo-plugin.nix { };
            })
          ];
        })

        ./hosts/nixos/default.nix

        home-manager.nixosModules.home-manager

        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;

          home-manager.extraSpecialArgs = {
            inherit inputs;
          };

          home-manager.sharedModules = [
            inputs.spicetify-nix.homeManagerModules.spicetify
          ];

          home-manager.users.realdhiru = import ./home.nix;
        }
      ];
    };
  };
}