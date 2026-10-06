#!/usr/bin/env bash
# Download public Google GKI build artifacts (build 13771415, android15-6.6-2025-06_r12) into ./official/
# No login needed: the per-file artifact viewer page embeds a signed storage.googleapis.com URL.
# NOTE: the URL is embedded in the *per-file* page (<base>/<file>). The base index (<base>) is a JS
# shell without "artifactUrl" and is never requested here.
#
# usage: tools/fetch_official_artifacts.sh [file ...]
#        (default: Image can.ko boot-gz.img vmlinux.symvers System.map)
# Exit 0 = every requested file downloaded (and hash-checked when a known hash exists), 1 otherwise.
set -euo pipefail
BID=13771415
B="https://ci.android.com/builds/submitted/$BID/kernel_aarch64/latest"
OUT="$(cd "$(dirname "$0")/.." && pwd)/official"; mkdir -p "$OUT"
FILES=("$@"); [ ${#FILES[@]} -gt 0 ] || FILES=(Image can.ko boot-gz.img vmlinux.symvers System.map)
UA='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36'
ATTEMPTS=3
SLEEP=5

# sha256 of the artifacts this project verified against the device (empty = check not possible)
declare -A KNOWN=(
  [Image]="a023b4fdd9d4dd55a5bb06f2fcb46af3d06a9e773c109c5cc6e3e368d83bbaca"
  [can.ko]="5c9a8de421e556a65ee1c1ff3ac53de05806ce5fcc55a31a8a47d92e4f23af43"
)

artifact_url() { # <name> -> prints the signed URL; retries, then a clear human error
  local f="$1" path html url attempt
  case "$f" in BUILD_INFO|repo.prop) path="view/$f";; *) path="$f";; esac
  for attempt in $(seq 1 "$ATTEMPTS"); do
    html="$(curl -fsS -A "$UA" --retry 2 --max-time 60 "$B/$path" 2>/dev/null || true)"
    url="$(printf '%s' "$html" | grep -o '"artifactUrl":"[^"]*"' | sed -n '1p' \
            | sed 's/^"artifactUrl":"//;s/"$//;s/\\u0026/\&/g' || true)"
    if [ -n "$url" ]; then printf '%s' "$url"; return 0; fi
    echo "  tentativa $attempt/$ATTEMPTS: sem artifactUrl em $B/$path" >&2
    [ "$attempt" -lt "$ATTEMPTS" ] && sleep "$SLEEP"
  done
  cat >&2 <<EOF
ERRO: o viewer não expôs "artifactUrl" para '$f' depois de $ATTEMPTS tentativas.
A página pública pode ter mudado de formato. Baixe manualmente em:
  $B/$path
e salve o conteúdo em: $OUT/$f
(o arquivo baixado à mão deve ter o sha256 esperado; veja o resumo no fim deste script)
EOF
  return 1
}

verify_hash() { # <name> -> 0 ok/unknown, 1 mismatch (nunca apaga o arquivo do usuário)
  local f="$1" want="${KNOWN[$1]:-}" got
  if [ -z "$want" ]; then
    echo "  $f: sem sha256 conhecido publicado (não verificado)"
    return 0
  fi
  got="$(sha256sum "$OUT/$f" | cut -d' ' -f1)"
  if [ "$got" = "$want" ]; then
    echo "  $f: sha256 OK ($want)"
    return 0
  fi
  {
    echo "ERRO: sha256 de $f não confere"
    echo "  esperado: $want"
    echo "  obtido:   $got"
    echo "  (arquivo mantido em $OUT/$f para inspeção; NÃO use sem resolver a divergência)"
  } >&2
  return 1
}

rc=0
for f in "${FILES[@]}"; do
  echo "== $f"
  url="$(artifact_url "$f")" || { rc=1; continue; }
  if ! curl -fsS -A "$UA" --retry 3 --max-time 600 -o "$OUT/$f" "$url"; then
    echo "ERRO: download falhou: $f" >&2
    rc=1; continue
  fi
  verify_hash "$f" || rc=1
  printf '%s  %s  %s bytes\n' "$(sha256sum "$OUT/$f" | cut -c1-64)" "$f" "$(stat -c%s "$OUT/$f")"
done

if [ "$rc" -ne 0 ]; then
  echo "FALHOU: um ou mais arquivos não foram obtidos/validados (destino: $OUT)" >&2
else
  echo "OK: artefatos em $OUT"
fi
exit "$rc"
