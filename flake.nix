{
  description = "Port of ttf-ms-win11{,-fod}-auto* packages to Nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.devshell.url = "github:numtide/devshell";
  inputs.flake-compat.url = "https://flakehub.com/f/edolstra/flake-compat/1.tar.gz";

  outputs = inputs @ {
    nixpkgs,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;}
    {
      imports = [
        inputs.devshell.flakeModule
        inputs.flake-parts.flakeModules.easyOverlay
      ];
      systems = [
        "i686-linux"
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      perSystem = {
        pkgs,
        system,
        config,
        ...
      }: {
        _module.args.pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        packages = let
          allPackages =
            pkgs.lib.mapAttrs' (jsonFileName: _: let
              pkgName = pkgs.lib.removeSuffix ".json" jsonFileName;
              pkgData = builtins.fromJSON (builtins.readFile ./pkgs/${jsonFileName});
            in {
              name = pkgName;
              value = (import ./mkPackage.nix) {
                inherit pkgs pkgName;
                inherit (pkgData) archive files iso outputHash parentDir version;
              };
            })
            (builtins.readDir ./pkgs);
        in
          allPackages
          // rec {
            ttf-ms-win11-auto-all = pkgs.symlinkJoin {
              name = "ttf-ms-win11-auto-all";
              paths = pkgs.lib.attrValues allPackages;
            };
            default = ttf-ms-win11-auto-all;
          };
        overlayAttrs = builtins.listToAttrs (
          map (pkgName: {
            name = pkgName;
            value = config.packages.${pkgName};
          }) (pkgs.lib.attrNames config.packages)
        );
        devshells.default = {
          commands = [
            {
              help = "Update the package definitions in pkgs.json";
              name = "update-pkgs";
              command = "${pkgs.bash}/bin/bash ${./.}/update-pkgs.sh update";
            }
            {
              help = "Force update the package definitions in pkgs.json";
              name = "update-pkgs-force";
              command = "${pkgs.bash}/bin/bash ${./.}/update-pkgs.sh force-update";
            }
          ];
          packages = with pkgs; [
            git
            jq
            parallel
            (pkgs.python3.withPackages (p: [
              p.fontforge
            ]))
          ];
        };
      };
    };
}
