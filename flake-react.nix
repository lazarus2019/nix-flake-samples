{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { nixpkgs, ... }:
  let
    eachSystem = f:
      nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed
        (system: f nixpkgs.legacyPackages.${system});
  in {
    devShells = eachSystem (pkgs: {
      default = pkgs.mkShell {
        packages = with pkgs; [
          nodejs
          pnpm
          # Formatting / Linting
          biome
          nodePackages.prettier
          # Image optimization (for Next.js)
          sharp
          # LSP
          nodePackages.typescript-language-server
          # Browsers for testing
          # playwright-driver.browsers
        ];

        env = {
          NEXT_TELEMETRY_DISABLED = "1";
        };

        shellHook = ''
          echo "⚛️  React/Next.js Frontend — Node $(node --version)"
          # Ensure biome from Nix is used instead of node_modules
          export BIOME_BINARY="$(command -v biome)"
        '';
      };
    });
  };
}