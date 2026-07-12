#!/usr/bin/env bash
#
# mayhem/test.sh — behavioral known-answer oracle for the blurhash C implementation.
#
# Upstream ships NO runnable test suite for the C code (the only tests in the repo are
# Kotlin androidTest / Swift Xcode UI targets, unusable headless), so this is an AUTHORED
# known-answer/golden-output oracle over the upstream CLIs that build.sh pre-built with
# upstream's normal Makefile flags (/mayhem/out/blurhash_{encoder,decoder}).
# Golden values were captured from these exact binaries in this image.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "$SRC"

emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

ENC=/mayhem/out/blurhash_encoder
DEC=/mayhem/out/blurhash_decoder
for b in "$ENC" "$DEC"; do
  if [ ! -x "$b" ]; then
    echo "FATAL: $b missing — build.sh must build the oracle binaries" >&2
    emit_ctrf blurhash-kat 0 1
    exit 1
  fi
done

PASS=0; FAIL=0
check() { # check <name> <expected> <actual>
  if [ "$2" = "$3" ]; then
    PASS=$((PASS+1)); echo "PASS: $1"
  else
    FAIL=$((FAIL+1)); echo "FAIL: $1 — expected [$2] got [$3]"
  fi
}

IMG="$SRC/mayhem/blurhash_encoder/testsuite/test.png"

# 1-3) Known-answer encodes: fixed image + component counts -> exact hash strings.
check "encode 4x3 test.png" 'LRA],3nW0yb,pKnWoabnADa$-Bfh' "$("$ENC" 4 3 "$IMG" 2>/dev/null)"
check "encode 8x8 test.png" ':RA],3nW0yb,#jR%W?n-pKnWoabnMxayt7jJADa$-BfhJ6ofj]WBV?W,WEn-tQoMjtbFVYbWbujKkDj@s.jvsRobR-WEt6j?WCn-nioeX7WCnjayX7oMWCj@oejHfkbHWCbE' "$("$ENC" 8 8 "$IMG" 2>/dev/null)"
check "encode 1x1 test.png" '00A],3' "$("$ENC" 1 1 "$IMG" 2>/dev/null)"

# 4) Encoder rejects out-of-range component counts (asserted stderr text + exit code).
out=$("$ENC" 9 3 "$IMG" 2>&1); rc=$?
check "encode rejects x=9" "1:Component counts must be between 1 and 8." "$rc:$out"

# 5-6) Known-answer decode: fixed hash -> exact PNG bytes (sha256 golden).
rm -f /tmp/kat-out.png
out=$("$DEC" 'LEHV6nWB2yk8pyo0adR*.7kCMdnj' 32 32 /tmp/kat-out.png 2>&1)
check "decode stdout" "Decoded blurhash successfully, wrote PNG file /tmp/kat-out.png" "$out"
check "decode png sha256" "f3beb9defd97ff01698992195a57b1aba7afc6de2d30836c2a21b24989290fae" "$(sha256sum /tmp/kat-out.png | cut -d' ' -f1)"

# 7) Decoder rejects an invalid blurhash (wrong length/charset).
out=$("$DEC" 'notavalidhash' 32 32 /tmp/kat-bad.png 2>&1); rc=$?
check "decode rejects invalid hash" "1:notavalidhash is not a valid blurhash, decoding failed." "$rc:$out"

# 8) Round-trip: decode(encode(img)) re-encodes to the same hash (fixpoint golden).
h1=$("$ENC" 4 4 "$IMG" 2>/dev/null)
rm -f /tmp/kat-rt.png
"$DEC" "$h1" 64 64 /tmp/kat-rt.png >/dev/null 2>&1
check "roundtrip re-encode" 'UOBV^onW0yb,pKjLf4boADa#$jfiaJWna#jc' "$("$ENC" 4 4 /tmp/kat-rt.png 2>/dev/null)"

emit_ctrf blurhash-kat "$PASS" "$FAIL"
