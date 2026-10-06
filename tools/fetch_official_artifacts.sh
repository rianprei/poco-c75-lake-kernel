#!/usr/bin/env bash
# Download public Google GKI build artifacts (build 13771415, android15-6.6-2025-06_r12) into ./official/
# No login needed: the artifact viewer page embeds a signed storage.googleapis.com URL per file.
# usage: tools/fetch_official_artifacts.sh [file ...]   (default: Image can.ko boot-gz.img vmlinux.symvers System.map)
set -euo pipefail
BID=13771415
B="https://ci.android.com/builds/submitted/$BID/kernel_aarch64/latest"
OUT="$(cd "$(dirname "$0")/.." && pwd)/official"; mkdir -p "$OUT"
FILES=("$@"); [ ${#FILES[@]} -gt 0 ] || FILES=(Image can.ko boot-gz.img vmlinux.symvers System.map)
for f in "${FILES[@]}"; do
  case "$f" in BUILD_INFO|repo.prop) path="view/$f";; *) path="$f";; esac
  url=$(curl -fsS --max-time 60 "$B/$path" | grep -o '"artifactUrl":"[^"]*"' | head -1 | sed 's/^"artifactUrl":"//;s/"$//;s/\\u0026/\&/g')
  [ -n "$url" ] || { echo "no artifactUrl for $f" >&2; exit 1; }
  curl -fsS --max-time 600 -o "$OUT/$f" "$url"; printf '%s  %s  %s bytes\n' "$(sha256sum "$OUT/$f" | cut -c1-64)" "$f" "$(stat -c%s "$OUT/$f")"
done
