#!/bin/zsh
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
export CLANG_MODULE_CACHE_PATH="$project_dir/build/ModuleCache.noindex"
export SWIFTPM_MODULECACHE_OVERRIDE="$project_dir/build/ModuleCache.noindex"
python3 scripts/check_copy.py
swift test --disable-sandbox --scratch-path .build --manifest-cache local
python3 scripts/check_unicode.py
