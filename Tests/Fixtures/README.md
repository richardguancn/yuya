# 测试样本来源

`rar.rar` 和 `7zip.7z` 从 libarchive v3.7.4 的公开测试样本解码得到，原始文本保留为 `.uu`：

- https://github.com/libarchive/libarchive/blob/v3.7.4/libarchive/test/test_read_format_rar.rar.uu
- https://github.com/libarchive/libarchive/blob/v3.7.4/libarchive/test/test_read_format_7zip_copy.7z.uu

仅用于验证压缩包目录读取、文件内容、目录与内部链接。libarchive 许可证见项目根目录 `THIRD_PARTY_NOTICES.md`。
