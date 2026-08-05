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

  outputs = inputs@{ nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      inherit system;

      specialArgs = {
        inherit inputs;
      };

      modules = [
        ({ pkgs, ... }: {
          nixpkgs.overlays = [
            (final: prev: {
              buuf-nestort-icon-theme =
                prev.callPackage ./pkgs/buuf-nestort.nix { };
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

    checks.${system}.qml-lint = pkgs.runCommandLocal "qml-lint" { } ''
      QT_QML=${pkgs.qt6.qtdeclarative}/lib/qt-6/qml
      QS_QML=${pkgs.quickshell}/lib/qt-6/qml
      QMLLINT=${pkgs.qt6.qtdeclarative}/bin/qmllint
      cp -r ${./dotfiles/hypr/scripts/quickshell} src
      fail=0
      while IFS= read -r f; do
        echo "qmllint: ''${f#src/}"
        if lintout=$("$QMLLINT" -I "$QT_QML" -I "$QS_QML" "$f" 2>&1); then
          if printf '%s\n' "$lintout" | grep -q "unknown attached property scope"; then
            echo "FAIL: unresolved attached property in ''${f#src/}:"
            printf '%s\n' "$lintout" | grep "unknown attached property scope"
            fail=1
          fi
        else
          echo "FAIL: qmllint exited non-zero on ''${f#src/}:"
          printf '%s\n' "$lintout" | tail -20
          fail=1
        fi
      done < <(find src -name '*.qml' -type f | sort)
      mkdir -p "$out"
      exit "$fail"
    '';
  };
}