---
name: nix
description: "Load when working with Nix, NixOS, Home Manager, nix-darwin, nixpkgs, flakes, derivations, overlays, modules, options, or registries; with .nix files such as configuration.nix, home.nix, default.nix, shell.nix, or flake.nix; or with the Nix CLI (nix build, nix develop, nix flake, nix repl, nix fmt, nix-shell). Use even when the user only mentions a Nix package, option, overlay, flake input, or hash-mismatch error without naming Nix explicitly."
---

# Nix Skill

<!-- Vendored from https://github.com/wimpysworld/nix-config/blob/main/home-manager/_mixins/agentic/assistants/skills/nix/SKILL.md (2026-08-19)
     本地适配:
     - References 表改写为 mcp-nixos v3 统一接口(上游写的是 v2 细分工具名 nixos_search 等)
     - Constraints 补一条 devenv 优先约定(与全局 AGENTS.md 一致)
     与 nixpkgs skill 分工:本条 = 判断/约束层(工作流与防坑),nixpkgs = 打包 API 参考 -->

## Role

Use expert Nix judgement across the Nix language, nixpkgs, NixOS, Home Manager, nix-darwin, flakes, packaging, overlays, reproducibility, evaluation, builds, and debugging. Prefer current Nix CLI and flakes unless the project uses legacy workflows. Explain trade-offs only where they affect the implementation.

## References

Verify names, option paths, versions, and syntax with authoritative current references when tools are available. Do not rely on memory for package names or module options.

The local `nixos` MCP server (mcp-nixos v3) exposes a single unified `nix` tool plus `nix_versions`:

| Need                     | Tool call                                                                 |
| ------------------------ | ------------------------------------------------------------------------- |
| NixOS packages           | `nix` `action: "search"` / `"info"`, `query` = name, `type: "packages"`    |
| NixOS / HM / darwin options | `nix` `action: "search"` / `"info"`, `type: "options"`, `source: "nixos"` / `"home-manager"` / `"darwin"` |
| Option tree browsing     | `nix` `action: "browse"` with an option prefix (HM/darwin/nixvim/nvf only) |
| Package version history  | `nix_versions` (NixHub, commit-accurate: which nixpkgs commit ships X)    |
| Flakes / FlakeHub        | `nix` `action: "search"`, `type: "flakes"` or `source: "flakehub"`         |
| Docs                     | `nix` with `source: "wiki"` / `"nix-dev"` / `"noogle"`                    |
| Channel pinning          | `channel: "unstable"` (default) / `"stable"` / `"25.05"` etc.             |

## Guidance

- Model module changes through options, `lib.mkIf`, `lib.mkMerge`, priorities, and imports that match the existing project architecture.
- Use `home.packages` for Home Manager user packages and `environment.systemPackages` for NixOS system packages.
- Package with the appropriate nixpkgs builder: `stdenv.mkDerivation`, `buildGoModule`, `buildPythonPackage`, Rust builders, Node builders, or project-specific helpers.
- Prefer overlays and overrides for package customisation; keep local packages composable and easy to build with `nix build`.
- Treat hash mismatches as normal fixed-output derivation workflow: use a fake hash, build, copy the reported hash, then rebuild.
- Debug by separating parse errors, evaluation errors, option type errors, missing attributes, dependency failures, and runtime failures.
- Preserve reproducibility: pin inputs through flakes or project lock policy, avoid impurity unless the project already requires it.

## Commands

Prefer project commands for formatting, evaluation, checks, builds, and updates. Common fallbacks are `nix fmt`, `nix flake check`, `nix build`, `nix develop`, `nix eval`, and `nix repl`.

## Constraints

- Never edit lock files directly unless project policy explicitly says to do so; use the project update command or `nix flake update`.
- Never change existing NixOS or Home Manager state version values unless explicitly requested.
- Never assume packages, options, or flake outputs exist; verify them.
- Never use legacy `nix-build`, `nix-shell`, or `nix-env` when the project uses flakes and the new CLI.
- Preserve existing module architecture, naming conventions, formatting, and validation commands.
- In projects that standardize on `devenv.nix` (cachix/devenv), extend devenv instead of introducing a new `flake.nix`.
