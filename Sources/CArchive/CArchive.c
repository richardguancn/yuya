#include "CArchive.h"
#include "vendor/archive.h"
#include "vendor/archive_entry.h"
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <limits.h>
#include <xlocale.h>

static int failure(struct archive *a, char *err, size_t cap) {
    const char *message = archive_error_string(a);
    snprintf(err, cap, "%s", message ? message : "无法读取或保存文件");
    return -1;
}
static struct archive *reader(void) {
    struct archive *a = archive_read_new();
    archive_read_support_filter_all(a);
    archive_read_support_format_all(a);
    archive_read_support_format_raw(a);
    return a;
}
static int safe_path(const char *path) {
    if (!path || !*path || path[0] == '/' || strchr(path, '\\')) return 0;
    // Also refuse Windows absolute paths when sharing extracted files.
    if (strlen(path) > 1 && path[1] == ':') return 0;
    const char *p = path;
    while (*p) {
        size_t n = strcspn(p, "/");
        if (n == 2 && p[0] == '.' && p[1] == '.') return 0;
        p += n;
        if (*p) p++;
    }
    return 1;
}
static int safe_link(const char *path, const char *target) {
    if (!target || !*target || target[0] == '/' || strchr(target, '\\') ||
        (strlen(target) > 1 && target[1] == ':')) return 0;
    int depth = -1;
    const char *p = path;
    while (*p) {
        size_t n = strcspn(p, "/");
        if (n && !(n == 1 && p[0] == '.')) depth++;
        p += n;
        if (*p) p++;
    }
    if (depth < 0) depth = 0;
    p = target;
    while (*p) {
        size_t n = strcspn(p, "/");
        if (n == 2 && p[0] == '.' && p[1] == '.') { if (--depth < 0) return 0; }
        else if (n && !(n == 1 && p[0] == '.')) depth++;
        p += n;
        if (*p) p++;
    }
    return 1;
}
static int raw_name(struct archive *a, struct archive_entry *entry, const char *source, char *err, size_t cap) {
    if (archive_format(a) != ARCHIVE_FORMAT_RAW) return 1;
    if (archive_filter_code(a, 0) == ARCHIVE_FILTER_NONE) {
        snprintf(err, cap, "压缩包已损坏或暂不支持"); return 0;
    }
    const char *base = strrchr(source, '/');
    char *name = strdup(base ? base + 1 : source);
    char *dot = strrchr(name, '.');
    if (dot && dot != name) *dot = 0;
    archive_entry_set_pathname(entry, name);
    free(name);
    return 1;
}
static int safe_entry(struct archive_entry *entry, char *err, size_t cap) {
    const char *path = archive_entry_pathname(entry);
    const char *link = archive_entry_symlink(entry);
    const char *hardlink = archive_entry_hardlink(entry);
    mode_t type = archive_entry_filetype(entry);
    if (!safe_path(path) || (link && !safe_link(path, link)) || (hardlink && !safe_path(hardlink)) ||
        (type != AE_IFREG && type != AE_IFDIR && type != AE_IFLNK && !hardlink)) {
        snprintf(err, cap, "压缩包内容不安全，已停止处理\n%.500s", path ? path : "");
        return 0;
    }
    return 1;
}
static int inspect_utf8(const char *path, yuya_callback cb, void *ctx, char *err, size_t cap) {
    struct archive *a = reader();
    int result = archive_read_open_filename(a, path, 65536);
    if (result != ARCHIVE_OK) { failure(a, err, cap); archive_read_free(a); return -1; }
    struct archive_entry *entry;
    int64_t count = 0, bytes = 0;
    while ((result = archive_read_next_header(a, &entry)) == ARCHIVE_OK) {
        if (!raw_name(a, entry, path, err, cap) || !safe_entry(entry, err, cap)) { archive_read_free(a); return -1; }
        int64_t size = archive_entry_size_is_set(entry) ? archive_entry_size(entry) : -1;
        if (size < -1 || (size > 0 && INT64_MAX - bytes < size) || ++count > 1000000) {
            snprintf(err, cap, "压缩包内容过多，暂时无法处理"); archive_read_free(a); return -1;
        }
        if (size > 0) bytes += size;
        if (cb(ctx, archive_entry_pathname(entry), size, count, archive_entry_filetype(entry) == AE_IFDIR)) {
            archive_read_free(a); return 1;
        }
        if (archive_format(a) == ARCHIVE_FORMAT_RAW) { archive_read_free(a); return 0; }
        result = archive_read_data_skip(a);
        if (result < ARCHIVE_OK) { failure(a, err, cap); archive_read_free(a); return -1; }
    }
    if (result != ARCHIVE_EOF) { failure(a, err, cap); archive_read_free(a); return -1; }
    archive_read_free(a);
    return 0;
}
static int extract_utf8(const char *path, const char *destination, yuya_callback cb, void *ctx, char *err, size_t cap) {
    char canonical[PATH_MAX];
    if (!realpath(destination, canonical)) {
        snprintf(err, cap, "无法打开保存位置\n%s", strerror(errno)); return -1;
    }
    destination = canonical;
    struct archive *a = reader();
    struct archive *disk = archive_write_disk_new();
    archive_write_disk_set_options(disk, ARCHIVE_EXTRACT_TIME | ARCHIVE_EXTRACT_PERM |
        ARCHIVE_EXTRACT_SECURE_SYMLINKS | ARCHIVE_EXTRACT_SECURE_NODOTDOT | ARCHIVE_EXTRACT_NO_OVERWRITE);
    archive_write_disk_set_standard_lookup(disk);
    int result = archive_read_open_filename(a, path, 65536), status = -1;
    int64_t bytes = 0, count = 0;
    struct archive_entry *entry;
    if (result != ARCHIVE_OK) { failure(a, err, cap); goto done; }
    while ((result = archive_read_next_header(a, &entry)) == ARCHIVE_OK) {
        if (!raw_name(a, entry, path, err, cap) || !safe_entry(entry, err, cap)) goto done;
        char *relative = strdup(archive_entry_pathname(entry));
        char full[PATH_MAX];
        if (snprintf(full, sizeof(full), "%s/%s", destination, relative) >= sizeof(full)) {
            free(relative); snprintf(err, cap, "文件位置过长，请换个保存位置"); goto done;
        }
        const char *hardlink = archive_entry_hardlink(entry);
        if (hardlink) {
            char target[PATH_MAX];
            if (snprintf(target, sizeof(target), "%s/%s", destination, hardlink) >= sizeof(target)) {
                free(relative); snprintf(err, cap, "文件位置过长，请换个保存位置"); goto done;
            }
            archive_entry_set_hardlink(entry, target);
        }
        archive_entry_set_pathname(entry, full);
        if (cb(ctx, relative, bytes, count, 0)) { free(relative); status = 1; goto done; }
        if (archive_write_header(disk, entry) < ARCHIVE_OK) {
            free(relative); failure(disk, err, cap); goto done;
        }
        const void *buffer;
        size_t size;
        la_int64_t offset;
        while ((result = archive_read_data_block(a, &buffer, &size, &offset)) == ARCHIVE_OK) {
            if (archive_write_data_block(disk, buffer, size, offset) < ARCHIVE_OK) {
                free(relative); failure(disk, err, cap); goto done;
            }
            bytes += size;
            if (cb(ctx, relative, bytes, count, 0)) { free(relative); status = 1; goto done; }
        }
        free(relative);
        if (result != ARCHIVE_EOF) { failure(a, err, cap); goto done; }
        if (archive_write_finish_entry(disk) < ARCHIVE_OK) { failure(disk, err, cap); goto done; }
        count++;
    }
    if (result != ARCHIVE_EOF) { failure(a, err, cap); goto done; }
    status = 0;
done:
    if (archive_write_close(disk) < ARCHIVE_OK && status == 0) { failure(disk, err, cap); status = -1; }
    archive_write_free(disk);
    archive_read_free(a);
    return status;
}
static int compress_utf8(const char * const *paths, size_t path_count, const char *destination, int level, int exclude_metadata,
                  yuya_callback cb, void *ctx, char *err, size_t cap) {
    struct archive *writer = archive_write_new();
    archive_write_set_format_zip(writer);
    char option[64];
    snprintf(option, sizeof(option), "zip:compression-level=%d,zip:hdrcharset=UTF-8", level);
    if (archive_write_set_options(writer, option) != ARCHIVE_OK ||
        archive_write_open_filename(writer, destination) != ARCHIVE_OK) {
        failure(writer, err, cap); archive_write_free(writer); return -1;
    }
    int status = 0;
    int64_t bytes = 0, count = 0;
    char buffer[65536];
    for (size_t i = 0; i < path_count && status == 0; i++) {
        struct archive *disk = archive_read_disk_new();
        archive_read_disk_set_symlink_physical(disk);
        archive_read_disk_set_standard_lookup(disk);
        if (archive_read_disk_open(disk, paths[i]) != ARCHIVE_OK) { failure(disk, err, cap); status = -1; }
        size_t prefix = (strrchr(paths[i], '/') - paths[i]) + 1;
        struct archive_entry *entry = archive_entry_new();
        int result = ARCHIVE_OK;
        while (status == 0 && (result = archive_read_next_header2(disk, entry)) == ARCHIVE_OK) {
            const char *full = archive_entry_sourcepath(entry);
            if (!full) full = archive_entry_pathname(entry);
            const char *relative = archive_entry_pathname(entry) + prefix;
            const char *name = strrchr(relative, '/');
            name = name ? name + 1 : relative;
            if (exclude_metadata && (!strcmp(name, ".DS_Store") || !strcmp(name, "__MACOSX") || !strncmp(name, "._", 2))) {
                archive_entry_clear(entry); continue;
            }
            mode_t type = archive_entry_filetype(entry);
            if (type != AE_IFREG && type != AE_IFDIR && type != AE_IFLNK) {
                snprintf(err, cap, "这个文件暂不支持压缩\n%.500s", relative); status = -1; break;
            }
            if (type == AE_IFDIR) archive_read_disk_descend(disk);
            char *name_copy = strdup(relative);
            int fd = -1;
            if (type == AE_IFREG) {
                fd = open(full, O_RDONLY | O_NOFOLLOW);
                if (fd < 0) { snprintf(err, cap, "无法读取文件\n%.500s\n%s", relative, strerror(errno)); free(name_copy); status = -1; break; }
            }
            archive_entry_set_pathname_utf8(entry, name_copy);
            if (!safe_entry(entry, err, cap)) status = -1;
            if (status == 0 && cb(ctx, name_copy, bytes, count, 0)) status = 1;
            if (status == 0 && archive_write_header(writer, entry) != ARCHIVE_OK) { failure(writer, err, cap); status = -1; }
            ssize_t n;
            int64_t remaining = archive_entry_size(entry);
            while (status == 0 && fd >= 0 && remaining > 0) {
                n = read(fd, buffer, remaining < sizeof(buffer) ? (size_t)remaining : sizeof(buffer));
                if (n <= 0) { snprintf(err, cap, "文件已变化或读取中断，请重试\n%.500s", name_copy); status = -1; break; }
                if (archive_write_data(writer, buffer, n) != n) { failure(writer, err, cap); status = -1; break; }
                bytes += n; remaining -= n;
                if (cb(ctx, name_copy, bytes, count, 0)) status = 1;
            }
            if (fd >= 0) close(fd);
            if (status == 0 && archive_write_finish_entry(writer) != ARCHIVE_OK) { failure(writer, err, cap); status = -1; }
            free(name_copy);
            count++;
            archive_entry_clear(entry);
        }
        if (status == 0 && result != ARCHIVE_EOF) { failure(disk, err, cap); status = -1; }
        archive_entry_free(entry);
        archive_read_free(disk);
    }
    if (archive_write_close(writer) != ARCHIVE_OK && status == 0) { failure(writer, err, cap); status = -1; }
    archive_write_free(writer);
    return status;
}

// Finder-launched apps can inherit the C locale, unlike terminal test runs.
// macOS file URLs use UTF-8. Keep libarchive's conversion local to this worker
// thread, so concurrent operations and the interface never change each other's locale.
static locale_t begin_utf8(char *err, size_t cap, locale_t *previous) {
    locale_t locale = newlocale(LC_CTYPE_MASK, "en_US.UTF-8", NULL);
    if (!locale) { snprintf(err, cap, "无法读取文件名，请重试"); return NULL; }
    *previous = uselocale(locale);
    return locale;
}
static void end_utf8(locale_t locale, locale_t previous) {
    uselocale(previous);
    freelocale(locale);
}
int yuya_inspect(const char *path, yuya_callback cb, void *ctx, char *err, size_t cap) {
    locale_t previous, locale = begin_utf8(err, cap, &previous);
    if (!locale) return -1;
    int result = inspect_utf8(path, cb, ctx, err, cap);
    end_utf8(locale, previous);
    return result;
}
int yuya_extract(const char *path, const char *destination, yuya_callback cb, void *ctx, char *err, size_t cap) {
    locale_t previous, locale = begin_utf8(err, cap, &previous);
    if (!locale) return -1;
    int result = extract_utf8(path, destination, cb, ctx, err, cap);
    end_utf8(locale, previous);
    return result;
}
int yuya_compress(const char * const *paths, size_t path_count, const char *destination, int level, int exclude_metadata,
                  yuya_callback cb, void *ctx, char *err, size_t cap) {
    locale_t previous, locale = begin_utf8(err, cap, &previous);
    if (!locale) return -1;
    int result = compress_utf8(paths, path_count, destination, level, exclude_metadata, cb, ctx, err, cap);
    end_utf8(locale, previous);
    return result;
}
