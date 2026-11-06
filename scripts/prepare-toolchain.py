#!/usr/bin/env python3
"""从锁定的官方 Go 归档构建 Linux x86-64 工具链。"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    """计算文件原始字节的 SHA-256。"""
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def unpack(work, name, asset):
    """在解包前校验完整归档，再移动到独立源码目录。"""
    archive = work / (name + ".tar.gz")
    with urllib.request.urlopen(asset["url"], timeout=90) as response, archive.open("xb") as output:
        shutil.copyfileobj(response, output)
    if digest(archive) != asset["sha256"]:
        raise ValueError("archive checksum mismatch: " + name)

    extraction = work / (name + "-extract")
    extraction.mkdir()
    with tarfile.open(archive) as source:
        source.extractall(extraction, filter="data")
    upstream = extraction / "go"
    if not (upstream / "src").is_dir():
        raise ValueError("unexpected Go archive layout: " + name)
    destination = work / name
    upstream.rename(destination)
    extraction.rmdir()
    archive.unlink()
    return destination


def verify_files(root, files, phase):
    """验证补丁目标完整处于锁定的应用前或应用后状态。"""
    for name, expected in files.items():
        relative = Path(name)
        path = root / relative
        if relative.is_absolute() or ".." in relative.parts or not path.resolve().is_relative_to(root):
            raise ValueError("unsafe patch path: " + name)
        if path.is_symlink():
            raise ValueError("unexpected symlink: " + name)
        actual = digest(path) if path.exists() else None
        if actual != expected[phase]:
            raise ValueError(f"unexpected {phase} digest: {name}")


def apply_platform(root, platform):
    """用零 fuzz 应用固定补丁，并验证每个目标文件。"""
    patch = ROOT / "patches" / platform["patch"]
    if digest(patch) != platform["patch_sha256"]:
        raise ValueError("platform patch checksum mismatch")
    files = platform["files"]
    paths = {line[6:] for line in patch.read_text(encoding="utf-8").splitlines()
             if line.startswith(("--- a/", "+++ b/"))}
    if paths != set(files):
        raise ValueError("patch paths differ from the lock")
    verify_files(root, files, "before")
    command = ["patch", "--batch", "--forward", "--fuzz=0", "--no-backup-if-mismatch",
               "-p1", "-d", str(root), "-i", str(patch)]
    subprocess.run(command + ["--dry-run"], check=True, stdout=subprocess.DEVNULL)
    subprocess.run(command, check=True, stdout=subprocess.DEVNULL)
    verify_files(root, files, "after")


def main():
    """构建宿主 go、compile、link，检查版本及目标注册。"""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("work", type=Path, help="new isolated build directory")
    work = parser.parse_args().work.resolve()
    if os.uname().sysname != "Linux" or os.uname().machine != "x86_64":
        parser.error("a Linux x86-64 host is required")
    work.mkdir(parents=True, exist_ok=False)
    lock = json.loads((ROOT / "toolchain.lock.json").read_bytes())
    bootstrap = unpack(work, "bootstrap", lock["bootstrap_linux_amd64"])
    go_root = unpack(work, "go", lock["source"])
    apply_platform(go_root, lock["platform"])

    env = dict(os.environ, GOROOT=str(go_root), GOROOT_BOOTSTRAP=str(bootstrap),
               GOTOOLCHAIN="local", GOENV="off", GOOS="linux", GOARCH="amd64",
               CGO_ENABLED="1", GOCACHE=str(work / "bootstrap-cache"))
    env.pop("GOCACHEPROG", None)
    env.pop("GOFLAGS", None)
    subprocess.run(["bash", "make.bash"], cwd=go_root / "src", env=env, check=True)
    go = str(go_root / "bin/go")
    version = subprocess.check_output([go, "env", "GOVERSION"], env=env, text=True).strip()
    targets = subprocess.check_output([go, "tool", "dist", "list"], env=env, text=True).splitlines()
    if version != lock["go_tag"] or "openharmony/arm64" not in targets:
        raise ValueError("unexpected built toolchain version or targets")
    print(f"{version} toolchain built at {go_root}")


if __name__ == "__main__":
    main()
