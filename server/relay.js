#!/usr/bin/env node
/**
 * 夜蚀 · 联机中继服务器
 *
 * 只做三件事：分房间、定序、广播。不跑游戏逻辑。
 * 客户端用锁步（lockstep）方式各跑一份确定性引擎，因此服务端不需要同步状态。
 *
 * 启动：node relay.js [port]
 * 协议：
 *   C→S  {"t":"hello","room":"ABCD","name":"旅人"}
 *   S→C  {"t":"wait","seat":0,"room":"ABCD","need":2}
 *   S→C  {"t":"start","seed":123,"seats":[{"seat":0,"name":"A"},{"seat":1,"name":"B"}]}
 *   C→S  {"t":"cmd","cmd":{...}}
 *   S→C  {"t":"cmd","seq":0,"by":0,"cmd":{...}}     ← 广播给房间内所有人
 *   S→C  {"t":"left","seat":1}
 */

const http = require('http');
const { WebSocketServer } = require('ws');

const PORT = parseInt(process.argv[2] || process.env.PORT || '8080', 10);
const MAX_PLAYERS = 2;
const IDLE_TIMEOUT_MS = 10 * 60 * 1000; // 房间空闲 10 分钟回收

// 用 HTTP server 承载 WebSocket，顺便提供 /health 给托管平台做健康检查
const httpServer = http.createServer((req, res) => {
  if (req.url === '/health' || req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('ok');
    return;
  }
  res.writeHead(404);
  res.end();
});

const wss = new WebSocketServer({ server: httpServer });
/** @type {Map<string, Room>} */
const rooms = new Map();

class Room {
  constructor(code) {
    this.code = code;
    this.seats = [];          // [{ws, name}]
    this.started = false;
    this.seed = 0;
    this.seq = 0;
    this.touchedAt = Date.now();
  }

  get full() { return this.seats.length >= MAX_PLAYERS; }

  touch() { this.touchedAt = Date.now(); }

  broadcast(obj) {
    const msg = JSON.stringify(obj);
    for (const s of this.seats) {
      if (s.ws.readyState === 1) s.ws.send(msg);
    }
  }

  join(ws, name) {
    const seat = this.seats.length;
    this.seats.push({ ws, name });
    ws._room = this;
    ws._seat = seat;
    return seat;
  }

  leave(ws) {
    const idx = this.seats.findIndex((s) => s.ws === ws);
    if (idx < 0) return;
    this.seats.splice(idx, 1);
    this.broadcast({ t: 'left', seat: idx });
    if (this.seats.length === 0) rooms.delete(this.code);
  }

  start() {
    this.started = true;
    this.seed = Math.floor(Math.random() * 2 ** 31);
    this.broadcast({
      t: 'start',
      seed: this.seed,
      seats: this.seats.map((s, i) => ({ seat: i, name: s.name })),
    });
  }

  relay(ws, cmd) {
    if (!this.started) return;
    const seat = ws._seat ?? -1;
    if (seat < 0) return;
    this.broadcast({ t: 'cmd', seq: this.seq++, by: seat, cmd });
  }
}

wss.on('connection', (ws) => {
  ws.on('message', (raw) => {
    let msg;
    try {
      msg = JSON.parse(raw.toString());
    } catch {
      return;
    }

    if (msg.t === 'hello') {
      const code = String(msg.room || 'OPEN').toUpperCase().slice(0, 8);
      let room = rooms.get(code);
      if (!room) {
        room = new Room(code);
        rooms.set(code, room);
      }
      room.touch();

      if (room.started) {
        ws.send(JSON.stringify({ t: 'error', msg: 'room_started' }));
        ws.close();
        return;
      }
      if (room.full) {
        ws.send(JSON.stringify({ t: 'error', msg: 'room_full' }));
        ws.close();
        return;
      }

      const seat = room.join(ws, String(msg.name || `玩家${room.seats.length + 1}`).slice(0, 16));
      ws.send(JSON.stringify({
        t: 'wait', seat, room: code, need: MAX_PLAYERS - room.seats.length,
      }));
      console.log(`[room ${code}] seat ${seat} joined (${room.seats.length}/${MAX_PLAYERS})`);
      if (room.full) room.start();
      return;
    }

    const room = ws._room;
    if (!room) return;
    room.touch();

    if (msg.t === 'cmd') {
      room.relay(ws, msg.cmd || {});
    } else if (msg.t === 'ping') {
      ws.send(JSON.stringify({ t: 'pong' }));
    }
  });

  ws.on('close', () => {
    const room = ws._room;
    if (room) {
      console.log(`[room ${room.code}] seat ${ws._seat} left`);
      room.leave(ws);
    }
  });
});

setInterval(() => {
  const now = Date.now();
  for (const [code, room] of rooms) {
    if (now - room.touchedAt > IDLE_TIMEOUT_MS) {
      for (const s of room.seats) s.ws.close();
      rooms.delete(code);
      console.log(`[room ${code}] idle timeout, closed`);
    }
  }
}, 60 * 1000);

httpServer.listen(PORT, () => {
  console.log(`nightfall relay listening on ws://0.0.0.0:${PORT}`);
});
