#!/usr/bin/env bash
# verify_modsig.sh — prova offline de assinatura de módulo GKI (sem aparelho, sem flash).
# Uso:
#   verify_modsig.sh <Image> <modulo.ko> [workdir]   (workdir opcional; default = mktemp -d, removido no fim)
#   verify_modsig.sh --selftest   # positivo (can.ko oficial) + negativo (módulo adulterado)
# Método:
#   1) Extrai a assinatura PKCS#7 do fim do .ko (struct module_signature + magic).
#   2) Garimpa certificados DER do Image (toda SEQUENCE válida que o openssl aceita
#      como X.509).
#   3) openssl cms -verify do conteúdo do módulo contra cada cert garimpado, E a
#      identidade do signatário declarada no PKCS#7 (issuer+serial) tem que ser a
#      do cert que validou (método B real).
#   PASS = algum cert do Image valida E a identidade do signatário confere; FAIL
#   caso contrário. Isto prova offline a cadeia cert↔assinatura; não diz nada
#   sobre o comportamento do keyring em runtime (item 53).
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


def die(msg):
    sys.stderr.write(f'ERRO: {msg} (sem traceback)\n')
    sys.exit(3)


i = data.rfind(magic)
if i < 12:
    die('módulo sem assinatura (sem magic de assinatura nos últimos bytes)')
ms = data[i-12:i]
try:
    algo, h, idt, slen, klen, siglen = struct.unpack('>BBBBB3xI', ms)
except struct.error:
    die('assinatura truncada/corrompida')
# struct é: u8 algo,hash,id_type,signer_len,key_id_len, __be32 sig_len
if siglen <= 0 or i - 12 - siglen < 0:
    die(f'sig_len inválido ({siglen})')
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
    # V79: openssl failure and a missing issuer line are printed. Nothing here is `|| true`.
    diag_rc=0
    diag_out="$(openssl cms -inform DER -in "$SIG" -cmsout -print 2>&1)" || diag_rc=$?
    if [ "$diag_rc" -ne 0 ]; then
      echo "      diagnóstico: openssl cms -print falhou (exit=$diag_rc)"
    elif printf '%s\n' "$diag_out" | grep -a -m2 -iE 'serial|issuer' >"$work/diag.txt"; then
      sed 's/^/      /' "$work/diag.txt"
    else
      echo "      diagnóstico: issuer/serial ausentes na saída cms -print"
    fi
    echo "[3/3] verificando assinatura contra cada cert do Image..."
    # Método B real (item 49): a identidade do signatário declarada no PKCS#7
    # (issuer+serial) tem que ser a do cert que valida — não basta "algum cert valida".
    # Extração canônica "issuer|serial" dos dois lados (minúsculas, só [a-z0-9]).
    signer_id="$(openssl cms -inform DER -in "$SIG" -cmsout -print 2>/dev/null | awk '
        /serialNumber:/ { gsub(/.*0[xX]/, ""); sn=$0 }
        /issuer:/ && !done { sub(/.*issuer:[[:space:]]*/, ""); iss=$0; done=1 }
        END { print tolower(iss) "|" tolower(sn) }' | tr -cd 'a-z0-9|')"
    for c in "${CERTS[@]}"; do
        if verify_one "$CONTENT" "$SIG" "$c"; then
            cert_id="$(openssl x509 -inform DER -in "$c" -noout -issuer -serial 2>/dev/null \
                | sed -e 's/^issuer=//' -e 's/^serial=//' | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9\n' | paste -sd'|' -)"
            if [ -n "$signer_id" ] && [ "$signer_id" = "$cert_id" ]; then
                echo "PASS: $ko validado por cert do Image: $c (signatário confere)"
                return 0
            else
                echo "      - valida criptograficamente com $c mas signatário difere (segue procurando)"
            fi
        else
            echo "      - não valida com $c"
        fi
    done
    echo "FAIL: nenhum cert do Image valida $ko com identidade do signatário"
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
with open(p, 'rb') as f:
    d = bytearray(f.read())
d[1000] ^= 0x01
with open(p, 'wb') as f:
    f.write(d)
PY
    if cmd_verify "$SELFTEST_IMAGE" "$work/neg/can_bad.ko" "$work/neg_out"; then
        echo 'FAIL DO TESTE: módulo adulterado validou (inaceitável)'
        return 1
    else
        echo 'OK negativo: adulterado rejeitado como esperado'
    fi
    echo 'SELFTEST PASS (positivo PASS + negativo FAIL)'
}

cmd_selftest_full() { # matriz sintética offline (item 52): chaves/módulos gerados aqui
    local work="${SELFTEST_WORK:-}"
    if [ -z "$work" ]; then new_tmpwork; work="$TMPWORK"; fi
    mkdir -p "$work/full"
    local fails=0 n_ok=0
    # duas identidades: (k1,c1) e (k2,c2 com MESMO subject CN, outra chave)
    openssl req -x509 -newkey rsa:2048 -nodes -keyout "$work/full/k1.key" \
        -out "$work/full/c1.crt" -days 2 -subj "/CN=unittest-signer/" 2>/dev/null
    openssl req -x509 -newkey rsa:2048 -nodes -keyout "$work/full/k2.key" \
        -out "$work/full/c2.crt" -days 2 -subj "/CN=unittest-signer/" 2>/dev/null
    openssl x509 -in "$work/full/c1.crt" -outform DER -out "$work/full/c1.der" 2>/dev/null
    openssl x509 -in "$work/full/c2.crt" -outform DER -out "$work/full/c2.der" 2>/dev/null
    printf 'fake-module-content-0123456789' > "$work/full/content.bin"
    openssl cms -sign -binary -in "$work/full/content.bin" -outform DER \
        -signer "$work/full/c1.crt" -inkey "$work/full/k1.key" -nocerts \
        -out "$work/full/sig1.der" 2>/dev/null
    openssl cms -sign -binary -in "$work/full/content.bin" -outform DER \
        -signer "$work/full/c2.crt" -inkey "$work/full/k2.key" -nocerts \
        -out "$work/full/sig2.der" 2>/dev/null
    mkmod() { # <content> <sig.der> <out.ko>
        python3 - "$1" "$2" "$3" <<'PY'
import struct, sys
with open(sys.argv[1], 'rb') as f:
    content = f.read()
with open(sys.argv[2], 'rb') as f:
    sig = f.read()
info = struct.pack('>BBBBB3xI', 1, 2, 0, len(b'signer'), 0, len(sig))
with open(sys.argv[3], 'wb') as f:
    f.write(content + sig + info + b'~Module signature appended~\n')
PY
    }
    mkimg() { # <der-cert-ou-vazio> <out.img>
        python3 -c "import sys; open('$2','wb').write(b'\0'*512 + open('$1','rb').read() + b'\0'*512)" 2>/dev/null || \
            python3 -c "open('$2','wb').write(b'\0'*1024)"
    }
    mkmod "$work/full/content.bin" "$work/full/sig1.der" "$work/full/mod_ok.ko"
    mkimg "$work/full/c1.der" "$work/full/img_ok.img"
    full_case() { # <n> <label> <want-rc> <img> <ko>
        local n="$1" label="$2" want="$3" out rc
        printf '### [%s] %s\n' "$n" "$label"
        out="$(cmd_verify "$4" "$5" "$work/full/w$n" 2>&1)" && rc=0 || rc=$?
        if [ "$rc" -eq "$want" ]; then printf '  => OK (exit=%s)\n\n' "$rc"; n_ok=$((n_ok + 1));
        else printf '  => FALHA (exit=%s, esperado %s)\n%s\n\n' "$rc" "$want" "$out"; fails=$((fails + 1)); fi
    }
    full_case 1 "signatário correto valida" 0 "$work/full/img_ok.img" "$work/full/mod_ok.ko"
    mkmod "$work/full/content.bin" "$work/full/sig2.der" "$work/full/mod_k2.ko"
    full_case 2 "signatário errado rejeitado" 1 "$work/full/img_ok.img" "$work/full/mod_k2.ko"
    python3 -c "d=bytearray(open('$work/full/mod_ok.ko','rb').read()); d[10]^=1; open('$work/full/mod_bad.ko','wb').write(bytes(d))"
    full_case 3 "conteúdo modificado rejeitado" 1 "$work/full/img_ok.img" "$work/full/mod_bad.ko"
    python3 -c "d=bytearray(open('$work/full/mod_ok.ko','rb').read()); d[-30]^=1; open('$work/full/mod_badsig.ko','wb').write(bytes(d))"
    full_case 4 "assinatura modificada rejeitada" 1 "$work/full/img_ok.img" "$work/full/mod_badsig.ko"
    mkimg "" "$work/full/img_empty.img"
    full_case 5 "cert ausente rejeitado limpo" 1 "$work/full/img_empty.img" "$work/full/mod_ok.ko"
    mkimg "$work/full/c2.der" "$work/full/img_samecn.img"
    full_case 6 "mesmo issuer, outra chave rejeitado" 1 "$work/full/img_samecn.img" "$work/full/mod_ok.ko"
    # V67-EXPIRED: openssl cms -verify rejects notAfter in the past (proved: exit 4, "certificate has expired").
    openssl req -x509 -newkey rsa:2048 -nodes -keyout "$work/full/kexp.key" \
        -out "$work/full/cexp.crt" -subj "/CN=unittest-expired/" \
        -not_before 20200101000000Z -not_after 20200102000000Z 2>/dev/null
    openssl x509 -in "$work/full/cexp.crt" -outform DER -out "$work/full/cexp.der" 2>/dev/null
    openssl cms -sign -binary -in "$work/full/content.bin" -outform DER \
        -signer "$work/full/cexp.crt" -inkey "$work/full/kexp.key" -nocerts \
        -out "$work/full/sigexp.der" 2>/dev/null
    mkmod "$work/full/content.bin" "$work/full/sigexp.der" "$work/full/mod_exp.ko"
    mkimg "$work/full/cexp.der" "$work/full/img_exp.img"
    full_case 7 "cert expirado rejeitado" 1 "$work/full/img_exp.img" "$work/full/mod_exp.ko" # V67-EXPIRED
    # V67-NOTYET: notBefore in the future is rejected ("certificate is not yet valid").
    openssl req -x509 -newkey rsa:2048 -nodes -keyout "$work/full/kfut.key" \
        -out "$work/full/cfut.crt" -subj "/CN=unittest-future/" \
        -not_before 20300101000000Z -not_after 20310101000000Z 2>/dev/null
    openssl x509 -in "$work/full/cfut.crt" -outform DER -out "$work/full/cfut.der" 2>/dev/null
    openssl cms -sign -binary -in "$work/full/content.bin" -outform DER \
        -signer "$work/full/cfut.crt" -inkey "$work/full/kfut.key" -nocerts \
        -out "$work/full/sigfut.der" 2>/dev/null
    mkmod "$work/full/content.bin" "$work/full/sigfut.der" "$work/full/mod_fut.ko"
    mkimg "$work/full/cfut.der" "$work/full/img_fut.img"
    full_case 8 "cert ainda não válido rejeitado" 1 "$work/full/img_fut.img" "$work/full/mod_fut.ko" # V67-NOTYET
    if [ "$fails" -eq 0 ] && [ "$n_ok" -eq 8 ]; then
      echo 'V67 OK modsig synthetic matrix (8/8: signer ok/errado, conteúdo/assinatura, cert ausente, mesmo issuer, cert expirado, cert ainda não válido)'
      echo 'SELFTEST-FULL PASS (8/8)'
      return 0
    fi
    echo 'V67 FAIL modsig synthetic matrix'
    echo "SELFTEST-FULL FAIL (fails=$fails ok=$n_ok, esperado 8)"
    return 1
}

case "${1:-}" in
    --selftest) cmd_selftest ;;
    --selftest-full) cmd_selftest_full ;;
    -h|--help) sed -n '2,12p' "$0" ;;
    *) [ $# -ge 2 ] || { echo "uso: $0 <Image> <mod.ko> [workdir] | $0 --selftest"; exit 2; }
       cmd_verify "$1" "$2" "${3:-}" ;;
esac
