#!/usr/bin/env bash
#
# mayhem/build.sh — build the blurhash C fuzz harnesses + the KAT oracle binaries.
#
# Builds:
#   1) sanitized libFuzzer harnesses:  /mayhem/blurhash_encoder, /mayhem/blurhash_decoder
#   2) standalone run-once reproducers: /mayhem/<fuzzer>-standalone
#   3) the KAT oracle binaries (upstream CLIs, upstream's NORMAL Makefile flags):
#      /mayhem/out/blurhash_encoder, /mayhem/out/blurhash_decoder — test.sh only RUNS them.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"

# 1+2) Sanitized, DWARF-3 instrumented library + harnesses (project code compiled with
#      $SANITIZER_FLAGS so the fuzzed code itself is instrumented).
for h in blurhash_encoder blurhash_decoder; do
	# shellcheck disable=SC2086
	$CC $SANITIZER_FLAGS $DEBUG_FLAGS $LIB_FUZZING_ENGINE -I"$SRC/C" \
		"$SRC/mayhem/$h.c" "$SRC/C/encode.c" "$SRC/C/decode.c" -lm \
		-o "/mayhem/$h"
	# shellcheck disable=SC2086
	$CC $SANITIZER_FLAGS $DEBUG_FLAGS "$STANDALONE_FUZZ_MAIN" -I"$SRC/C" \
		"$SRC/mayhem/$h.c" "$SRC/C/encode.c" "$SRC/C/decode.c" -lm \
		-o "/mayhem/$h-standalone"
done

# 3) KAT oracle binaries: the upstream CLIs, built with upstream's own Makefile (normal
#    flags, no sanitizers) into a separate out/ tree so test.sh never compiles.
mkdir -p /mayhem/out
make -C "$SRC/C" clean
# shellcheck disable=SC2086
make -C "$SRC/C" CC="$CC $COVERAGE_FLAGS" blurhash_encoder blurhash_decoder
cp "$SRC/C/blurhash_encoder" "$SRC/C/blurhash_decoder" /mayhem/out/
make -C "$SRC/C" clean
