#!/usr/bin/env bash
# Download public Google GKI build artifacts (build 13771415, android15-6.6-2025-06_r12) into ./official/
# No login needed: the per-file artifact viewer page embeds a signed storage.googleapis.com URL.
# NOTE: the URL is embedded in the *per-file* page (<base>/<file>). The base index (<base>) is a JS
# shell without "artifactUrl" and is never requested here.
#
# usage: tools/fetch_official_artifacts.sh [--dry-run] [file ...]
#        tools/fetch_official_artifacts.sh --ingest NAME FILE
#        (default: Image can.ko boot-gz.img vmlinux.symvers System.map)
#        --dry-run prints the viewer URL that would be requested for each file and writes nothing
#                  (used by tools/selftest_fetch.sh, invariant V9: the URL tested is the script's own).
#        --ingest publishes FILE under NAME through the same type/hash gate, with no network.
#        FETCH_OUT=/absolute/dir overrides the destination (tests).
#        FETCH_EXTRA_KNOWN=name:hex adds a hash for --ingest only, and cannot replace Image or can.ko.
# A requested name must be one basename: empty, a leading dot, an absolute path, any '/',
# or any '..' is refused before mkdir or curl (item 36). The body is staged in a private
# directory and moved into place only after the type/size check and, when a hash is pinned,
# an exact sha256 (items 37-40). A rejected body is removed. Status words are DOWNLOADED
# plus exactly one of HASH-VERIFIED or UNVERIFIED (item 39).
# Exit 0 = every requested file published, 1 = a body failed, 2 = a name or flag was refused.
set -euo pipefail
BID=13771415
B="https://ci.android.com/builds/submitted/$BID/kernel_aarch64/latest"
if [ -n "${FETCH_OUT:-}" ]; then
  case "$FETCH_OUT" in
    /*) OUT="$FETCH_OUT" ;;
    *) echo "ERRO: FETCH_OUT deve ser um caminho absoluto" >&2; exit 2 ;;
  esac
else
  OUT="$(cd "$(dirname "$0")/.." && pwd)/official"
fi
DO_DRY=0
DO_INGEST=0
INGEST_NAME=""
INGEST_FILE=""
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DO_DRY=1; shift ;;
    --ingest)
      DO_INGEST=1
      INGEST_NAME="${2:-}"
      INGEST_FILE="${3:-}"
      [ -n "$INGEST_NAME" ] && [ -n "$INGEST_FILE" ] || { echo "ERRO: --ingest NOME ARQUIVO" >&2; exit 2; }
      shift 3
      ;;
    --) shift; ARGS+=("$@"); break ;;
    -*) echo "ERRO: opção desconhecida: $1" >&2; exit 2 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
if [ "$DO_DRY" -eq 1 ] && [ "$DO_INGEST" -eq 1 ]; then
  echo "ERRO: --dry-run e --ingest juntos" >&2
  exit 2
fi
FILES=("${ARGS[@]}")
if [ ${#FILES[@]} -eq 0 ] && [ "$DO_INGEST" -eq 0 ]; then
  FILES=(Image can.ko boot-gz.img vmlinux.symvers System.map)
fi

viewer_path() { case "$1" in BUILD_INFO|repo.prop) printf 'view/%s' "$1";; *) printf '%s' "$1";; esac; }

safe_name() { # V76-NAME-GATE
  case "$1" in
    ""|.*|/*|*/*|*..*) return 1;;
  esac
  return 0
}

check_type() { # V76-TYPE-GATE
  python3 - "$1" "$2" <<'PY' || return 1
import sys
name, path = sys.argv[1], sys.argv[2]
data = open(path, "rb").read()
n = len(data)
def die():
    sys.exit(1)
if name == "Image":
    if n < 1048576 or data[56:60] != b"ARM\x64":
        die()
elif name.endswith(".ko"):
    if n < 64 or data[:4] != b"\x7fELF":
        die()
elif name == "boot-gz.img":
    if n < 1024 or not (data[:2] == b"\x1f\x8b" or data[:8] == b"ANDROID!"):
        die()
elif name.endswith(".symvers"):
    line = data.split(b"\n", 1)[0]
    if n < 16 or not line.startswith(b"0x") or b"\t" not in line:
        die()
elif name == "System.map":
    line = data.split(b"\n", 1)[0]
    head = line.split(b" ", 1)[0]
    if n < 16 or not head or any(c not in b"0123456789abcdefABCDEF" for c in head):
        die()
elif name in ("BUILD_INFO", "repo.prop"):
    if n < 8 or b"\0" in data[:64]:
        die()
else:
    die()
sys.exit(0)
PY
  return 0
}

hash_ok() { # V76-HASH-GATE
  [ -z "$1" ] || [ "$1" = "$2" ] || return 1
  return 0
}

STAGE=""
cleanup_stage() {
  if [ -n "${STAGE:-}" ] && [ -d "$STAGE" ]; then
    rm -rf "$STAGE"
  fi
  STAGE=""
}
trap cleanup_stage EXIT

refuse_name() {
  safe_name "$1" || { echo "ERRO: nome recusado: '$1'" >&2; exit 2; }
}

if [ "$DO_INGEST" -eq 1 ] && [ -n "${FETCH_EXTRA_KNOWN:-}" ]; then
  case "$FETCH_EXTRA_KNOWN" in
    Image:*|can.ko:*) echo "ERRO: FETCH_EXTRA_KNOWN não pode substituir um hash pinado" >&2; exit 2 ;;
    *:[0-9a-fA-F]*) ;;
    *) echo "ERRO: FETCH_EXTRA_KNOWN deve ser nome:hex" >&2; exit 2 ;;
  esac
fi

declare -A KNOWN=(
  [Image]="a023b4fdd9d4dd55a5bb06f2fcb46af3d06a9e773c109c5cc6e3e368d83bbaca"
  [can.ko]="5c9a8de421e556a65ee1c1ff3ac53de05806ce5fcc55a31a8a47d92e4f23af43"
)

known_for() {
  local n="$1" en eh
  if [ -n "${KNOWN[$n]:-}" ]; then
    printf '%s' "${KNOWN[$n]}"
    return 0
  fi
  if [ "$DO_INGEST" -eq 1 ] && [ -n "${FETCH_EXTRA_KNOWN:-}" ]; then
    en="${FETCH_EXTRA_KNOWN%%:*}"
    eh="${FETCH_EXTRA_KNOWN#*:}"
    if [ "$n" = "$en" ]; then
      printf '%s' "$eh"
    fi
  fi
}

accept_staged() {
  local n="$1" sum want
  if ! check_type "$n" "$STAGE/body"; then
    cleanup_stage
    echo "ERRO: tipo ou tamanho recusado: $n" >&2
    return 1
  fi
  sum="$(sha256sum "$STAGE/body" | cut -d' ' -f1)"
  want="$(known_for "$n")"
  if ! hash_ok "$want" "$sum"; then
    cleanup_stage
    echo "ERRO: sha256 de $n não confere" >&2
    echo "  esperado: $want" >&2
    echo "  obtido:   $sum" >&2
    return 1
  fi
  mkdir -p "$OUT"
  mv -f "$STAGE/body" "$OUT/$n"
  cleanup_stage
  echo "DOWNLOADED $n"
  if [ -n "$want" ]; then
    echo "HASH-VERIFIED $n"
  else
    echo "UNVERIFIED $n"
  fi
  printf '%s  %s  %s bytes\n' "$sum" "$n" "$(stat -c%s "$OUT/$n")"
}

if [ "$DO_DRY" -eq 1 ]; then
  for f in "${FILES[@]}"; do refuse_name "$f"; done
  for f in "${FILES[@]}"; do printf '%s/%s\n' "$B" "$(viewer_path "$f")"; done
  exit 0
fi

if [ "$DO_INGEST" -eq 1 ]; then
  refuse_name "$INGEST_NAME"
  [ -f "$INGEST_FILE" ] || { echo "ERRO: arquivo de ingest inexistente" >&2; exit 2; }
  STAGE="$(mktemp -d)"
  cp -- "$INGEST_FILE" "$STAGE/body"
  accept_staged "$INGEST_NAME"
  exit 0
fi

UA='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36'
ATTEMPTS="${FETCH_ATTEMPTS:-3}"
SLEEP="${FETCH_SLEEP:-5}"

artifact_url() { # <name> -> prints the signed URL; retries, then a clear human error
  local f="$1" path html url attempt line curl_rc
  path="$(viewer_path "$f")"
  for attempt in $(seq 1 "$ATTEMPTS"); do
    # V78-CURL-GATE: a network failure is not an empty page. No `|| true`.
    html=""
    curl_rc=0
    html="$(curl -fsS -A "$UA" --retry 2 --max-time 60 "$B/$path" 2>/dev/null)" || curl_rc=$?
    if [ "$curl_rc" -ne 0 ]; then
      echo "  tentativa $attempt/$ATTEMPTS: ERRO: curl falhou (exit=$curl_rc) em $B/$path" >&2
      [ "$attempt" -lt "$ATTEMPTS" ] && sleep "$SLEEP"
      continue
    fi
    url=""
    # grep -m1 stops itself (no `head` pipe, so pipefail cannot turn a hit into SIGPIPE).
    if line="$(printf '%s\n' "$html" | grep -m1 -o '"artifactUrl":"[^"]*"')"; then
      url="$(printf '%s\n' "$line" | sed 's/^"artifactUrl":"//;s/"$//;s/\\u0026/\&/g')"
    fi
    if [ -n "$url" ]; then printf '%s' "$url"; return 0; fi
    echo "  tentativa $attempt/$ATTEMPTS: curl ok, sem artifactUrl em $B/$path" >&2
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

rc=0
for f in "${FILES[@]}"; do
  echo "== $f"
  if ! safe_name "$f"; then
    echo "ERRO: nome recusado: '$f'" >&2
    rc=1
    continue
  fi
  url="$(artifact_url "$f")" || { rc=1; continue; }
  STAGE="$(mktemp -d)"
  if ! curl -fsS -A "$UA" --retry 3 --max-time 600 -o "$STAGE/body" "$url"; then
    cleanup_stage
    echo "ERRO: download falhou: $f" >&2
    rc=1
    continue
  fi
  accept_staged "$f" || rc=1
done

if [ "$rc" -ne 0 ]; then
  echo "FALHOU: um ou mais arquivos não foram obtidos/validados (destino: $OUT)" >&2
else
  echo "OK: artefatos em $OUT"
fi
exit "$rc"
