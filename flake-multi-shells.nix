{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # pre-commit hooks as a flake input
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, git-hooks, ... }:
  let
    supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    eachSystem = f:
      nixpkgs.lib.genAttrs supportedSystems
        (system: f nixpkgs.legacyPackages.${system});
  in
  {
    # ── Pre-commit checks ──────────────────────────────
    checks = eachSystem (pkgs: {
      pre-commit-check = git-hooks.lib.${pkgs.system}.run {
        src = ./.;
        hooks = {
          # Nix
          nixfmt-rfc-style.enable = true;

          # JS/TS
          eslint.enable = true;
          prettier = {
            enable = true;
            types_or = [ "javascript" "typescript" "css" "json" "yaml" "markdown" ];
          };

          # Git
          commitizen.enable = true;

          # General
          check-merge-conflicts.enable = true;
          detect-private-keys.enable = true;
        };
      };
    });

    # ── Dev Shells ─────────────────────────────────────
    devShells = eachSystem (pkgs: {
      # Default — full-stack dev environment
      default = pkgs.mkShell {
        inherit (self.checks.${pkgs.system}.pre-commit-check) shellHook;

        packages = with pkgs; [
          # Runtime
          nodejs
          pnpm
          corepack

          # Linting / Formatting
          dprint          # Fast formatter (Rust-based)
          nodePackages.eslint
          nodePackages.prettier

          # Git
          pre-commit
          gitlint
          commitizen

          # AWS
          awscli2
          localstack

          # LSP / Editor
          nodePackages.typescript-language-server

          # Utilities
          jq
          yq-go
          httpie
          hyperfine  # benchmarking
        ];

        env = {
          # AWS LocalStack config
          AWS_ACCESS_KEY_ID = "test";
          AWS_SECRET_ACCESS_KEY = "test";
          AWS_DEFAULT_REGION = "ap-northeast-1";
          AWS_ENDPOINT_URL = "http://localhost:4566";
        };
      };

      # Backend only
      backend = pkgs.mkShell {
        packages = with pkgs; [ nodejs pnpm awscli2 ];
      };

      # Frontend only
      frontend = pkgs.mkShell {
        packages = with pkgs; [ nodejs pnpm ];
      };

      # CI — minimal for pipelines
      ci = pkgs.mkShell {
        packages = with pkgs; [ nodejs pnpm ];
      };
    });

    # ── Formatter (nix fmt) ────────────────────────────
    formatter = eachSystem (pkgs: pkgs.nixfmt-rfc-style);
  };
}