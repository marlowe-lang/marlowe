{
  description = "The Marlowe Language";

  inputs = {
    # isabelle-nixpkgs.url = "nixpkgs/nixos-23.11";

    haskell-nix = {
      url = "github:input-output-hk/haskell.nix?ref=2025.12.21";
      # inputs.hackage.follows = "hackage";
    };

    nixpkgs.follows = "haskell-nix/nixpkgs";

    CHaP = {
      url = "github:IntersectMBO/cardano-haskell-packages?ref=repo";
      flake = false;
    };

    flake-utils.url = "github:numtide/flake-utils";

    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
  };

  outputs = inputs: inputs.flake-utils.lib.eachDefaultSystem (system:
    let
      repoRoot = ./.;
      pkgs =
        import inputs.nixpkgs {
          inherit system;
          config = inputs.haskell-nix.config;
          overlays = [
            inputs.haskell-nix.overlay
          ];
        };
      inherit (pkgs) lib;

      project = pkgs.haskell-nix.cabalProject' (
        { config, pkgs, ... }:
        {
          name = "marlowe";
          compiler-nix-name = lib.mkDefault "ghc984";
          src = lib.cleanSource ./.;
          inputMap = { "https://chap.intersectmbo.org/" = inputs.CHaP; };
          modules = [{
            packages = {};
          }];
        }
      );


      packages = { };

      devShells = {
        default = import ./nix/shell.nix {
          inherit inputs pkgs lib project system repoRoot;
        };
      };

      projectFlake = project.flake {};
    in {
      inherit packages;
      inherit devShells;
    }
  );

  nixConfig = {
    extra-substituters = [
      "https://cache.iog.io"
      "https://cache.zw3rk.com"
    ];
    extra-trusted-public-keys = [
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      "loony-tools:pr9m4BkM/5/eSTZlkQyRt57Jz7OMBxNSUiMC4FkcNfk="
    ];
    allow-import-from-derivation = true;
    accept-flake-config = true;
  };
}



