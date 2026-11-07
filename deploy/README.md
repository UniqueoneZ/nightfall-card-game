# Web 部署说明

游戏导出为**纯静态站点**（HTML + wasm + pck），不需要后端，任何静态服务器都能托管。

## 1. 构建

```bash
cd Nightfall
bash tools/build_web.sh
```

产物在 `build/web/`：

| 文件 | 大小 | 说明 |
| --- | --- | --- |
| `index.html` | 5 KB | 入口 |
| `index.js` | 298 KB | 加载器 |
| `index.wasm` | 36 MB | 引擎（gzip 后约 9 MB） |
| `index.pck` | 7.6 MB | 游戏资源（含中文字体） |

首次加载需要下载约 44 MB，gzip 后约 12 MB。建议开启压缩 + CDN；后续访问靠缓存。

## 2. 本地预览

```bash
cd build/web && python3 -m http.server 8080
# 打开 http://127.0.0.1:8080
```

## 3. 部署方式

### 3.1 直接丢到静态托管

把 `build/web/` 整个目录上传到任意静态托管（Nginx / Caddy / GitHub Pages / Vercel / 对象存储 + CDN）即可，
唯一要求：**`.wasm` 的 MIME 类型必须是 `application/wasm`**。

### 3.2 Nginx

```bash
sudo cp -r build/web/* /var/www/nightfall/
sudo cp deploy/nginx.conf /etc/nginx/conf.d/nightfall.conf
sudo nginx -t && sudo systemctl reload nginx
```

`deploy/nginx.conf` 已配置：gzip、wasm MIME、长缓存、SPA 回落。

### 3.3 Docker

```bash
bash tools/build_web.sh
docker build -f deploy/Dockerfile -t nightfall-web .
docker run -d --name nightfall -p 8080:80 nightfall-web
# 打开 http://<服务器IP>:8080
```

### 3.4 Caddy（最省事，自动 HTTPS）

```caddyfile
game.example.com {
    root * /var/www/nightfall
    encode gzip
    file_server
}
```

## 4. 注意事项

### 4.1 线程模式

当前导出使用 `variant/thread_support=false`（单线程），**不要求** COOP/COEP 响应头，
因此可以部署在 GitHub Pages、对象存储等无法自定义响应头的环境。

若将来为了性能开启线程：

```ini
# export_presets.cfg
variant/thread_support=true
```

则服务器**必须**返回以下响应头，否则 `SharedArrayBuffer` 不可用，游戏白屏：

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

`deploy/nginx.conf` 里已预留注释。

### 4.2 中文字体

字体已内置在 `assets/fonts/NotoSansSC-Regular.otf`（OFL 授权），
**不要**改回依赖系统字体——浏览器里没有系统字体文件，会全部变成方块。

### 4.3 缓存策略

- `index.html`：`no-cache`（每次校验，保证版本更新后能拿到新入口）
- `*.wasm` / `*.pck` / `*.js`：长缓存。**升级版本时要改文件名或加 hash**，否则玩家会用到旧资源。

### 4.4 移动端

Godot Web 在移动浏览器上可运行，但：
- 首次加载 44 MB 对 4G 偏重，建议做加载页与进度提示；
- 触摸交互需要改成拖拽出牌（当前是点击）；
- 横屏锁定。

## 5. 发布流程

```bash
bash tools/build_web.sh          # 1. 构建
rsync -avz --delete build/web/ user@server:/var/www/nightfall/   # 2. 同步
# 3. 浏览器强刷验证
```

建议在 CI 里加一步：导出后 `gzip -9` 检查体积是否超阈值（例如 15 MB）。
