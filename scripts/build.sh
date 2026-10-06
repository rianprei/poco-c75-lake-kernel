#!/usr/bin/env bash
# Exact commands used to produce the verified builds. Host-only: never touches a device.
#   scripts/build.sh sync      download the pinned source (~12 GB, partial clone)
#   scripts/build.sh control   unmodified build -> dist_control (must match Google's symvers/config)
#   scripts/build.sh cert      patched build with Google's module-signing cert embedded -> dist_cert
# Env: WORK (default ~/lake-build), CPUS (default nproc), RAM_MB (default 8000), REPO_NO_VERIFY=1 to skip repo GPG check.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${WORK:-$HOME/lake-build}"; SRC="$WORK/src"; CPUS="${CPUS:-$(nproc)}"; RAM_MB="${RAM_MB:-8000}"
export SOURCE_DATE_EPOCH=1752273969   # committer time of android15-6.6-2025-06_r12 (2025-07-11 22:46:09 UTC)
need() { command -v "$1" >/dev/null || { echo "missing: $1" >&2; exit 1; }; }

cmd_sync() {
  need git; need repo
  mkdir -p "$SRC" && cd "$SRC"
  [ -d .repo ] || repo init -u https://android.googlesource.com/kernel/manifest -b common-android15-6.6-2025-06 \
      --repo-url=https://gerrit.googlesource.com/git-repo --repo-rev=stable --depth=1 ${REPO_NO_VERIFY:+--no-repo-verify}
  # the monthly branch android15-6.6-2025-06 no longer exists upstream: the pinned manifest fetches `common` by TAG
  cp "$HERE/manifests/pinned.xml" .repo/manifests/pinned.xml
  repo init -m pinned.xml --partial-clone --clone-filter=blob:none
  repo sync -c -j3 --no-tags --no-clone-bundle --optimized-fetch --force-sync
  # gate: every critical project must sit on the official revision
  [ "$(git -C common rev-parse HEAD)" = 5a0ffb447c1dbd82e8e3af7a98c4a629f4b6d143 ] || { echo "common revision mismatch" >&2; exit 1; }
  [ "$(git -C build/kernel rev-parse HEAD)" = 4039bcfd1d55f2e9f3d3f34c1815c63b755127b8 ] || { echo "build/kernel revision mismatch" >&2; exit 1; }
  echo "sync OK: kernel $(grep -E '^(VERSION|PATCHLEVEL|SUBLEVEL) ' common/Makefile | awk '{print $3}' | paste -sd.)"
}

bazel_dist() { # <dist_dir>
  cd "$SRC"; mkdir -p "$1"
  tools/bazel run --config=stamp --local_cpu_resources="$CPUS" --local_ram_resources="$RAM_MB" \
      //common:kernel_aarch64_dist -- --dist_dir="$1"
}

cmd_control() { bazel_dist "$WORK/out/dist_control"; }

cmd_cert() {
  cd "$SRC"
  (cd build/kernel && git apply --check "$HERE/patches/0001-kleaf-forward-system_trusted_key.patch" && git apply "$HERE/patches/0001-kleaf-forward-system_trusted_key.patch")
  (cd common && git apply --check "$HERE/patches/0002-common-embed-google-gki-cert.patch" && git apply "$HERE/patches/0002-common-embed-google-gki-cert.patch")
  cp "$HERE/certs/google_gki_ab13771415_modsign_cert.pem" common/google_gki_ab13771415_modsign_cert.pem
  bazel_dist "$WORK/out/dist_cert"
}

case "${1:-}" in sync) cmd_sync;; control) cmd_control;; cert) cmd_cert;; *) sed -n '2,7p' "$0"; exit 2;; esac
