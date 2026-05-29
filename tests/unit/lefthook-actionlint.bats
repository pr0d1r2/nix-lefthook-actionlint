#!/usr/bin/env bats

setup() {
    load "${BATS_LIB_PATH}/bats-support/load.bash"
    load "${BATS_LIB_PATH}/bats-assert/load.bash"

    TMP="$BATS_TEST_TMPDIR"
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
