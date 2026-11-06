#!/usr/bin/env bash
# 供通用库构建和 C 链接验收复用的 SDK 环境。
: "${OHOS_SDK_NATIVE:?Set OHOS_SDK_NATIVE to the Linux SDK native directory}"
OHOS_SDK_NATIVE=$(cd -- "$OHOS_SDK_NATIVE" && pwd)
llvm="$OHOS_SDK_NATIVE/llvm/bin"
sysroot="$OHOS_SDK_NATIVE/sysroot"
test -x "$llvm/clang"
test -x "$llvm/ld.lld" || test -x "$llvm/lld"
test -d "$sysroot/usr/lib/aarch64-linux-ohos"

# 某些 SDK 的 Clang 依赖与宿主发行版不同的 libxml2 SONAME。
sdk_lib="$OHOS_SDK_NATIVE/llvm/lib"
export LD_LIBRARY_PATH="$sdk_lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
if ! "$llvm/clang" --version >/dev/null 2>&1; then
  sdk_xml="$sdk_lib/libxml2.so.2.14.0"
  if [[ -f "$sdk_xml" ]] && ldd "$llvm/clang" | grep -F 'libxml2.so.16 => not found'; then
    sdk_host_overlay=$(mktemp -d)
    trap 'rmdir -- "$sdk_host_overlay" 2>/dev/null || true' EXIT
    ln -s -- "$sdk_xml" "$sdk_host_overlay/libxml2.so.16"
    trap 'rm -- "$sdk_host_overlay/libxml2.so.16"; rmdir -- "$sdk_host_overlay"' EXIT
    export LD_LIBRARY_PATH="$sdk_host_overlay:$LD_LIBRARY_PATH"
  fi
fi
"$llvm/clang" --version
