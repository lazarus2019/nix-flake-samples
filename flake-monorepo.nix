{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { nixpkgs, ... }:
  let
    eachSystem = f:
      nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed
        (system: f nixpkgs.legacyPackages.${system});

    commonPackages = pkgs: with pkgs; [
      nodejs
      pnpm
      dprint
      pre-commit
      gitlint
      jq
    ];
  in {
    devShells = eachSystem (pkgs: {
      # Full monorepo dev
      default = pkgs.mkShell {
        packages = (commonPackages pkgs) ++ (with pkgs; [
          awscli2
          localstack
          docker-compose
          terraform
        ]);
      };

      # Backend only
      backend = pkgs.mkShell {
        packages = (commonPackages pkgs) ++ (with pkgs; [
          awscli2
          localstack
          postgresql
        ]);
        env.DATABASE_URL = "postgresql://postgres:postgres@localhost:5432/myapp";
      };

      # Frontend only
      frontend = pkgs.mkShell {
        packages = (commonPackages pkgs) ++ (with pkgs; [
          biome
        ]);
        env.NEXT_TELEMETRY_DISABLED = "1";
      };

      # CI pipeline (minimal)
      ci = pkgs.mkShell {
        packages = with pkgs; [ nodejs pnpm ];
      };
    });
  };
}