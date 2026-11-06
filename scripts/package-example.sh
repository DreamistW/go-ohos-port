#!/usr/bin/env bash
# 验证真实 ELF 符号和 C 消费方链接，再生成可下载的集成包。
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$root/scripts/ohos-env.sh"
pkg="$root/dist/c-shared"
scratch=$(mktemp -d)
trap 'rm -f -- "$scratch/libconsumer.so"; rmdir -- "$scratch"; if [[ -n "${sdk_host_overlay:-}" ]]; then rm -- "$sdk_host_overlay/libxml2.so.16"; rmdir -- "$sdk_host_overlay"; fi' EXIT

mkdir -p -- "$pkg/include" "$pkg/lib/arm64-v8a"
lib="$pkg/lib/arm64-v8a/libgoohos.so"
bash "$root/scripts/build-shared.sh" "$root/example/shared" "$lib"
mv -- "${lib%.so}.h" "$pkg/include/"
readelf -hW "$lib" | grep -E 'Machine:.*AArch64'
readelf -hW "$lib" | grep -E 'Type:.*DYN'
readelf -dW "$lib" | grep -F '(SONAME)' | grep -F '[libgoohos.so]'
readelf --dyn-syms -W "$lib" | awk '$7 != "UND" && $8 == "GoOhosAdd" { add=1 } $7 != "UND" && $8 == "GoOhosInterfaceCount" { net=1 } END { exit !(add && net) }'
"$llvm/clang" --target=aarch64-linux-ohos --sysroot="$sysroot" -fuse-ld=lld \
  -fPIC -shared -Wall -Werror -Wl,--no-undefined -I"$pkg/include" \
  "$root/example/consumer/consumer.c" -L"$(dirname -- "$lib")" -lgoohos -o "$scratch/libconsumer.so"
readelf -dW "$scratch/libconsumer.so" | grep -F '(NEEDED)' | grep -F '[libgoohos.so]'
cp -- "$root/LICENSE" "$root/PATENTS" "$pkg/"
{
  echo "commit=$(git -C "$root" rev-parse HEAD)"
  echo 'target=openharmony/arm64'
  "$OHOS_GO_ROOT/bin/go" version
  "$llvm/clang" --version
} > "$pkg/BUILD.txt"
(cd -- "$pkg"; sha256sum BUILD.txt LICENSE PATENTS include/libgoohos.h lib/arm64-v8a/libgoohos.so > SHA256SUMS)
