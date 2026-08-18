{
  self,
  nixpkgs,
  set-and-setting,
  ...
}:
{
  packages =
    nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ]
      (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.writeShellApplication {
            name = "lefthook-actionlint";
            runtimeInputs = [ pkgs.actionlint ];
            text = builtins.readFile ./../lefthook-actionlint.sh;
          };
          setting = (set-and-setting.lib.mkSetting { inherit pkgs; }).materialized;
        }
      );

  devShells =
    nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ]
      (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          fragments = [
            "base"
            "actions"
            "nix"
            "shell"
            "ascii"
            "markdown"
            "yaml"
          ];
          mat = set-and-setting.lib.materializationFor { inherit pkgs fragments; };
          sys = pkgs.stdenv.hostPlatform.system;
        in
        set-and-setting.lib.mkDevShells {
          inherit pkgs;
          basePackages = mat.packages ++ [ self.packages.${sys}.default ];
          settingHook = ''
            ${self.packages.${sys}.setting}/bin/sync-setting .
            _assemble_out="$(mktemp -d)"
            FRAGMENTS="${builtins.concatStringsSep " " fragments}" out="$_assemble_out" FRAGMENTS_DIR="${set-and-setting}/setting/integrations/lefthook" bash "${set-and-setting}/setting/lib/assemble-lefthook.sh"
            cp -f "$_assemble_out/lefthook.yml" lefthook.yml
            rm -rf "$_assemble_out"
          '';
        }
      );

  checks = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ] (
    system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      fragments = [
        "base"
        "actions"
        "nix"
        "shell"
        "ascii"
        "markdown"
        "yaml"
      ];
      checkFragments = builtins.filter (fragment: fragment != "actions") fragments;
      # set-and-setting's mkActionlintCheck currently passes a scalar regex to
      # nixpkgs' sourceByRegex, whose current API requires a list of regexes.
      # Keep the actions check enabled, but provide the compatible equivalent
      # locally until the shared helper is updated.
      actionlintCheck =
        let
          workflowFiles = nixpkgs.lib.sources.sourceByRegex (nixpkgs.lib.sources.sourceFilesBySuffices ./.. [
            ".yml"
            ".yaml"
          ]) [ "^\\.github/workflows/.*" ];
        in
        pkgs.runCommand "actionlint-check" { nativeBuildInputs = [ pkgs.findutils ]; } ''
          cd ${workflowFiles}
          mapfile -t matches < <(find . -type f | sort)
          if [ ''${#matches[@]} -eq 0 ]; then
            echo "actionlint: no matching files, nothing to check"
            touch $out
            exit 0
          fi
          ${nixpkgs.lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.default} "''${matches[@]}"
          echo "actionlint: PASS (''${#matches[@]} files)"
          touch $out
        '';
    in
    (set-and-setting.lib.checksFor {
      inherit pkgs;
      fragments = checkFragments;
      src = ./..;
    })
    // {
      actionlint = actionlintCheck;
    }
    // {
      dep-graph = set-and-setting.lib.mkDepGraphCheck {
        inherit pkgs;
        projectRoot = ./..;
      };
      default = pkgs.runCommand "checks" { } "touch $out";
    }
  );

  apps = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ] (
    system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      mat = set-and-setting.lib.materializationFor {
        inherit pkgs;
        fragments = [
          "base"
          "actions"
          "nix"
          "shell"
          "ascii"
          "markdown"
          "yaml"
        ];
      };
      sys = pkgs.stdenv.hostPlatform.system;
    in
    {
      confirm = {
        type = "app";
        program = "${
          pkgs.writeShellApplication {
            name = "confirm";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.diffutils
              pkgs.findutils
              pkgs.gawk
              pkgs.git
              pkgs.gnugrep
            ]
            ++ mat.packages
            ++ [ self.packages.${sys}.default ];
            text = ''
              export FRAGMENTS_DIR="${set-and-setting}/setting/integrations/lefthook"
              export ASSEMBLE_SCRIPT="${set-and-setting}/setting/lib/assemble-lefthook.sh"
              export DETECT_SCRIPT="${set-and-setting}/setting/lib/detect-fragments.sh"
              export SETTING_SRC="${self.packages.${sys}.setting}"
              export CONFIRM_SCRIPT="${set-and-setting}/lib/confirm.sh"
              export CONFIRM_REV="${set-and-setting.rev or "unknown"}"
              bash "$CONFIRM_SCRIPT"
            '';
          }
        }/bin/confirm";
      };
    }
  );
}
