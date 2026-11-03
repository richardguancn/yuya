#!/usr/bin/env python3
"""Reproduce desktop-launch locale, check ZIP with an independent reader."""
import ctypes
import locale
from pathlib import Path
import subprocess
import tempfile
import zipfile

root = Path(__file__).resolve().parents[1]
locale.setlocale(locale.LC_ALL, "C")
with tempfile.TemporaryDirectory(prefix="yuya-unicode-") as temp:
    temp = Path(temp)
    library = temp / "CArchive.dylib"
    subprocess.run(["xcrun", "clang", "-dynamiclib", str(root / "Sources/CArchive/CArchive.c"),
                    "-I", str(root / "Sources/CArchive/include"), "-larchive", "-o", str(library)], check=True)
    lib = ctypes.CDLL(str(library))
    callback_type = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_void_p, ctypes.c_char_p,
                                   ctypes.c_int64, ctypes.c_int64, ctypes.c_int)
    seen = []
    @callback_type
    def callback(_, name, _bytes, _count, _directory):
        seen.append(name.decode("utf-8"))
        return 0
    folder = temp / "中文 资料"
    folder.mkdir()
    (folder / "使用说明.txt").write_bytes("验证中文文件名。\n".encode())
    (folder / "空文件夹").mkdir()
    sources = (ctypes.c_char_p * 1)(bytes(folder))
    archive = temp / "压缩文件.zip"
    error = ctypes.create_string_buffer(4096)
    assert lib.yuya_compress(sources, ctypes.c_size_t(1), bytes(archive), 6, 1, callback, None,
                             error, ctypes.c_size_t(len(error))) == 0, error.value.decode()
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        assert z.read("中文 资料/使用说明.txt") == (folder / "使用说明.txt").read_bytes()
        assert "中文 资料/空文件夹/" in z.namelist()
        assert all(item.flag_bits & 0x800 for item in z.infolist())
    seen.clear()
    assert lib.yuya_inspect(bytes(archive), callback, None, error, ctypes.c_size_t(len(error))) == 0, error.value.decode()
    assert "中文 资料/使用说明.txt" in seen
    output = temp / "解压结果"
    output.mkdir()
    assert lib.yuya_extract(bytes(archive), bytes(output), callback, None, error, ctypes.c_size_t(len(error))) == 0, error.value.decode()
    assert (output / "中文 资料/使用说明.txt").read_bytes() == (folder / "使用说明.txt").read_bytes()
    assert locale.setlocale(locale.LC_CTYPE) == "C", "Archive operations changed the caller's locale"
print("通过：桌面启动使用的 C 语言环境下，中文与空格名称可被独立 ZIP 读取器正确识别，预览和解压内容一致。")
