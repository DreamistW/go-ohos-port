# Go for OpenHarmony ARM64

基于 [golang/go](https://github.com/golang/go) 的社区移植，目标为 `GOOS=openharmony`、`GOARCH=arm64`。工具链在 Linux x86-64 上运行，使用 OpenHarmony Native SDK 将 Go `main` 包编译成 HarmonyOS 应用可链接的 C ABI 共享库。平台补丁延续既有社区适配并保留源文件中的版权声明。各发布版本使用的 Go 上游标签、提交和源码校验值记录在对应标签下的 [toolchain.lock.json](toolchain.lock.json)。

## 下载与集成

从 [Latest Release](https://github.com/DreamistW/go-ohos-port/releases/latest) 下载 `openharmony-arm64-c-shared.tar.gz`。若同时下载两个归档和 `SHA256SUMS.txt`，可运行 `sha256sum -c SHA256SUMS.txt` 校验归档。共享库解包后也可运行 `sha256sum -c SHA256SUMS` 校验包内文件。

- `lib/arm64-v8a/libgoohos.so` 放入 HarmonyOS 项目的 `entry/libs/arm64-v8a/`。
- `include/libgoohos.h` 放入 `entry/src/main/cpp/include/`，在 C/C++ 中包含并调用所需的导出函数。
- 在应用分发材料中保留随包提供的 `LICENSE` 和 `PATENTS`。

在 `entry/src/main/cpp/CMakeLists.txt` 添加以下配置，并将 `your_native_target` 替换为你的 CMake target。

```cmake
add_library(goohos SHARED IMPORTED)
set_target_properties(goohos PROPERTIES
    IMPORTED_LOCATION "${CMAKE_CURRENT_LIST_DIR}/../../../libs/arm64-v8a/libgoohos.so"
    INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_CURRENT_LIST_DIR}/include")
target_link_libraries(your_native_target PRIVATE goohos)
```

示例导出 `GoOhosAdd` 和 `GoOhosInterfaceCount`。CI 使用 OpenHarmony 7.0（API 26）公共 Native SDK，检查 AArch64 ELF、SONAME 和导出符号，并实际链接 C 调用方。CI 的覆盖范围是交叉编译和链接，设备上的加载及调用由消费项目验收。

## 构建自己的 Go 库

在 Linux x86-64 使用 Python 3.12+、GNU patch、GCC、binutils、curl 和 unzip。可从 [Latest Release](https://github.com/DreamistW/go-ohos-port/releases/latest) 下载 `go-ohos-linux-amd64.tar.gz`，解包后将 `OHOS_GO_ROOT` 指向其中的 `go`。也可从锁定的官方源码和 bootstrap 归档构建。

```bash
python3 scripts/prepare-toolchain.py "$PWD/.work/toolchain"
export OHOS_GO_ROOT="$PWD/.work/toolchain/go"

mkdir -p .work
bash scripts/fetch-native-sdk.sh "$PWD/.work/sdk"
export OHOS_SDK_NATIVE="$PWD/.work/sdk/native"

bash scripts/build-shared.sh /path/to/go-main-package "$PWD/dist/libexample.so"
```

`OHOS_SDK_NATIVE` 也可以指向已安装的 Linux Native SDK，其目录应包含 `llvm/` 和 `sysroot/`，路径使用无空格的绝对路径。Go 包需为 `package main`，并通过 `import "C"` 和 `//export` 声明至少一个 C 入口。脚本生成同名 `.so` 和 `.h`。运行 `bash scripts/package-example.sh` 可复现示例包与链接验收。

## 发布

项目发布标签使用 `vMAJOR.MINOR.PATCH`，与 Go 的上游版本独立。推送正式版本标签后，GitHub Actions 构建并验收两个归档，再发布为 Latest Release。

## 许可证

本项目使用与 Go 相同的 BSD-3-Clause。上游许可与专利授权文本保存在 [LICENSE](LICENSE) 和 [PATENTS](PATENTS)。
