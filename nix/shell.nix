{ project, repoRoot, inputs, pkgs, lib, system, ghcVersion ? "ghc984" }:
  let
    name = "marlowe";
    welcomeMessage = ''
      Welcome to Marlowe!

      Tests:
        • run-isabelle-test
        • cabal test all

      Scripts:
        • build-marlowe-proofs
        • edit-marlowe-proofs
        • build-marlowe-docs
        • generate-marlowe-language-specification

      Tools:
        • bnfc
        • isabelle
        • latex
        • lhs2tex
        • nettools
        • nil
        • perl
    '';

    lhs2tex = (pkgs.haskell-nix.hackage-package {
      compiler-nix-name = ghcVersion;
      name = "lhs2tex";
      version = "latest";
    });
    BNFC = (pkgs.haskell-nix.hackage-package {
      compiler-nix-name = ghcVersion;
      name = "BNFC";
      version = "latest";
    });

    # This could be probably moved to `shellFor { tools = { cabal = "latest",.. }}` but
    # then the hooks setup should be modified as well. Not sure how to do that cleanly.
    tools = {
      cabal = (project.tool "cabal" "latest");
      cabal-fmt = (project.tool "cabal-fmt" "latest");
      haskell-language-server = (project.tool "haskell-language-server" "latest");
      stylish-haskell = (project.tool "stylish-haskell" "latest");
      fourmolu = (project.tool "fourmolu" "latest");
      hlint = (project.tool "hlint" "latest");
      lhs2tex = lhs2tex.components.exes.lhs2TeX;
      BNFC = BNFC.components.exes.bnfc;
    };

    preCommitCheck = inputs.pre-commit-hooks.lib.${pkgs.system}.run {
      src = lib.cleanSources ../.;

      hooks = {
        nixpkgs-fmt = {
          enable = false;
          package = pkgs.nixpkgs-fmt;
        };
        cabal-fmt = {
          enable = false;
          package = tools.cabal-fmt;
        };
        stylish-haskell = {
          enable = false;
          package = tools.stylish-haskell;
          args = [ "--config" ".stylish-haskell.yaml" ];
        };
        fourmolu = {
          enable = false;
          package = tools.fourmolu;
        };
        hlint = {
          enable = false;
          package = tools.hlint;
          args = [ "--hint" ".hlint.yaml" ];
        };
        shellcheck = {
          enable = false;
          package = pkgs.shellcheck;
        };
      };
    };

    isabelle = import ./isabelle.nix {
      inherit repoRoot inputs pkgs lib system;
    };

    scripts = import ./scripts.nix {
      inherit repoRoot inputs pkgs lib system;
    };

    shell = project.shellFor {
      buildInputs = [
        isabelle.isabelle
        isabelle.latex-environment
        isabelle.perl
        isabelle.nettools

        scripts.run-isabelle-test
        scripts.build-marlowe-proofs
        scripts.edit-marlowe-proofs
        scripts.build-marlowe-docs
        scripts.generate-marlowe-language-specification

        tools.haskell-language-server
        tools.haskell-language-server.package.components.exes.haskell-language-server-wrapper
        tools.stylish-haskell
        tools.fourmolu
        tools.cabal
        tools.hlint
        tools.cabal-fmt
        tools.lhs2tex
        tools.BNFC

        pkgs.nil
        pkgs.tk
      ];


      shellHook = ''
        ${preCommitCheck.shellHook}
      '';

      withHoogle = false;
    };
  in
    shell

