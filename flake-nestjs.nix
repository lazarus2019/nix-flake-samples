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
          # NestJS CLI
          nodePackages."@nestjs/cli"
          # Database
          postgresql
          # AWS
          awscli2
          localstack
          # Quality
          dprint
          pre-commit
          gitlint
          # LSP
          nodePackages.typescript-language-server
        ];

        env = {
          DATABASE_URL = "postgresql://postgres:postgres@localhost:5432/myapp";
          AWS_ACCESS_KEY_ID = "test";
          AWS_SECRET_ACCESS_KEY = "test";
          AWS_DEFAULT_REGION = "ap-northeast-1";
          AWS_ENDPOINT_URL = "http://localhost:4566";
        };

        shellHook = ''
          echo "🏗️  NestJS Backend — Node $(node --version)"
        '';
      };
    });
  };
}