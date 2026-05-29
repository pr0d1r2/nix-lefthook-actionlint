# SPEC — nix-lefthook-actionlint

## §G Goal

Lefthook-compatible actionlint wrapper as Nix flake. Filter .yml/.yaml from args, run actionlint, exit 0 when no match. Two consumption modes: lefthook remote (recommended, zero flake config) and flake input.

## §C Constraints

- C1: Pure Nix packaging — `writeShellApplication` wraps script + actionlint runtime dep
- C2: 4 platforms — aarch64-darwin, x86_64-darwin, x86_64-linux, aarch64-linux
- C3: Timeout at lefthook level via `LEFTHOOK_ACTIONLINT_TIMEOUT` env var, default 30s — script itself has no timeout
- C4: Non-.yml/.yaml files silently skipped (lefthook passes all staged files)
- C5: Non-existent files silently skipped (lefthook may pass deleted files)
- C6: MIT license
- C7: LLM-generated, validated via lefthook hooks + bats tests + CI
- C8: Cachix binary cache (`pr0d1r2.cachix.org`) configured in nixConfig for faster builds
- C9: DevShell via `nix-dev-shell-agentic` — provides `default` + `ci` shells, bats libs, lefthook

## §I Interfaces

- I.cli: `lefthook-actionlint [file ...]` — main entry point, exit 0 if no yaml files, else exit code from actionlint
- I.flake-pkg: `packages.<system>.default` — writeShellApplication with actionlint in runtimeInputs
- I.flake-dev: `devShells.<system>.{default,ci}` — via nix-dev-shell-agentic, includes lefthook-actionlint + bats
- I.remote: `lefthook-remote.yml` — drop-in lefthook remote config (pre-commit + pre-push) for consumers
- I.self-hooks: `lefthook.yml` — dev hooks for this repo (includes 15 lefthook remotes for linting)
- I.env: `LEFTHOOK_ACTIONLINT_TIMEOUT` — seconds, default 30, used in lefthook configs
- I.cache: `nixConfig.extra-substituters` — cachix substituter for pre-built packages

## §V Invariants

- V1: Zero args → exit 0
- V2: All non-yaml args → exit 0
- V3: Non-existent file args → skipped, not error
- V4: Valid .yml/.yaml → actionlint runs, exit 0
- V5: Invalid .yml/.yaml → actionlint runs, exit non-zero
- V6: Mixed yaml + non-yaml → only yaml passed to actionlint
- V7: Multiple files with one bad → exit non-zero (actionlint checks all)
- V8: Both .yml and .yaml extensions accepted
- V9: Script uses `exec actionlint` — process replacement, exit code is actionlint's directly

## §T Tasks

| id | st | desc | cites |
|----|----|------|-------|
| T1 | x | Shell wrapper: filter yaml, exec actionlint | V1-V9,I.cli |
| T2 | x | Nix flake: writeShellApplication package | I.flake-pkg,C1 |
| T3 | x | Nix flake: devShell via nix-dev-shell-agentic | I.flake-dev,C9 |
| T4 | x | lefthook-remote.yml for consumers | I.remote,C3 |
| T5 | x | lefthook.yml for self (dev hooks) | I.self-hooks,I.cli |
| T6 | x | Bats unit tests (7 cases) | V1-V8 |
| T7 | x | CI workflow: 3 platforms via nix-lefthook-ci-action | C2,C8 |
| T8 | x | README with usage docs | I.remote,I.flake-pkg |
| T9 | x | yamllint config (.yamllint.yml) | I.self-hooks |
| T10 | . | Create GitHub repo and push | I.remote |
| T11 | . | Verify CI passes on all 3 platforms | C2,T7 |

## §B Bugs

| id | date | cause | fix |
|----|------|-------|-----|
| B1 | 2026-05-29 | lefthook.yml used raw `actionlint` not on PATH outside devShell | Use `lefthook-actionlint` wrapper |
