{
  inputs = {
    # nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # Support a particular subset of the Nix systems
    # systems.url = "github:nix-systems/default";
  };

  outputs =
    { nixpkgs, ... }:
    let
      eachSystem =
        f:
        nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = eachSystem (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            nodejs
            # corepack
            # pre-commit
            gitlint
            # If you want to use biome, remember add `export BIOME_BINARY=$(which biome)` in .envrc to use biome's binary of nix instead of node_modules.
            biome
            # dprint
            # aws-lambda-rie
            # To install a specific alternative package manager directly,
            # comment out one of these to use an alternative package manager.

            # pkgs.yarn
            # pnpm
            bun

            # Required to enable the language server
            nodePackages.typescript
            nodePackages.typescript-language-server

            # Python is required on NixOS if the dependencies require node-gyp
            # pkgs.python3
          ];
        };
      });
    };
}
