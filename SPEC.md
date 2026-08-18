# SPEC -- nix-lefthook-actionlint

## S.G Goal

Lefthook-compatible actionlint wrapper as Nix flake. Filter YAML args, run actionlint, and exit 0 when no match. Supports lefthook remote (recommended) and flake input.

## S.C Constraints

- C1: Pure Nix packaging -- `writeShellApplication` wraps script + actionlint runtime dep
- C2: 4 platforms -- aarch64-darwin, x86_64-darwin, x86_64-linux, aarch64-linux
- C3: Timeout at lefthook level via `LEFTHOOK_ACTIONLINT_TIMEOUT` env var, default 30s -- script itself has no timeout
- C4: Non-.yml/.yaml files silently skipped (lefthook passes all staged files)
- C5: Non-existent files silently skipped (lefthook may pass deleted files)
- C6: MIT
- C7: LLM-generated, validated via hooks, bats tests + CI
- C8: Cachix binary cache configured in nixConfig
- C9: DevShell via `nix-dev-shell-agentic` -- provides shells, bats libs, lefthook

## S.I Interfaces

- I.cli: `lefthook-actionlint [file ...]` -- main entry point, exit 0 if no yaml files, else exit code from actionlint
- I.flake-pkg: `packages.<system>.default` -- writeShellApplication with actionlint in runtimeInputs
- I.flake-dev: `devShells.<system>.{default,ci}` -- via nix-dev-shell-agentic, includes lefthook-actionlint + bats
- I.remote: `lefthook-remote.yml` -- drop-in consumer config
- I.self-hooks: `lefthook.yml` -- this repo's dev hooks
- I.env: `LEFTHOOK_ACTIONLINT_TIMEOUT` -- seconds, default 30, used in lefthook configs
- I.cache: `nixConfig.extra-substituters` -- cachix substituter for pre-built packages

## S.V Invariants

- V1: Zero args -> exit 0
- V2: All non-yaml args -> exit 0
- V3: Non-existent file args -> skipped, not error
- V4: Valid .yml/.yaml -> actionlint runs, exit 0
- V5: Invalid .yml/.yaml -> actionlint runs, exit non-zero
- V6: Mixed yaml + non-yaml -> only yaml passed to actionlint
- V7: Multiple files with one bad -> exit non-zero (actionlint checks all)
- V8: Both .yml and .yaml extensions accepted
- V9: Script uses `exec actionlint` -- process replacement, exit code is actionlint's directly

## S.T Tasks

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
| T10 | x | Create GitHub repo and push | I.remote |
| T11 | . | Verify CI passes on all 3 platforms | C2,T7 |

## S.B Bugs

| id | date | cause | fix |
|----|------|-------|-----|
| B1 | 2026-05-29 | lefthook.yml used raw `actionlint` not on PATH outside devShell | Use `lefthook-actionlint` wrapper |
| B2 | 2026-07-21 | Migration left confirm app and devShell without lefthook-* wrappers on PATH; unused `nix-dev-shell-agentic` input flagged by deadnix; missing `.nix-embedded-shell-allowlist`; shfmt 4-vs-2-space indent | Add `mat.packages` + `self.packages` to confirm app `runtimeInputs` and devShell `basePackages`; remove stale input; add allowlist; fix indent |
| B3 | 2026-07-28 | Pin refresh grew `flake.lock` beyond the stale 64 KiB file-size limit | Raise the `.lock` limit to 128 KiB while retaining file-size enforcement |
| B4 | 2026-08-07 | Flake manifest guard rejected helper bindings and an inline outputs attrset | Delegate outputs to `flake/default.nix` and keep the root flake manifest declarative |
| B5 | 2026-08-08 | Root `flake.nix` did not merge `flake/default.nix`, leaving the wrapper out of devShell and confirm PATH | Merge delegated outputs into consumer-flake outputs |
| B6 | 2026-08-08 | Required B5 history entry pushed SPEC.md past the 4 KiB markdown limit | Compact redundant SPEC text while retaining the limit |
| B7 | 2026-08-18 | Generated lefthook configuration was absent and fragment lists omitted detected GitHub Actions hooks | Include the actions fragment everywhere and commit the generated lefthook.yml |
| B8 | 2026-08-18 | Guardrails rejected scalar lefthook glob patterns where the current schema requires lists | Encode every generated hook glob as a one-item list |
| B9 | 2026-08-18 | Shared actionlint check passed a scalar regex to the current nixpkgs `sourceByRegex` API, preventing flake evaluation | Keep the actions check enabled with a local equivalent using the list-valued regex API |
| B10 | 2026-08-18 | Linter-coverage guard required its exemptions manifest, but the repository did not include one | Add the empty `config/linter-coverage-exemptions.yml` manifest |
| B11 | 2026-08-18 | Nix formatting and the required bug-history entry pushed `flake/default.nix` and `SPEC.md` beyond their 4 KiB limits | Raise only the `.nix` and `.md` limits to 8 KiB while retaining file-size enforcement |
