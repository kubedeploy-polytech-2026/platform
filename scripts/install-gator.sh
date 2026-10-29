#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
platform="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$(uname -m)" in
  x86_64) arch=amd64 ;;
  arm64|aarch64) arch=arm64 ;;
  *) echo 'Unsupported architecture' >&2; exit 1 ;;
esac
case "$platform-$arch" in
  darwin-amd64) checksum=4318b3ce4bc115ed861ff4a1df26ad1ddf3ae0c7907f20caac85affd400af39e ;;
  darwin-arm64) checksum=dc96df4a0bad0427b36d2b10473801528ca5bdb00f2addb34d17bb7d706ed99b ;;
  linux-amd64) checksum=c268d7b809c9fe59a110ab0bf7c296ab00b0b6c894c209cd15e94194590291bb ;;
  linux-arm64) checksum=2d4bd0e28e708c2893a66fdca652f1d775b23fc5a3c07571fd314ba06d19ff2b ;;
  *) echo 'Unsupported platform' >&2; exit 1 ;;
esac
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
archive="$work_dir/gator.tar.gz"
curl --fail --silent --show-error --location --retry 3 \
  "https://github.com/open-policy-agent/gatekeeper/releases/download/v3.23.1/gator-v3.23.1-$platform-$arch.tar.gz" -o "$archive"
python3 - "$archive" "$checksum" <<'PY'
import hashlib,sys
from pathlib import Path
if hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest() != sys.argv[2]:
    raise SystemExit('Gator archive checksum mismatch')
PY
tar -xzf "$archive" -C "$work_dir"
mkdir -p "$project_root/.tools/bin"
install -m 755 "$work_dir/gator" "$project_root/.tools/bin/gator"
