{
  description = "A basic flake with a shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.systems.url = "github:nix-systems/default";
  inputs.flake-utils = {
    url = "github:numtide/flake-utils";
    inputs.systems.follows = "systems";
  };
  inputs.treefmt-nix.url = "github:numtide/treefmt-nix";

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      treefmt-nix,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
      in
      {
        packages = {
          ci_checks = pkgs.writeShellApplication {
            name = "ci_checks";
            runtimeInputs = [ pkgs.python313Packages.openapi-spec-validator ];
            text = "openapi-spec-validator openapi.yml";
          };
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            gleam
            beam27Packages.erlang
            rebar3
            # inotify-tools
            redocly-cli
            nodejs_22
          ];
        };

        # run with `nix fmt`
        formatter = treefmtEval.config.build.wrapper;

        # run with `nix flake check`
        checks.formatting = treefmtEval.config.build.check self;
      }
    );
}
