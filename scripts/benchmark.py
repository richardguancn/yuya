#!/usr/bin/env python3
"""Compare the previous per-file zip implementation with the shared native archive engine.
Only generated input is used. All outputs are verified, then removed.
"""
import ctypes
import hashlib
import json
import pathlib
import statistics
import subprocess
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
CALLBACK = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int64, ctypes.c_int64, ctypes.c_int)


def main():
    with tempfile.TemporaryDirectory(prefix="yuya-benchmark-") as temporary:
        work = pathlib.Path(temporary)
        library = work / "libyuya.dylib"
        subprocess.run(["xcrun", "clang", "-O2", "-dynamiclib", str(ROOT / "Sources/CArchive/CArchive.c"),
                        "-I" + str(ROOT / "Sources/CArchive/include"), "-larchive", "-o", str(library)], check=True)
        native = ctypes.CDLL(str(library))
        native.yuya_compress.argtypes = [ctypes.POINTER(ctypes.c_char_p), ctypes.c_size_t, ctypes.c_char_p,
                                         ctypes.c_int, ctypes.c_int, CALLBACK, ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t]
        callback = CALLBACK(lambda *_: 0)
        folder = work / "input"
        folder.mkdir()
        # Many individually selected small files were the old implementation's most expensive case.
        paths = []
        for index in range(300):
            path = folder / f"document-{index:04d}.txt"
            path.write_bytes((f"Yuya document {index}\n" * 240).encode())
            paths.append(path)
        expected = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
        arguments = (ctypes.c_char_p * len(paths))(*(str(p).encode() for p in paths))
        results = {"previous_seconds": [], "current_seconds": []}
        for run in range(3):
            for kind in ("previous", "current") if run % 2 == 0 else ("current", "previous"):
                output = work / f"{kind}-{run}.zip"
                started = time.perf_counter()
                if kind == "previous":
                    for path in paths:
                        subprocess.run(["/usr/bin/zip", "-r", "-q", str(output), path.name], cwd=folder, check=True)
                else:
                    error = ctypes.create_string_buffer(4096)
                    code = native.yuya_compress(arguments, len(paths), str(output).encode(), 6, 1, callback, None, error, len(error))
                    if code != 0:
                        raise RuntimeError(error.value.decode())
                results[f"{kind}_seconds"].append(time.perf_counter() - started)
                import zipfile
                with zipfile.ZipFile(output) as archive:
                    actual = {name: hashlib.sha256(archive.read(name)).hexdigest() for name in archive.namelist()}
                    assert actual == expected, f"content mismatch: {kind}"
        results["input_files"] = len(paths)
        results["input_bytes"] = sum(p.stat().st_size for p in paths)
        results["previous_median_seconds"] = statistics.median(results["previous_seconds"])
        results["current_median_seconds"] = statistics.median(results["current_seconds"])
        results["speedup"] = results["previous_median_seconds"] / results["current_median_seconds"]
        results["verified"] = "All 6 archives contain exactly the same 300 files and matching SHA-256 digests."
        print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
