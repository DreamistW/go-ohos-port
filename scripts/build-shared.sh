#!/usr/bin/env bash
# 从调用者的 Go main package 生成同名 .so 和 .h。
set -euo pipefail

[[ $# == 2 ]] || { echo "Usage: $0 <Go main package directory> <output/libname.so>" >&2; exit 2; }
scripts=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$scripts/ohos-env.sh"
: "${OHOS_GO_ROOT:?Set OHOS_GO_ROOT to the built Go toolchain directory}"
export GOROOT
GOROOT=$(cd -- "$OHOS_GO_ROOT" && pwd)
output=$(realpath -m -- "$2")
soname=$(basename -- "$output")
[[ "$soname" =~ ^lib[a-zA-Z0-9_]+\.so$ ]] || { echo "Expected output name lib<name>.so" >&2; exit 2; }

export GOOS=openharmony GOARCH=arm64 CGO_ENABLED=1 GOTOOLCHAIN=local GOENV=off
export CC="$llvm/clang" CXX="$llvm/clang++" AR="$llvm/llvm-ar"
export CGO_CPPFLAGS="--target=aarch64-linux-ohos --sysroot=$sysroot -D__MUSL__"
export CGO_CFLAGS="$CGO_CPPFLAGS" CGO_CXXFLAGS="$CGO_CPPFLAGS"
export CGO_LDFLAGS="--target=aarch64-linux-ohos --sysroot=$sysroot -fuse-ld=lld -Wl,-soname,$soname"
# cgo 将空格分隔的参数拆成多个字段，路径保持独立。
if [[ "$OHOS_SDK_NATIVE" == *[[:space:]]* ]]; then
  echo 'OHOS_SDK_NATIVE must not contain whitespace' >&2
  exit 2
fi
mkdir -p -- "$(dirname -- "$output")"
cd -- "$1"
"$GOROOT/bin/go" build -mod=readonly -trimpath -buildmode=c-shared -o "$output" .
test -s "${output%.so}.h"
