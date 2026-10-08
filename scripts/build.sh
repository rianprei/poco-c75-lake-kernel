#!/usr/bin/env bash
# Exact commands used to produce the verified builds. Host-only: never touches a device.
#   scripts/build.sh sync      download the pinned source (~12 GB, partial clone)
#   scripts/build.sh control   unmodified build -> dist_control (must match Google's symvers/config)
#   scripts/build.sh cert      patched build with Google's module-signing cert embedded -> dist_cert
#   scripts/build.sh clean     reset the two patched projects to pristine (allows cert->control)
#   scripts/build.sh record <mode>  write build provenance (see item 35)
# Env: WORK (default ~/lake-build), CPUS (default nproc), RAM_MB (default 8000),
#      REPO_NO_VERIFY=1 to skip repo GPG check (strict boolean + explicit WARNING).
#
# State machine (items 28/29: predictable, never silently contaminated):
#   pristine checkout  -> control OK (repeatable) | cert OK once -> contaminated
#   contaminated      -> control REFUSES, cert REFUSES (run clean first)
#   clean             -> pristine again
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${WORK:-$HOME/lake-build}"; SRC="$WORK/src"; CPUS="${CPUS:-$(nproc)}"; RAM_MB="${RAM_MB:-8000}"
export SOURCE_DATE_EPOCH=1752273969   # committer time of android15-6.6-2025-06_r12 (2025-07-11 22:46:09 UTC)
need() { command -v "$1" >/dev/null || { echo "missing: $1" >&2; exit 1; }; }

# --- preflight: canonical disk requirement (item 34: 80 GB free on $WORK) -----------------------
disk_ok() {
  local avail_kb
  avail_kb="$(df -k --output=avail "$WORK" 2>/dev/null | tail -1 | tr -d ' ')"
  [ -n "$avail_kb" ] && [ "$avail_kb" -ge 83886080 ] || {
    echo "disk preflight FAIL: need 80 GB free on $WORK (have ${avail_kb:-?} KiB)" >&2; exit 2; }
}

# --- strict REPO_NO_VERIFY (item 33) --------------------------------------------------------------
repo_verify_flag() {
  case "${REPO_NO_VERIFY:-}" in
    "") printf '%s' "" ;;
    1|true|yes)
      echo "WARNING: repo GPG check SKIPPED by explicit opt-in (REPO_NO_VERIFY=$REPO_NO_VERIFY)" >&2
      printf '%s' "--no-repo-verify" ;;
    *) echo "REPO_NO_VERIFY must be unset or exactly 1/true/yes (got '$REPO_NO_VERIFY')" >&2; exit 2 ;;
  esac
}

pinned_manifest() { printf '%s' "$SRC/.repo/manifests/pinned.xml"; }

# --- validate ALL manifest projects (item 31) ------------------------------------------------------
check_all_projects() { # fails unless every <project path+revision> matches HEAD
  local man bad=0
  man="$(pinned_manifest)"
  [ -f "$man" ] || { echo "manifest not synced: $man" >&2; exit 2; }
  while IFS=$'\t' read -r path rev; do
    [ -n "$path" ] || continue
    if [ ! -d "$SRC/$path" ]; then echo "MISSING project dir: $path" >&2; bad=1; continue; fi
    if [[ "$rev" == refs/tags/* ]]; then
      echo "note: $path pinned by TAG ($rev, mutable metadata) — resolved SHA recorded, not enforced" >&2
      continue
    fi
    if [ "$(git -C "$SRC/$path" rev-parse HEAD 2>/dev/null)" != "$rev" ]; then
      echo "revision mismatch: $path (want $rev)" >&2; bad=1
    fi
  done < <(python3 - "$man" <<'PY'
import sys, xml.etree.ElementTree as ET
t = ET.parse(sys.argv[1])
for p in t.getroot().iter('project'):
    print(f"{p.get('path', '')}\t{p.get('revision', '')}")
PY
)
  [ "$bad" -eq 0 ] || { echo "project revision gate FAIL" >&2; exit 1; }
  echo "all manifest projects match pinned revisions (tags noted, not enforced)"
}

# --- patch-state gates (items 28/29/30) --------------------------------------------------------------
PATCH1="$HERE/patches/0001-kleaf-forward-system_trusted_key.patch"
PATCH2="$HERE/patches/0002-common-embed-google-gki-cert.patch"
patches_applied() { # 0 = both applied, 1 = both absent, 2 = mixed/unknown
  local a=1 b=1
  (cd "$SRC/build/kernel" && git apply --check --reverse "$PATCH1" >/dev/null 2>&1) && a=0
  (cd "$SRC/common" && git apply --check --reverse "$PATCH2" >/dev/null 2>&1) && b=0
  if [ "$a" -eq 0 ] && [ "$b" -eq 0 ]; then return 0; fi
  if [ "$a" -eq 1 ] && [ "$b" -eq 1 ]; then return 1; fi
  return 2
}
require_pristine() { # for control: refuse contaminated trees
  git -C "$SRC/common" status --short | grep -q . && { echo "common dirty — run clean first" >&2; exit 1; } || true
  git -C "$SRC/build/kernel" status --short | grep -q . && { echo "build/kernel dirty — run clean first" >&2; exit 1; } || true
  patches_applied; rc=$?
  [ "$rc" -eq 1 ] || { echo "patches already applied (state=$rc) — control needs pristine; run clean first" >&2; exit 1; }
}

cmd_sync() {
  need git; need repo
  disk_ok
  local noverify
  noverify="$(repo_verify_flag)"
  mkdir -p "$SRC" && cd "$SRC"
  [ -d .repo ] || repo init -u https://android.googlesource.com/kernel/manifest -b common-android15-6.6-2025-06 \
      --repo-url=https://gerrit.googlesource.com/git-repo --repo-rev=stable --depth=1 $noverify
  # the monthly branch android15-6.6-2025-06 no longer exists upstream: the pinned manifest fetches `common` by TAG
  cp "$HERE/manifests/pinned.xml" .repo/manifests/pinned.xml
  repo init -m pinned.xml --partial-clone --clone-filter=blob:none
  repo sync -c -j3 --no-tags --no-clone-bundle --optimized-fetch --force-sync
  check_all_projects
  # record resolved SHAs (item 32: tags are metadata; the SHA is what matters)
  {
    echo "manifest_sha256=$(sha256sum .repo/manifests/pinned.xml | cut -d' ' -f1)"
    echo "common_HEAD=$(git -C common rev-parse HEAD)"
    echo "common_tag_requested=refs/tags/android15-6.6-2025-06_r12"
  } > "$WORK/sync-record.txt"
  echo "sync OK: kernel $(grep -E '^(VERSION|PATCHLEVEL|SUBLEVEL) ' common/Makefile | awk '{print $3}' | paste -sd.)"
}

cmd_clean() {
  cd "$SRC"
  (cd build/kernel && git checkout -- .)
  (cd common && git checkout -- .)
  # remove ONLY our copied cert, and only if untracked (V6-clean by construction:
  # no rm; git clean on one verified path cannot touch anything else)
  if git -C common status --short google_gki_ab13771415_modsign_cert.pem | grep -q '^\?\?'; then
    git -C common clean -f -q -- google_gki_ab13771415_modsign_cert.pem
  fi
  echo "clean OK: both projects pristine"
}

bazel_dist() { # <dist_dir>
  cd "$SRC"; mkdir -p "$1"
  tools/bazel run --config=stamp --local_cpu_resources="$CPUS" --local_ram_resources="$RAM_MB" \
      //common:kernel_aarch64_dist -- --dist_dir="$1"
}

cmd_record() { # <mode> — provenance file (item 35)
  local mode="${1:?usage: build.sh record <mode>}"
  local f="$WORK/out/build-record-$mode.txt"
  mkdir -p "$WORK/out"
  {
    echo "mode=$mode"
    echo "date_utc=$(date -u +%FT%TZ)"
    echo "source_date_epoch=$SOURCE_DATE_EPOCH"
    echo "command=$0 $* (WORK=$WORK CPUS=$CPUS RAM_MB=$RAM_MB)"
    echo "manifest_sha256=$(sha256sum "$HERE/manifests/pinned.xml" | cut -d' ' -f1)"
    if [ -d "$SRC/.repo" ]; then
      echo "--- synced projects (path HEAD) ---"
      while IFS=$'\t' read -r path _rev; do
        [ -n "$path" ] && [ -d "$SRC/$path" ] && \
          echo "$path $(git -C "$SRC/$path" rev-parse HEAD 2>/dev/null || echo MISSING)"
      done < <(python3 - "$SRC/.repo/manifests/pinned.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
t = ET.parse(sys.argv[1])
for p in t.getroot().iter('project'):
    print(f"{p.get('path', '')}\t{p.get('revision', '')}")
PY
)
    else
      echo "not-synced (no $SRC/.repo)"
    fi
    echo "--- tool versions ---"
    for t in git python3 openssl avbtool curl repo; do
      command -v "$t" >/dev/null && echo "$t $($t --version 2>&1 | head -1)" || echo "$t MISSING"
    done
    [ -x "$SRC/tools/bazel" ] && echo "bazel $($SRC/tools/bazel --version 2>/dev/null | head -1)" || echo "bazel MISSING-or-unbuilt"
    echo "--- kleaf/config ---"
    echo "kleaf_HEAD=$(git -C "$SRC/build/kernel" rev-parse HEAD 2>/dev/null || echo MISSING)"
    echo "common_HEAD=$(git -C "$SRC/common" rev-parse HEAD 2>/dev/null || echo MISSING)"
  } > "$f"
  echo "record written: $f"
}

cmd_control() {
  disk_ok; require_pristine
  bazel_dist "$WORK/out/dist_control"
  cmd_record control
}

cmd_cert() {
  disk_ok; require_pristine
  cd "$SRC"
  (cd build/kernel && git apply --check "$PATCH1" && git apply "$PATCH1")
  (cd common && git apply --check "$PATCH2" && git apply "$PATCH2")
  cp "$HERE/certs/google_gki_ab13771415_modsign_cert.pem" common/google_gki_ab13771415_modsign_cert.pem
  bazel_dist "$WORK/out/dist_cert"
  cmd_record cert
}

case "${1:-}" in
  sync) cmd_sync;; control) cmd_control;; cert) cmd_cert;;
  clean) cmd_clean;; record) cmd_record "${2:?usage: build.sh record <mode>}" ;;
  *) sed -n '2,7p' "$0"; exit 2;;
esac
