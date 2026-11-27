#!/usr/bin/env bats

setup() {
    TMP="$BATS_TEST_TMPDIR"
}

assert_success() {
    [ "$status" -eq 0 ]
}

assert_failure() {
    [ "$status" -ne 0 ]
}

@test "no args exits 0" {
    run lefthook-actionlint
    assert_success
}

@test "non-existent file is skipped" {
    run lefthook-actionlint /nonexistent/workflow.yml
    assert_success
}

@test "non-yaml files are skipped" {
    echo 'hello' > "$TMP/readme.md"
    run lefthook-actionlint "$TMP/readme.md"
    assert_success
}

@test "valid workflow passes" {
    mkdir -p "$TMP/.github/workflows"
    cat > "$TMP/.github/workflows/ci.yml" <<'YML'
name: CI
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "hello"
YML
    run lefthook-actionlint "$TMP/.github/workflows/ci.yml"
    assert_success
}

@test "invalid workflow fails" {
    cat > "$TMP/bad.yml" <<'YML'
name: Bad
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo "hello"
        if: ${{ invalid_expression( }}
YML
    run lefthook-actionlint "$TMP/bad.yml"
    assert_failure
}

@test ".yaml extension is accepted" {
    mkdir -p "$TMP/.github/workflows"
    cat > "$TMP/.github/workflows/ci.yaml" <<'YML'
name: CI
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "hello"
YML
    run lefthook-actionlint "$TMP/.github/workflows/ci.yaml"
    assert_success
}

@test "multiple files: bad one causes failure" {
    mkdir -p "$TMP/.github/workflows"
    cat > "$TMP/.github/workflows/good.yml" <<'YML'
name: Good
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "hello"
YML
    cat > "$TMP/.github/workflows/bad.yml" <<'YML'
name: Bad
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo "hello"
        if: ${{ invalid_expression( }}
YML
    run lefthook-actionlint "$TMP/.github/workflows/good.yml" "$TMP/.github/workflows/bad.yml"
    assert_failure
}

@test "mixed yaml and non-yaml files: only yaml checked" {
    mkdir -p "$TMP/.github/workflows"
    cat > "$TMP/.github/workflows/ci.yml" <<'YML'
name: CI
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "hello"
YML
    echo 'not yaml' > "$TMP/data.txt"
    run lefthook-actionlint "$TMP/.github/workflows/ci.yml" "$TMP/data.txt"
    assert_success
}

remote_run_with_stubs() {
    remote="$BATS_TEST_DIRNAME/../../lefthook-remote.yml"
    sh_bin="$(command -v sh)"
    printf '#!%s\nshift\nexec "$@"\n' "$sh_bin" > "$TMP/bin/timeout"
    chmod +x "$TMP/bin/"*
    ran=0
    while IFS= read -r cmd; do
        cmd="${cmd//\{staged_files\}/ci.yml}"
        cmd="${cmd//\{push_files\}/ci.yml}"
        run env PATH="$TMP/bin" "$sh_bin" -c "$cmd"
        assert_success
        [ "$output" = "$1 ci.yml" ]
        ran=$((ran + 1))
    done < <(sed -n 's/^ *run: //p' "$remote")
    [ "$ran" -eq 2 ]
}

@test "lefthook-remote.yml calls the lefthook-actionlint wrapper in every stage" {
    mkdir -p "$TMP/bin"
    printf '#!%s\necho "wrapper $*"\n' "$(command -v sh)" > "$TMP/bin/lefthook-actionlint"
    printf '#!%s\necho "bare $*"\n' "$(command -v sh)" > "$TMP/bin/actionlint"
    remote_run_with_stubs wrapper
}

@test "lefthook-remote.yml falls back to bare actionlint without the wrapper" {
    mkdir -p "$TMP/bin"
    printf '#!%s\necho "bare $*"\n' "$(command -v sh)" > "$TMP/bin/actionlint"
    remote_run_with_stubs bare
}
