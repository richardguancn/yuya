#ifndef YUYA_ARCHIVE_H
#define YUYA_ARCHIVE_H
#include <stdint.h>
#include <stddef.h>
// Callbacks run synchronously on the caller's worker thread. Nonzero cancels.
typedef int (*yuya_callback)(void *, const char *, int64_t, int64_t, int);
int yuya_inspect(const char *, yuya_callback, void *, char *, size_t);
int yuya_extract(const char *, const char *, yuya_callback, void *, char *, size_t);
int yuya_compress(const char * const *, size_t, const char *, int, int, yuya_callback, void *, char *, size_t);
#endif
