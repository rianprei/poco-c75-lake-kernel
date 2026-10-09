#!/usr/bin/env bash
# selftest_fetch_publish.sh — V76: a fetch name cannot escape the destination,
# and a body is published only after the type check and any pinned hash.
# No network. Exit 0 prints V76 PASS.
set -uo pipefail
export LC_ALL=C
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
FETCH="$ROOT/tools/fetch_official_artifacts.sh"
BASE='https://ci.android.com/builds/submitted/13771415/kernel_aarch64/latest'
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
OUT="$WORK/dest"
fails=0

fail() { echo "V76 FAIL $*"; fails=$((fails + 1)); }
ok() { echo "V76 OK $*"; }

# --- names: refused before any write ------------------------------------------
if "$FETCH" --dry-run '../x' >"$WORK/o1" 2>"$WORK/e1"; then
  fail "nome ../x aceito no dry-run"
else
  ok "nome ../x recusado"
fi
if "$FETCH" --dry-run '/etc/passwd' >"$WORK/o2" 2>"$WORK/e2"; then
  fail "nome absoluto aceito no dry-run"
else
  ok "nome absoluto recusado"
fi
if "$FETCH" --dry-run 'a/b' >"$WORK/o3" 2>"$WORK/e3"; then
  fail "nome com barra aceito no dry-run"
else
  ok "nome com barra recusado"
fi
if "$FETCH" --dry-run '..' >"$WORK/o4" 2>"$WORK/e4"; then
  fail "nome .. aceito no dry-run"
else
  ok "nome .. recusado"
fi
if [ -e "$ROOT/official" ]; then
  fail "dry-run de nome ruim criou official/"
else
  ok "official/ do repo continua ausente"
fi

got="$("$FETCH" --dry-run Image 2>"$WORK/e5" | head -1)"
if [ "$got" = "$BASE/Image" ]; then
  ok "dry-run Image intacto"
else
  fail "dry-run Image mudou: ${got:-<vazio>}"
fi

# --- type: garbage is not a symvers candidate ---------------------------------
printf 'not a symvers\n' > "$WORK/garbage"
if FETCH_OUT="$OUT" "$FETCH" --ingest vmlinux.symvers "$WORK/garbage" >"$WORK/g.out" 2>"$WORK/g.err"; then
  fail "lixo publicado como symvers"
else
  ok "lixo de symvers recusado"
fi
if [ -e "$OUT/vmlinux.symvers" ]; then
  fail "candidato lixo ficou no destino"
else
  ok "destino sem candidato lixo"
fi

# --- hash: a well-typed can.ko with the wrong sha256 is not a candidate -------
python3 - "$WORK/elf" <<'PY'
import sys
open(sys.argv[1], "wb").write(b"\x7fELF" + b"\0" * 60)
PY
if FETCH_OUT="$OUT" "$FETCH" --ingest can.ko "$WORK/elf" >"$WORK/k.out" 2>"$WORK/k.err"; then
  fail "can.ko com hash errado foi publicado"
else
  ok "can.ko com hash errado recusado"
fi
if [ -e "$OUT/can.ko" ]; then
  fail "candidato can.ko ficou no destino"
else
  ok "destino sem candidato can.ko"
fi

# --- pinned hash cannot be replaced -------------------------------------------
if FETCH_OUT="$OUT" FETCH_EXTRA_KNOWN="Image:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" \
   "$FETCH" --ingest Image "$WORK/elf" >"$WORK/p.out" 2>"$WORK/p.err"; then
  fail "hash pinado de Image foi substituído"
else
  ok "hash pinado de Image não é substituível"
fi

# --- good symvers: DOWNLOADED + UNVERIFIED, never HASH-VERIFIED ---------------
printf '0x00000001\tfoo\tvmlinux\tEXPORT_SYMBOL\t\n' > "$WORK/sym"
out="$(FETCH_OUT="$OUT" "$FETCH" --ingest vmlinux.symvers "$WORK/sym" 2>"$WORK/s.err")" || fail "symvers bom recusado"
if grep -qx 'DOWNLOADED vmlinux.symvers' <<<"$out"; then ok "DOWNLOADED symvers"; else fail "falta DOWNLOADED"; fi
if grep -qx 'UNVERIFIED vmlinux.symvers' <<<"$out"; then ok "UNVERIFIED symvers"; else fail "falta UNVERIFIED"; fi
if grep -q 'HASH-VERIFIED' <<<"$out"; then fail "symvers sem hash pinado saiu HASH-VERIFIED"; else ok "sem HASH-VERIFIED falso"; fi
if [ -f "$OUT/vmlinux.symvers" ]; then ok "symvers publicado"; else fail "symvers bom não chegou ao destino"; fi

# --- extra known hash on an unpinned name -------------------------------------
sum="$(sha256sum "$WORK/sym" | cut -d' ' -f1)"
out="$(FETCH_OUT="$OUT" FETCH_EXTRA_KNOWN="local.symvers:$sum" "$FETCH" --ingest local.symvers "$WORK/sym" 2>"$WORK/h.err")" \
  || fail "local.symvers com hash certo recusado"
if grep -qx 'HASH-VERIFIED local.symvers' <<<"$out"; then ok "HASH-VERIFIED local.symvers"; else fail "falta HASH-VERIFIED"; fi
if grep -q 'UNVERIFIED' <<<"$out"; then fail "HASH-VERIFIED e UNVERIFIED no mesmo arquivo"; else ok "uma palavra de verificação"; fi

# V78: a curl that exits non-zero must say so. `|| true` used to turn that into
# "sem artifactUrl" and hide the exit code. No network: the stub never connects.
CURLDIR="$(mktemp -d "$WORK/curlbin.XXXXXX")"
cat > "$CURLDIR/curl" <<'EOF'
#!/bin/sh
echo "forced curl failure" >&2
exit 22
EOF
chmod +x "$CURLDIR/curl"
curl_out="$(PATH="$CURLDIR:$PATH" FETCH_OUT="$WORK/curl-dest" FETCH_ATTEMPTS=1 FETCH_SLEEP=0 \
  "$FETCH" Image 2>&1)" || curl_rc=$?
curl_rc="${curl_rc:-0}"
if [ "$curl_rc" -ne 0 ] && grep -q 'curl falhou (exit=22)' <<<"$curl_out"; then
  echo "V78 OK curl failure is reported, not swallowed"
else
  echo "V78 FAIL curl failure hidden or accepted (exit=${curl_rc})"
  printf '%s\n' "$curl_out" | tail -8 | sed 's/^/    /'
  fails=$((fails + 1))
fi
if [ -e "$WORK/curl-dest/Image" ]; then
  echo "V78 FAIL curl failure still published a body"
  fails=$((fails + 1))
fi

if [ "$fails" -eq 0 ]; then
  echo "V76 PASS fetch name gate + atomic publish"
  exit 0
fi
echo "V76 FAIL $fails divergência(s) de publish"
exit 1
