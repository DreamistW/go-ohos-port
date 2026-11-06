#!/usr/bin/env bash
# 下载已锁定的公开 SDK 镜像，只解出 Linux native 组件。
set -euo pipefail

[[ $# == 1 ]] || { echo "Usage: $0 <new SDK directory>" >&2; exit 2; }
mkdir -- "$1"
cd -- "$1"
base=https://github.com/openharmony-rs/ohos-sdk/releases/download/v7.0
archive=ohos-sdk-windows_linux-public.tar.gz
curl --fail --location --retry 3 --silent --show-error -o "$archive.aa" "$base/$archive.aa"
curl --fail --location --retry 3 --silent --show-error -o "$archive.ab" "$base/$archive.ab"
sha256sum -c <<'SUMS'
e75e3c63e62bc0ca696f44205566fbd9b55f7cac34cd2e697e2c55a7d0a69621  ohos-sdk-windows_linux-public.tar.gz.aa
ec4457844ae794487078050cfd5ac3d3d5ff56da638fbae5c7220e1b98697436  ohos-sdk-windows_linux-public.tar.gz.ab
SUMS
cat "$archive.aa" "$archive.ab" | python3 -c '
import shutil, sys, tarfile
from pathlib import PurePosixPath

found = False
with tarfile.open(fileobj=sys.stdin.buffer, mode="r|gz") as sdk:
    for member in sdk:
        path = PurePosixPath(member.name)
        if (member.isfile() and path.name.startswith("native-linux-")
                and path.suffix == ".zip"):
            if found:
                raise SystemExit("multiple Linux native SDK components")
            with sdk.extractfile(member) as src, open("native.zip", "xb") as dst:
                shutil.copyfileobj(src, dst)
            found = True
if not found:
    raise SystemExit("Linux native SDK component missing")
# 读取 gzip 结束标志之后的输入，让管道完整结束。
while sys.stdin.buffer.read(1024 * 1024):
    pass
'
unzip -q native.zip
test -x native/llvm/bin/clang
test -x native/llvm/bin/clang++
test -d native/sysroot
rm -- "$archive.aa" "$archive.ab" native.zip
