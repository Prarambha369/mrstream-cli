#!/usr/bin/env bats

setup() {
    . src/core/cache.sh
    CACHE_DIR="/tmp/mrstream_test_cache"
    mkdir -p "$CACHE_DIR"
}

teardown() {
    rm -rf "$CACHE_DIR"
}

@test "cache_path generation" {
    path=$(get_cache_path "test")
    [ "$path" = "$CACHE_DIR/test.cache" ]
}

@test "cache validation logic" {
    file="$CACHE_DIR/test.cache"
    touch "$file"
    is_cache_valid "$file"
}
