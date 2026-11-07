#!/usr/bin/env bash
# 构建 Web 版本到 build/web，可直接丢到任意静态服务器。
set -euo pipefail

cd "$(dirname "$0")/.."

GODOT="${GODOT:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
if [ ! -x "$GODOT" ]; then
  echo "找不到 Godot: $GODOT（可用 GODOT=/path/to/godot 指定）" >&2
  exit 1
fi

echo "==> 清理"
rm -rf build/web
mkdir -p build/web

echo "==> 导出 Web"
"$GODOT" --headless --path . --export-release "Web" build/web/index.html

if [ ! -f build/web/index.wasm ]; then
  echo "导出失败：未生成 index.wasm" >&2
  exit 1
fi

# 可选：把 wasm/pck 指向 GitHub raw CDN（国内 github.io 限速时使用）
if [ -n "${CDN_REPO:-}" ]; then
  echo "==> 应用 CDN 补丁: $CDN_REPO"
  python3 tools/patch_web_cdn.py build/web/index.html "$CDN_REPO" "${CDN_BRANCH:-gh-pages}"
fi

echo "==> 产物"
du -sh build/web
ls -lh build/web | sed 's/^/    /'

echo
echo "本地预览： cd build/web && python3 -m http.server 8080"
echo "     打开： http://127.0.0.1:8080"
