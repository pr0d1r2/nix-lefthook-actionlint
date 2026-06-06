{
  description = "Lefthook-compatible actionlint check";

  nixConfig = {
    extra-substituters = [ "https://pr0d1r2.cachix.org" ];
    extra-trusted-public-keys = [ "pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nix-dev-shell-agentic = {
      url = "github:pr0d1r2/nix-dev-shell-agentic";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-lefthook-nix-flake-eval-src = {
      url = "github:pr0d1r2/nix-lefthook-nix-flake-eval";
      flake = false;
    };
    nix-lefthook-linter-coverage-src = {
      url = "github:pr0d1r2/nix-lefthook-linter-coverage";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-dev-shell-agentic,
      nix-lefthook-nix-flake-eval-src,
      nix-lefthook-linter-coverage-src,
      ...
    }@inputs:
    let
      supportedSystems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems =
        f: nixpkgs.lib.genAttrs supportedSystems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: {
        default = pkgs.writeShellApplication {
          name = "lefthook-actionlint";
          runtimeInputs = [ pkgs.actionlint ];
          text = builtins.readFile ./lefthook-actionlint.sh;
        };
      });

      devShells = forAllSystems (
        pkgs:
        let
          inherit (pkgs.stdenv.hostPlatform) system;
          pkg-nix-flake-eval = pkgs.writeShellApplication {
            name = "lefthook-nix-flake-eval";
            runtimeInputs = [ pkgs.nix ];
            text = builtins.readFile "${nix-lefthook-nix-flake-eval-src}/lefthook-nix-flake-eval.sh";
          };
          parseCoverageDoc = pkgs.writeText "parse-coverage-doc.sh" (
            builtins.readFile "${nix-lefthook-linter-coverage-src}/parse-coverage-doc.sh"
          );
          pkg-linter-coverage = pkgs.writeShellApplication {
            name = "lefthook-linter-coverage";
            runtimeInputs = [
              pkgs.gawk
              pkgs.git
              pkgs.gnugrep
              pkgs.gnused
              pkgs.coreutils
            ];
            text = builtins.replaceStrings [ "@PARSE_COVERAGE_DOC@" ] [ "${parseCoverageDoc}" ] (
              builtins.readFile "${nix-lefthook-linter-coverage-src}/lefthook-linter-coverage.sh"
            );
          };
          shells = nix-dev-shell-agentic.lib.mkShells {
            inherit pkgs inputs;
            ciPackages = [
              self.packages.${system}.default
              pkg-nix-flake-eval
              pkg-linter-coverage
            ];
            shellHook = builtins.replaceStrings [ "@BATS_LIB_PATH@" ] [ "${shells.batsWithLibs}" ] (
              builtins.readFile ./dev.sh
            );
          };
        in
        shells
      );
    };
}
