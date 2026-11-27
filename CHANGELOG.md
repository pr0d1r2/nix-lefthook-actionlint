# Changelog

All notable changes to this project are documented here.

## Unreleased

- Fix `lefthook-remote.yml` running bare `actionlint`; it now calls the `lefthook-actionlint` wrapper when on PATH and falls back to bare `actionlint` for remote-only consumers (#43)
