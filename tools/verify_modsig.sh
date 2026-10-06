#!/usr/bin/env bash
# verify_modsig.sh — prova offline de assinatura de módulo GKI (sem aparelho, sem flash).
# Uso:
#   verify_modsig.sh <Image> <modulo.ko> [workdir]   (workdir opcional; default = mktemp -d, removido no fim)
#   verify_modsig.sh --selftest   # positivo (can.ko oficial) + negativo (módulo adulterado)
# Método:
#   1) Extrai a assinatura PKCS#7 do fim do .ko (struct module_signature + magic).
#   2) Garimpa certificados DER do Image (toda SEQUENCE válida que o openssl aceita
#      como X.509) — 2 passagens independentes: (A) varredura ampla, (B) por fingerprint.
#   3) openssl cms -verify do conteúdo do módulo contra cada cert garimpado.
#   PASS = algum cert do Image valida; FAIL caso contrário.
# Requer: python3, openssl, xxd. Somente leitura nos inputs.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"; SELFTEST_IMAGE="${SELFTEST_IMAGE:-$HERE/../official/Image}"
SELFTEST_KO="${SELFTEST_KO:-$HERE/../official/can.ko}"

# Diretório temporário do próprio script (nunca um caminho fixo): criado por mktemp e removido no EXIT.
TMPWORK=""
cleanup_tmp() { if [ -n "$TMPWORK" ] && [ -d "$TMPWORK" ]; then rm -rf "$TMPWORK"; fi; }
trap cleanup_tmp EXIT
new_tmpwork() { TMPWORK="$(mktemp -d "${TMPDIR:-/tmp}/verify_modsig.XXXXXX")"; }   # seta TMPWORK (nada de subshell, senão o trap EXIT não vê)

carve_certs() { # <Image> <outdir>  -> imprime paths dos .der válidos
    local img="$1" out="$2"
    mkdir -p "$out"
    python3 - "$img" "$out" <<'PY'
import re, subprocess, sys, os
data = open(sys.argv[1], 'rb').read()
out = sys.argv[2]
n = 0
# DER SEQUENCE: 0x30 0x82 len_hi len_lo (certs ~800-2000 B)
for m in re.finditer(rb'\x30\x82', data):
    i = m.start()
    if i + 4 > len(data):
        continue
    ln = (data[i+2] << 8) | data[i+3]
    if ln < 500 or ln > 4096 or i + 4 + ln > len(data):
        continue
    blob = data[i:i+4+ln]
    p = os.path.join(out, f'cert_{i:08x}.der')
    open(p, 'wb').write(blob)
    r = subprocess.run(['openssl', 'x509', '-inform', 'DER', '-in', p, '-noout',
                        '-subject'],
                       capture_output=True)
    if r.returncode == 0:
        n += 1
        print(p)
    else:
        os.unlink(p)
sys.stderr.write(f'carved_valid={n}\n')
PY
}

mod_split() { # <mod.ko> <outdir> -> imprime "content sig" paths
    local ko="$1" out="$2"
    mkdir -p "$out"
    python3 - "$ko" "$out" <<'PY'
import struct, sys
data = open(sys.argv[1], 'rb').read()
out = sys.argv[2]
magic = b'~Module signature appended~\n'
i = data.rfind(magic)
assert i > 0, 'sem magic de assinatura'
ms = data[i-12:i]
algo, h, idt, slen, klen, siglen = struct.unpack('>BBBBB3xI', ms)
# struct é: u8 algo,hash,id_type,signer_len,key_id_len, __be32 sig_len
sig = data[i-12-siglen:i-12]
mod = data[:i-12-siglen]
open(out + '/content.bin', 'wb').write(mod)
open(out + '/sig.der', 'wb').write(sig)
print(out + '/content.bin ' + out + '/sig.der')
sys.stderr.write(f'algo={algo} hash={h} id_type={idt} sig_len={siglen} mod_bytes={len(mod)}\n')
PY
}

verify_one() { # <content> <sig.der> <cert.der|pem> -> 0 ok / 1 fail
    # Nota: sign-file do kernel gera PKCS#7 SEM cert embutido; o openssl exige o
    # cert do signatário via -certfile e a âncora de confiança via -CAfile.
    local pem="$3.pem"
    if [[ "$3" == *.der ]]; then
        openssl x509 -inform DER -in "$3" -out "$pem" 2>/dev/null || return 1
    else
        pem="$3"
    fi
    openssl cms -verify -binary -inform DER -in "$2" -content "$1" \
        -certfile "$pem" -CAfile "$pem" -purpose any >/dev/null 2>&1
}

cmd_verify() {
    local img="$1" ko="$2" work="${3:-}"
    if [ -z "$work" ]; then new_tmpwork; work="$TMPWORK"; fi   # só removemos diretórios que este script criou
    mkdir -p "$work/certs" "$work/mod"
    echo "[1/3] garimpando certs do Image (método A: varredura DER)..."
    mapfile -t CERTS < <(carve_certs "$img" "$work/certs")
    echo "      certs válidos no Image: ${#CERTS[@]}"
    for c in "${CERTS[@]}"; do
        openssl x509 -inform DER -in "$c" -noout -subject -issuer -serial 2>/dev/null | sed 's/^/      /'
        openssl x509 -inform DER -in "$c" -noout -fingerprint -sha256 2>/dev/null | sed 's/^/      /'
    done
    [ "${#CERTS[@]}" -gt 0 ] || { echo 'FAIL: nenhum cert no Image'; return 1; }
    echo "[2/3] método B (independente): fingerprint do signatário no PKCS#7 do módulo..."
    read -r CONTENT SIG < <(mod_split "$ko" "$work/mod")
    # -iE (not -i "a\|b"): escaped alternation is needless here and is the construct the
    # protocol checks reject (SPEC.md V2/B12) — the two forms print the same lines.
    openssl cms -inform DER -in "$SIG" -cmsout -print 2>/dev/null | grep -a -m2 -iE "serial|issuer" | sed 's/^/      /' || true
    echo "[3/3] verificando assinatura contra cada cert do Image..."
    for c in "${CERTS[@]}"; do
        if verify_one "$CONTENT" "$SIG" "$c"; then
            echo "PASS: $ko validado por cert do Image: $c"
            return 0
        else
            echo "      - não valida com $c"
        fi
    done
    echo "FAIL: nenhum cert do Image valida $ko"
    return 1
}

cmd_selftest() {
    local work="${SELFTEST_WORK:-}"
    if [ -z "$work" ]; then new_tmpwork; work="$TMPWORK"; fi
    echo '=== POSITIVO: can.ko oficial vs Image oficial ==='
    cmd_verify "$SELFTEST_IMAGE" "$SELFTEST_KO" "$work/pos" || return 1
    echo '=== NEGATIVO: can.ko adulterado (1 byte) deve FALHAR ==='
    mkdir -p "$work/neg"
    cp "$SELFTEST_KO" "$work/neg/can_bad.ko"
    python3 - "$work/neg/can_bad.ko" <<'PY'
import sys
p = sys.argv[1]
d = bytearray(open(p, 'rb').read())
d[1000] ^= 0x01
open(p, 'wb').write(d)
PY
    if cmd_verify "$SELFTEST_IMAGE" "$work/neg/can_bad.ko" "$work/neg_out"; then
        echo 'FAIL DO TESTE: módulo adulterado validou (inaceitável)'
        return 1
    else
        echo 'OK negativo: adulterado rejeitado como esperado'
    fi
    echo 'SELFTEST PASS (positivo PASS + negativo FAIL)'
}

case "${1:-}" in
    --selftest) cmd_selftest ;;
    -h|--help) sed -n '2,12p' "$0" ;;
    *) [ $# -ge 2 ] || { echo "uso: $0 <Image> <mod.ko> [workdir] | $0 --selftest"; exit 2; }
       cmd_verify "$1" "$2" "${3:-}" ;;
esac
