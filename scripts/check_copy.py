#!/usr/bin/env python3
"""Check the requested 2–4-character Chinese labels, <=20-character Chinese descriptions, and paired Native English copy."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
source = (root / "Yuya/AppCopy.swift").read_text()
errors = []
counts = {}
for section, minimum, maximum in [("Label", 2, 4), ("Description", 1, 20)]:
    block = source.split(f"enum {section} {{", 1)[1].split("\n    }", 1)[0]
    entries = re.findall(r'static var (\w+): String \{ localized\(zh: "([^"]*)", en: "([^"]*)"\) \}', block)
    if not entries:
        # Fallback to legacy static let if present
        entries = [(k, v, "") for k, v in re.findall(r'static let (\w+) = "([^"]*)"', block)]
    assert entries, f"Missing {section} catalog"
    counts[section] = len(entries)
    for item in entries:
        key, zh_val = item[0], item[1]
        en_val = item[2] if len(item) > 2 else ""
        if not minimum <= len(zh_val) <= maximum:
            errors.append(f"{section}.{key}: {len(zh_val)} characters: {zh_val}")
        if any(word in zh_val for word in ["工作空间", "归档", "元数据", "路径", "项目", "临时文件"]):
            errors.append(f"{section}.{key}: avoid jargon: {zh_val}")
        if not en_val.strip():
            errors.append(f"{section}.{key}: missing Native English translation")
    keys = {item[0] for item in entries}
    for file in (root / "Yuya").glob("*.swift"):
        for key in re.findall(rf"AppCopy\.{section}\.(\w+)", file.read_text()):
            if key not in keys:
                errors.append(f"{file.name}: unknown {section}.{key}")
# Product-authored low-level explanations also stay short. Interpolated file names
# and original operating-system diagnostics are data, not editable interface copy.
for literal in re.findall(r'"([^"\n]*[\u4e00-\u9fff][^"\n]*)"', (root / "Sources/CArchive/CArchive.c").read_text()):
    explanation = literal.split(r"\n", 1)[0]
    if len(explanation) > 20:
        errors.append(f"Archive explanation too long: {explanation}")
if errors:
    raise SystemExit("\n".join(errors))
print(f"通过：{counts['Label']} 个名称均为 2–4 字，{counts['Description']} 条说明均不超过 20 字；中英双语对齐，无缺失引用。")
