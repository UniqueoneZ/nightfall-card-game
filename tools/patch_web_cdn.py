#!/usr/bin/env python3
"""把 Web 构建里的大文件（wasm / pck）指向 GitHub raw CDN。

背景：github.io 不压缩 wasm（38MB 原样传输），且在国内常被限速到几十 KB/s；
而 raw.githubusercontent.com 通常快一个数量级。HTML/JS 留在 Pages，
wasm/pck 走 raw，首次加载从十几分钟降到一分钟内。

用法:
    python3 tools/patch_web_cdn.py build/web/index.html UniqueoneZ/nightfall-card-game gh-pages
"""
import hashlib
import os
import re
import sys

RAW = "https://raw.githubusercontent.com/{repo}/{branch}/index"
MARK = "raw.githubusercontent.com"


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    path, repo = sys.argv[1], sys.argv[2]
    branch = sys.argv[3] if len(sys.argv) > 3 else "gh-pages"
    html = open(path, encoding="utf-8").read()

    if MARK in html:
        print("[skip] 已经是 CDN 版本")
        return 0

    base = RAW.format(repo=repo, branch=branch)
    # 用 pck 内容哈希做版本号，绕开 raw CDN 的 5 分钟缓存
    pck_path = os.path.join(os.path.dirname(path), "index.pck")
    ver = hashlib.sha1(open(pck_path, "rb").read(1 << 20)).hexdigest()[:10]
    new, n = re.subn(
        r'"executable":"index"',
        f'"executable":"{base}","mainPack":"{base}.pck?v={ver}"',
        html,
    )
    if n != 1:
        print(f"[fail] 未找到 executable 配置（匹配 {n} 次）")
        return 1
    open(path, "w", encoding="utf-8").write(new)
    print(f"[ok] 大文件已指向 {base}.wasm / .pck")
    return 0


if __name__ == "__main__":
    sys.exit(main())
