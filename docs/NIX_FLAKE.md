# 🧊 Nix Flakes — Development Environment Deep Dive

> A progressive guide from **Newbie → Expert** for setting up reproducible, automated development environments with Nix Flakes.

---

## Table of Contents

- [1. Why Nix Flakes for Dev Environments?](#1-why-nix-flakes-for-dev-environments)
- [2. Prerequisites & Installation](#2-prerequisites--installation)
- [3. Core Concepts](#3-core-concepts)
- [4. Progressive Implementation Levels](#4-progressive-implementation-levels)
  - [Level 0 — Newbie: Hello Nix Shell](#level-0--newbie-hello-nix-shell)
  - [Level 1 — Junior: Project devShell with flake.nix](#level-1--junior-project-devshell-with-flakenix)
  - [Level 2 — Senior: Multi-shell, Tools & Automation](#level-2--senior-multi-shell-tools--automation)
  - [Level 3 — Expert: Composable Flake Architecture](#level-3--expert-composable-flake-architecture)
- [5. Project Recipes](#5-project-recipes)
  - [Backend — NestJS](#backend--nestjs)
  - [Frontend — React / Next.js](#frontend--react--nextjs)
  - [Full-Stack Monorepo](#full-stack-monorepo)
- [6. Tool Integration](#6-tool-integration)
  - [Linting & Formatting (dprint, Biome, ESLint, Prettier)](#linting--formatting)
  - [Pre-commit Hooks](#pre-commit-hooks)
  - [AWS LocalStack](#aws-localstack)
  - [Docker / Podman Compose](#docker--podman-compose)
- [7. Auto-Setup: direnv + nix-direnv](#7-auto-setup-direnv--nix-direnv)
- [8. Developer Experience Enhancers](#8-developer-experience-enhancers)
- [9. Cheatsheet](#9-cheatsheet)
- [10. Troubleshooting](#10-troubleshooting)
- [11. Open Questions & Brainstorm](#11-open-questions--brainstorm)

---

## 1. Why Nix Flakes for Dev Environments?

| Problem | Nix Flakes Solution |
|---|---|
| "Works on my machine" | Deterministic, hash-locked dependencies via `flake.lock` |
| Onboarding takes hours/days | `cd project && direnv allow` — done |
| Conflicting global tool versions | Each project gets its own isolated toolchain |
| Broken system after updates | Atomic rollbacks, garbage collection |
| CI/CD environment drift | Same `flake.lock` = same tools everywhere |

### Mental Model

```
flake.nix          → What you WANT (declarative)
flake.lock         → What you GOT (pinned, reproducible)
nix develop        → Activate the environment (imperative entry)
direnv + .envrc    → Activate AUTOMATICALLY on cd (magic ✨)
```

---

## 2. Prerequisites & Installation

### Install Nix (multi-user, with flakes)

```bash
# Determinate Nix Installer (recommended — flakes enabled by default)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Or official installer + enable flakes manually
sh <(curl -L https://nixos.org/nix/install) --daemon
```

If using the official installer, enable flakes:

```bash
# ~/.config/nix/nix.conf
experimental-features = nix-command flakes
```

### Install direnv + nix-direnv

```bash
# Via Nix itself
nix profile install nixpkgs#direnv nixpkgs#nix-direnv

# Hook into your shell (~/.bashrc or ~/.zshrc)
eval "$(direnv hook bash)"   # or zsh
```

Add to `~/.config/direnv/direnvrc`:

```bash
source $HOME/.nix-profile/share/nix-direnv/direnvrc
```

### VS Code Extension

Install the **direnv** extension (`mkhl.direnv`) so VS Code respects the Nix environment.  
Also recommended: **Nix IDE** (`jnoortheen.nix-ide`) for syntax highlighting & LSP.

---

## 3. Core Concepts

### flake.nix Anatomy

```nix
{
  description = "My project dev environment";

  # INPUTS — dependencies (pinned in flake.lock)
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  # OUTPUTS — what this flake provides
  outputs = { self, nixpkgs, ... }:
  let
    # Helper to support multiple systems (x86_64-linux, aarch64-darwin, etc.)
    eachSystem = f:
      nixpkgs.lib.genAttrs
        [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ]
        (system: f nixpkgs.legacyPackages.${system});
  in
  {
    devShells = eachSystem (pkgs: {
      default = pkgs.mkShell {
        packages = [ /* tools here */ ];
        shellHook = ''
          echo "🚀 Dev environment ready!"
        '';
      };
    });
  };
}
```

### Key Commands

| Command | Purpose |
|---|---|
| `nix develop` | Enter the default devShell |
| `nix develop .#backend` | Enter a named devShell |
| `nix flake update` | Update all inputs (rewrites `flake.lock`) |
| `nix flake lock --update-input nixpkgs` | Update only nixpkgs |
| `nix flake show` | Show what this flake provides |
| `nix flake check` | Run checks/tests defined in the flake |

---

## 4. Progressive Implementation Levels

---

### Level 0 — Newbie: Hello Nix Shell

> **Goal:** Understand that Nix can give you tools without installing them globally.

```bash
# Try a tool without installing it
nix shell nixpkgs#hello nixpkgs#cowsay
hello
cowsay "I'm using Nix!"
exit  # tools are gone

# Run a one-off command
nix shell nixpkgs#nodejs --command node --version
```

**Key takeaway:** Nix provides isolated, temporary environments. Nothing pollutes your system.

---

### Level 1 — Junior: Project devShell with flake.nix

> **Goal:** Create a `flake.nix` that gives your project all the tools it needs.

```nix
# flake.nix — Minimal Node.js project
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { nixpkgs, ... }:
  let
    eachSystem = f:
      nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed
        (system: f nixpkgs.legacyPackages.${system});
  in
  {
    devShells = eachSystem (pkgs: {
      default = pkgs.mkShell {
        packages = with pkgs; [
          nodejs       # Node.js runtime
          pnpm         # Package manager
          gitlint      # Commit message linter
        ];

        shellHook = ''
          echo "📦 Node $(node --version) | pnpm $(pnpm --version)"
        '';
      };
    });
  };
}
```

```bash
# Enter the environment
nix develop

# Or with direnv (auto-activate)
echo "use flake" > .envrc
direnv allow
```

**Key takeaway:** One file (`flake.nix`) declares your entire toolchain. Share it via git.

---

### Level 2 — Senior: Multi-shell, Tools & Automation

> **Goal:** Multiple dev shells, formatter/linter integration, pre-commit hooks, environment variable management.

```nix
# flake.nix — Senior level
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
```

**.envrc** for direnv:

```bash
# .envrc
use flake

# Optional: export additional project-specific vars
export BIOME_BINARY=$(which biome 2>/dev/null || true)
```

```bash
# Use the different shells
nix develop           # default (full-stack)
nix develop .#backend
nix develop .#frontend
nix develop .#ci

# Format Nix files
nix fmt
```

**Key takeaway:** Named shells for different contexts. Pre-commit hooks declared in Nix. Environment variables set declaratively.

---

### Level 3 — Expert: Composable Flake Architecture

> **Goal:** Reusable flake modules, custom overlays, flake-parts, process management, full infrastructure-as-code.

#### Using flake-parts (Recommended for large projects)

```nix
# flake.nix — Expert level with flake-parts
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      imports = [
        inputs.git-hooks.flakeModule
        inputs.treefmt-nix.flakeModule
        inputs.process-compose-flake.flakeModule
      ];

      perSystem = { config, pkgs, system, ... }: {
        # ── Formatting (treefmt) ───────────────────────
        treefmt = {
          projectRootFile = "flake.nix";
          programs = {
            nixfmt.enable = true;        # Nix
            prettier.enable = true;      # JS/TS/CSS/JSON/YAML/MD
            # dprint.enable = true;      # Alternative: faster
          };
        };

        # ── Pre-commit hooks ──────────────────────────
        pre-commit.settings.hooks = {
          treefmt.enable = true;              # Use treefmt for formatting
          eslint.enable = true;
          commitizen.enable = true;
          check-merge-conflicts.enable = true;
          detect-private-keys.enable = true;
        };

        # ── Process Compose (services) ────────────────
        process-compose."services" = {
          settings.processes = {
            localstack = {
              command = "localstack start";
              readiness_probe.http_get = {
                host = "127.0.0.1";
                port = 4566;
                path = "/_localstack/health";
              };
            };
            backend = {
              command = "cd apps/backend && pnpm dev";
              depends_on.localstack.condition = "process_healthy";
            };
            frontend = {
              command = "cd apps/frontend && pnpm dev";
            };
          };
        };

        # ── Dev Shell ─────────────────────────────────
        devShells.default = pkgs.mkShell {
          inputsFrom = [
            config.pre-commit.devShell       # includes hooks
            config.treefmt.build.devShell     # includes formatters
          ];

          packages = with pkgs; [
            # Runtime
            nodejs
            pnpm
            corepack

            # AWS
            awscli2
            localstack

            # Infrastructure
            terraform
            docker-compose

            # Utilities
            jq yq-go httpie process-compose
          ];

          env = {
            AWS_ACCESS_KEY_ID = "test";
            AWS_SECRET_ACCESS_KEY = "test";
            AWS_DEFAULT_REGION = "ap-northeast-1";
            AWS_ENDPOINT_URL = "http://localhost:4566";
          };

          shellHook = ''
            echo ""
            echo "╔══════════════════════════════════════════════╗"
            echo "║  🚀 Dev Environment Ready                   ║"
            echo "║  Node: $(node --version)                       ║"
            echo "║  pnpm: $(pnpm --version)                       ║"
            echo "║                                              ║"
            echo "║  Commands:                                   ║"
            echo "║    nix run .#services  — start all services  ║"
            echo "║    nix fmt             — format all files    ║"
            echo "║    nix flake check     — run all checks      ║"
            echo "╚══════════════════════════════════════════════╝"
            echo ""
          '';
        };
      };
    };
}
```

#### Custom Overlay — Pin or Patch a Package

```nix
# overlays/default.nix
final: prev: {
  # Pin Node.js to a specific major version
  nodejs = prev.nodejs_22;

  # Override dprint to use a specific version
  # dprint = prev.dprint.overrideAttrs (old: rec {
  #   version = "0.45.0";
  #   src = prev.fetchFromGitHub { ... };
  # });
}
```

```nix
# In flake.nix
outputs = { nixpkgs, ... }: {
  overlays.default = import ./overlays;
  devShells = eachSystem (pkgs:
    let myPkgs = pkgs.extend self.overlays.default;
    in { default = myPkgs.mkShell { /* ... */ }; }
  );
};
```

**Key takeaway:** Composable architecture. Services managed via process-compose. Formatters unified via treefmt. Everything is modular and reusable across projects.

---

## 5. Project Recipes

### Backend — NestJS

```nix
# flake.nix
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
```

### Frontend — React / Next.js

```nix
# flake.nix
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
```

### Full-Stack Monorepo

```
my-monorepo/
├── flake.nix           ← Root flake with all devShells
├── flake.lock
├── .envrc              ← "use flake"
├── apps/
│   ├── backend/        ← NestJS
│   │   └── .envrc      ← "use flake .#backend" (optional per-app shell)
│   └── frontend/       ← Next.js
│       └── .envrc      ← "use flake .#frontend"
├── packages/           ← Shared libraries
└── infra/              ← Terraform / Pulumi
```

```nix
# Root flake.nix for monorepo
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
```

---

## 6. Tool Integration

### Linting & Formatting

#### Option A: dprint (Fast, Rust-based)

```nix
packages = with pkgs; [ dprint ];
```

```jsonc
// dprint.json
{
  "plugins": [
    "https://plugins.dprint.dev/typescript-0.93.0.wasm",
    "https://plugins.dprint.dev/json-0.19.4.wasm",
    "https://plugins.dprint.dev/markdown-0.17.8.wasm"
  ]
}
```

> ⚠️ **Gotcha:** pnpm may install its own dprint in `node_modules/.bin/`. Use `shellHook` to fix:

```nix
shellHook = ''
  # Force node_modules/.bin/dprint to point to Nix's dprint
  NIX_DPRINT_BIN="$(command -v dprint)"
  if [ -n "$NIX_DPRINT_BIN" ]; then
    mkdir -p ./node_modules/.bin
    rm -f ./node_modules/.bin/dprint
    ln -s "$NIX_DPRINT_BIN" ./node_modules/.bin/dprint
    echo "✅ dprint → $(readlink -f ./node_modules/.bin/dprint)"
  fi
'';
```

#### Option B: Biome (All-in-one linter + formatter)

```nix
packages = with pkgs; [ biome ];

shellHook = ''
  export BIOME_BINARY="$(command -v biome)"
'';
```

#### Option C: treefmt (Unified multi-language formatting)

With `treefmt-nix` flake input — see [Level 3 Expert example](#level-3--expert-composable-flake-architecture).

### Pre-commit Hooks

#### Option A: Nix-native with git-hooks.nix (cachix/git-hooks.nix)

See [Level 2 Senior example](#level-2--senior-multi-shell-tools--automation). Hooks are declared in Nix, installed automatically on `nix develop`.

#### Option B: Traditional pre-commit + .pre-commit-config.yaml

```nix
packages = with pkgs; [ pre-commit gitlint ];

shellHook = ''
  pre-commit install --install-hooks
'';
```

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-merge-conflict
      - id: detect-private-key

  - repo: https://github.com/commitizen-tools/commitizen
    rev: v3.29.0
    hooks:
      - id: commitizen

  - repo: local
    hooks:
      - id: dprint
        name: dprint format
        entry: dprint fmt --diff
        language: system
        pass_filenames: false
```

### AWS LocalStack

```nix
packages = with pkgs; [
  awscli2
  localstack       # LocalStack CLI
  # docker-compose # if running LocalStack via Docker
];

env = {
  AWS_ACCESS_KEY_ID = "test";
  AWS_SECRET_ACCESS_KEY = "test";
  AWS_DEFAULT_REGION = "ap-northeast-1";
  AWS_ENDPOINT_URL = "http://localhost:4566";  # LocalStack default port
};
```

```bash
# Start LocalStack
localstack start -d

# Verify
awslocal s3 mb s3://my-bucket
awslocal s3 ls

# Or use process-compose for orchestration (Expert level)
nix run .#services
```

### Docker / Podman Compose

```nix
packages = with pkgs; [
  docker-compose   # or podman-compose
  docker-client    # or podman
];
```

```yaml
# docker-compose.yml — LocalStack + PostgreSQL
services:
  localstack:
    image: localstack/localstack
    ports:
      - "4566:4566"
    environment:
      - SERVICES=s3,sqs,lambda,dynamodb
      - DEFAULT_REGION=ap-northeast-1

  postgres:
    image: postgres:16
    ports:
      - "5432:5432"
    environment:
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: myapp
```

---

## 7. Auto-Setup: direnv + nix-direnv

> **The killer feature:** `cd` into your project → environment is ready. No manual steps.

### How It Works

```
You:     cd ~/projects/my-app
direnv:  Loading .envrc → "use flake"
nix:     Activating devShell from flake.nix
Result:  All tools available. ENV vars set. Hooks installed.
         It just works. ✨
```

### Setup

1. **Install direnv + nix-direnv** (see [Prerequisites](#2-prerequisites--installation))

2. **Create `.envrc` in your project root:**

```bash
# .envrc — Basic
use flake

# .envrc — With extras
use flake

# Project-specific overrides
export BIOME_BINARY=$(which biome 2>/dev/null || true)
export NODE_ENV=development

# Watch additional files for changes
watch_file flake.nix
watch_file flake.lock
```

3. **Allow direnv:**

```bash
direnv allow
```

4. **Add to `.gitignore`:**

```gitignore
# direnv
.direnv/
```

### Per-directory Shells in Monorepo

```bash
# apps/backend/.envrc
source_up        # inherit parent .envrc
use flake ..#backend

# apps/frontend/.envrc
source_up
use flake ..#frontend
```

### VS Code Integration

Install `mkhl.direnv` extension. It will:
- Auto-detect `.envrc`
- Load the Nix environment into VS Code's integrated terminal
- Make language servers find the right tools
- Show a notification when the environment loads

---

## 8. Developer Experience Enhancers

### starship — Beautiful Shell Prompt

Shows Nix shell indicator, git branch, Node version, etc.

```nix
packages = with pkgs; [ starship ];

shellHook = ''
  eval "$(starship init bash)"  # or zsh
'';
```

### process-compose — Service Orchestration

Run backend, frontend, database, LocalStack all at once:

```bash
nix run .#services
# Opens a TUI showing all processes, logs, health status
```

### devenv — Higher-level Nix Dev Environments

An alternative/complementary approach with more batteries included:

```nix
# devenv.nix
{ pkgs, ... }: {
  languages.javascript = {
    enable = true;
    package = pkgs.nodejs;
    pnpm.enable = true;
  };

  services.postgres.enable = true;
  services.localstack.enable = true;

  pre-commit.hooks = {
    prettier.enable = true;
    eslint.enable = true;
  };
}
```

### mise (formerly rtx) — Polyglot Version Manager

Can coexist with Nix for teams partially adopting Nix:

```nix
packages = with pkgs; [ mise ];
```

### Cachix — Binary Cache

Avoid rebuilding tools from source:

```bash
# Setup
nix profile install nixpkgs#cachix
cachix use my-org

# In CI, push built artifacts
cachix push my-org ./result
```

---

## 9. Cheatsheet

### Flake Commands

```bash
# ── Environment ───────────────────────────────────
nix develop                   # Enter default devShell
nix develop .#backend         # Enter named devShell
nix develop --command zsh     # Use a specific shell

# ── Flake Management ─────────────────────────────
nix flake init                # Create a new flake.nix
nix flake update              # Update all inputs (rewrite flake.lock)
nix flake lock --update-input nixpkgs  # Update single input
nix flake show                # Show flake outputs
nix flake check               # Run checks (tests, pre-commit, etc.)
nix flake metadata            # Show flake metadata & inputs tree

# ── Formatting ────────────────────────────────────
nix fmt                       # Format with declared formatter

# ── Building & Running ───────────────────────────
nix build                     # Build default package
nix build .#myPackage         # Build named package
nix run .#services            # Run a named app

# ── Debugging ─────────────────────────────────────
nix repl                      # Interactive Nix REPL
# In REPL:
#   :lf .                     # Load current flake
#   outputs.<TAB>             # Explore outputs
#   :q                        # Quit

# ── Garbage Collection ───────────────────────────
nix store gc                  # Remove unused store paths
nix store gc --min 10G        # Free at least 10 GB

# ── Search ────────────────────────────────────────
nix search nixpkgs nodejs     # Find packages
nix search nixpkgs --json nodejs | jq  # JSON output
```

### direnv Commands

```bash
direnv allow                  # Trust current .envrc
direnv deny                   # Untrust current .envrc
direnv reload                 # Force reload environment
direnv status                 # Show direnv state
```

### Common Patterns

```nix
# Pin Node.js version
nodejs_22

# Override yarn to use specific Node
(yarn.override { nodejs = nodejs_22; })

# Python with packages
(python3.withPackages (ps: [ ps.flask ps.boto3 ]))

# Use env attribute for clean environment variable declaration
env = {
  MY_VAR = "value";
  DATABASE_URL = "postgresql://localhost/mydb";
};

# Multiple inputs with follows (dedup nixpkgs)
inputs.some-tool = {
  url = "github:owner/tool";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

---

## 10. Troubleshooting

| Problem | Solution |
|---|---|
| `error: experimental feature 'flakes' is disabled` | Add `experimental-features = nix-command flakes` to `~/.config/nix/nix.conf` |
| `pnpm` uses wrong binary from `node_modules/.bin/` | Use `shellHook` to symlink Nix binary (see [dprint gotcha](#option-a-dprint-fast-rust-based)) |
| `direnv` not loading in VS Code | Install `mkhl.direnv` extension. Restart VS Code after `direnv allow` |
| `nix develop` is slow first time | Expected — it downloads/builds packages. Subsequent runs use cache. Use Cachix for team-wide binary cache |
| `warning: Git tree is dirty` | Commit or `git add` your `flake.nix`. Nix tracks git-tracked files only |
| `error: path '/nix/store/...' is not valid` | Run `nix store repair --all` or `nix store gc` |
| Environment not updating after `flake.nix` change | `direnv reload` or exit and re-run `nix develop` |
| Collision between Nix tool and `node_modules` tool | Use `shellHook` to create symlinks or `export TOOL_BINARY=$(which tool)` |

---

## 11. Open Questions & Brainstorm

### Architecture & Strategy

- [ ] **Mono-flake vs multi-flake?** Should a monorepo have one `flake.nix` at root, or one per app? What are the trade-offs for lock file management?
- [ ] **devenv vs raw flake vs flake-parts?** Which abstraction level is right for the team? How much Nix knowledge should be required?
- [ ] **How to handle secrets in dev environments?** `sops-nix`, `agenix`, `.env` files, or vault integration?
- [ ] **What's the migration path for a team not using Nix?** Can Nix coexist with `nvm`/`volta`/`asdf`/`mise` during transition?

### Tooling & DX

- [ ] **dprint vs Biome vs Prettier?** dprint is fastest but less ecosystem. Biome replaces ESLint+Prettier. Prettier has most plugins. Which to standardize on?
- [ ] **How to handle npm postinstall scripts that need native dependencies?** (e.g., `sharp`, `bcrypt`, Prisma engines) — use `LD_LIBRARY_PATH`? `buildFHSUserEnv`?
- [ ] **Should pre-commit hooks be Nix-managed (git-hooks.nix) or traditional (.pre-commit-config.yaml)?** What about CI parity?
- [ ] **How to integrate Playwright/Cypress browsers in Nix?** Chromium sandboxing issues? Use `playwright-driver.browsers` or system browsers?

### Infrastructure

- [ ] **LocalStack vs real AWS dev accounts?** What services are well-emulated? What's the boundary?
- [ ] **process-compose vs docker-compose for local services?** Nix-native (process-compose) is lighter but less portable. Docker is more familiar but adds overhead.
- [ ] **How to share Nix binary caches across the team?** Self-hosted Attic? Cachix? S3 bucket? GitHub Actions cache?
- [ ] **Can we build Docker images with Nix (`dockerTools`) instead of Dockerfile?** Benefits: smaller images, reproducible builds. Cost: learning curve.

### Team & Adoption

- [ ] **How to enforce that everyone uses Nix environments?** CI checks? Git hooks that verify Nix shell? `.tool-versions` fallback?
- [ ] **What's the minimum Nix knowledge for a developer?** Can we make it so devs only need `cd` and `direnv allow`?
- [ ] **How to version/template flake.nix across multiple projects?** Flake templates? Internal flake registry? Shared overlays?
- [ ] **How to handle Nix on CI/CD?** GitHub Actions with `DeterminateSystems/nix-installer-action`? Self-hosted runners with Nix pre-installed?

### Performance & Maintenance

- [ ] **How to keep `flake.lock` up to date?** Renovate bot? Scheduled `nix flake update` in CI? Manual?
- [ ] **Disk usage management?** Nix store grows fast. Auto-GC? Per-project `.nix-gc-roots`?
- [ ] **How to debug slow `nix develop` times?** Use `--show-trace`? Profile with `nix eval`? Reduce input count?
- [ ] **What if nixpkgs doesn't have the version we need?** Pin specific commits? Use overlays? Fall back to `npm`/`npx`?

### Advanced Exploration

- [ ] **Nix-based CI pipelines?** Hydra? Garnix? Hercules CI? Or just Nix in GitHub Actions?
- [ ] **NixOS as the dev machine OS?** Full reproducibility from OS to project. Worth the investment?
- [ ] **Remote development with Nix?** Codespaces / Devcontainers with Nix? `nix copy` to remote machines?
- [ ] **Can Nix replace Terraform for infrastructure?** NixOps? Colmena? Terranix?

---

## References

- [Nix Flakes Book (ryan4yin)](https://nixos-and-flakes.thiscute.world/) — Best beginner-friendly guide
- [nix.dev](https://nix.dev/) — Official Nix documentation
- [NixOS/nixpkgs](https://github.com/NixOS/nixpkgs) — Package repository
- [nix-community/nix-direnv](https://github.com/nix-community/nix-direnv) — Fast direnv integration
- [cachix/git-hooks.nix](https://github.com/cachix/git-hooks.nix) — Pre-commit hooks as Nix flake
- [numtide/treefmt-nix](https://github.com/numtide/treefmt-nix) — Unified formatting
- [hercules-ci/flake-parts](https://github.com/hercules-ci/flake-parts) — Composable flake modules
- [Platonic-Systems/process-compose-flake](https://github.com/Platonic-Systems/process-compose-flake) — Service orchestration
- [juspay/services-flake](https://github.com/juspay/services-flake) — Pre-built service definitions
- [devenv.sh](https://devenv.sh/) — Higher-level dev environments on Nix
- [Determinate Systems Nix Installer](https://github.com/DeterminateSystems/nix-installer) — Recommended installer
