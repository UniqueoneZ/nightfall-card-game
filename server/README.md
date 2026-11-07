# 联机中继服务

游戏本身是**锁步（lockstep）**：两名玩家各跑一份确定性引擎，服务器只负责
「分房间 + 给指令定序 + 广播」，不跑游戏逻辑、不存状态，所以极轻量（内存 < 30MB）。

## 本地运行

```bash
cd server
npm install
node relay.js 8787
```

然后用两个浏览器标签打开：

```
http://127.0.0.1:8792/?mode=online&server=ws://127.0.0.1:8787&room=TEST
```

（8792 是 `build/web` 的本地静态服务端口）

## 协议

| 方向 | 消息 |
| --- | --- |
| C→S | `{"t":"hello","room":"ABCD","name":"旅人"}` |
| S→C | `{"t":"wait","seat":0,"room":"ABCD","need":1}` |
| S→C | `{"t":"start","seed":123,"seats":[...]}` |
| C→S | `{"t":"cmd","cmd":{"type":"play",...}}` |
| S→C | `{"t":"cmd","seq":7,"by":0,"cmd":{...}}` |

服务端给每条指令编号并广播，两端按同一顺序执行，因此状态必然一致。
联机测试用 `state_hash()` 校验：两个无头客户端跑 48 步指令，哈希逐步完全相同。

## 一键部署到 Render（推荐，免费）

[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy?repo=https://github.com/UniqueoneZ/nightfall-card-game)

点上面的按钮 → GitHub 登录授权 → Render 自动读取仓库根目录的 `render.yaml` 建服务 → 完成后拿到
`wss://<服务名>.onrender.com`。

免费档说明：
- 15 分钟无流量会休眠，首次连接约 30 秒唤醒；
- 对局进行中有 WebSocket 心跳，不会休眠；
- 不需要信用卡。

## 其他部署方式

### Render（免费，最省事）

1. 仓库推到 GitHub；
2. Render → New → Blueprint → 选这个仓库（会自动读取 `server/render.yaml`）；
3. 拿到 `wss://xxx.onrender.com` 地址。

> 免费实例 15 分钟无访问会休眠，首次连接要等 30 秒左右唤醒。

### Fly.io

```bash
cd server
fly launch --copy-config --no-deploy
fly deploy
```

### 自己的服务器 / Docker

```bash
docker build -t nightfall-relay ./server
docker run -d -p 8080:8080 --restart=always nightfall-relay
```

前面套一层 Nginx 反代并开 TLS，游戏页面是 https，**必须用 wss://**，否则浏览器按混合内容拦截。

## 房间

- 不带 `room` 参数时所有人进 `OPEN` 房间；
- 带 `room=ABCD` 则进指定房间，最多 2 人，第三人会被拒绝；
- 房间空闲 10 分钟自动回收。
