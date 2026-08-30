# SIP Terminal

![Go](https://img.shields.io/badge/Go-1.23-00ADD8?logo=go&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter&logoColor=white)
![FreeSWITCH](https://img.shields.io/badge/FreeSWITCH-1.10-8D6E63?logo=freeswitch&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?logo=mysql&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-ready-2496ED?logo=docker&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green)

基于 **SIP + WebRTC** 的软电话系统：Flutter 安卓客户端 + Go API + FreeSWITCH 交换服务，支持账号注册即自动分配 SIP 分机、语音互拨、通话记录云端同步。

> 仅用于学习 SIP 协议与 VoIP 全栈落地，请勿用于非法通信场景。

## 功能特性

- 语音通话：拨打 / 接听 / 挂断 / 静音，通话计时
- 账号体系：注册即自动分配 SIP 分机（从 1001 起），JWT 登录
- 通话历史：本地 SQLite 缓存 + 服务端游标分页同步，断网不丢话单
- 动态目录：FreeSWITCH 通过 mod_xml_curl 实时回调 API 查询分机，无需静态配置
- 明暗双主题，遵循 Minimal & Direct 设计系统
- 断线自动重连（指数退避），来电通知 + 前台麦克风服务保活

## 架构

```
┌─────────────┐  SIP信令(WSS) + RTP媒体(WebRTC)   ┌──────────────┐
│ Flutter App │◄─────────────────────────────────►│  FreeSWITCH  │
│  (Android)  │                                    │   (Docker)   │
└──────┬──────┘                                    └──────▲───────┘
       │ HTTPS REST (JSON)                                │ mod_xml_curl
       ▼                                                  │ 动态查分机目录
┌────────────────┐   同一 docker 网络   ┌──────────────┐
│ Go API (Gin)   │◄────────────────────►│    MySQL     │
└────────────────┘                      └──────────────┘
```

- **信令**：SIP over WebSocket（WSS），摘要认证（Digest）
- **媒体**：WebRTC（DTLS-SRTP + ICE），编解码协商走 SDP
- **目录**：FS 收到 REGISTER 时回调 Go API 的 `/fsw/directory`，返回目录 XML——数据库即目录

## 技术栈

| 端 | 技术 |
|---|---|
| 客户端 | Flutter / sip_ua / flutter_webrtc / Riverpod / drift / go_router |
| 服务端 | Go 1.23 / Gin / GORM / golang-jwt / bcrypt |
| 交换 | FreeSWITCH（mod_sofia + mod_xml_curl） |
| 存储 | MySQL 8 |
| 网关 | Caddy（HTTPS 反代 + WebSocket 反代，可选） |

## 目录结构

```
├── server/                 # Go API（cmd/server + internal/{api,auth,model,store}）
│   └── Dockerfile
├── sip_terminal_app/       # Flutter 安卓客户端
│   └── lib/
│       ├── core/           # 配置 / dio / 会话 / 路由 / 主题 tokens
│       ├── data/           # drift 表 + 同步仓库
│       ├── sip/            # sip_ua 封装（CallEngine 抽象 + 状态机）
│       └── features/       # auth / dialpad / call / history / accounts
└── deploy/
    ├── docker-compose.yml  # 本地开发编排（freeswitch + go-api）
    └── freeswitch/conf     # FS 配置（xml_curl / WSS / 拨号计划）
```

## 快速开始

### 1. 准备数据库

```sql
CREATE DATABASE sip_terminal CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- AutoMigrate 会在服务端启动时自动建表
```

### 2. 启动服务端

```bash
cd deploy
MYSQL_DSN="user:pass@tcp(mysql-host:3306)/sip_terminal?charset=utf8mb4&parseTime=True&loc=Local" \
JWT_SECRET="请替换为强随机串" \
docker compose up -d --build
```

环境变量：

| 变量 | 说明 | 默认 |
|---|---|---|
| `MYSQL_DSN` | MySQL 连接串（必须 `parseTime=True`） | 本地开发 DSN |
| `JWT_SECRET` | JWT 签名密钥 | dev-secret-change-me |
| `PORT` | API 监听端口 | 8080 |

FS 目录回调目标在 `deploy/freeswitch/conf/etc/autoload_configs/xml_curl.conf.xml` 中配置（默认 `http://go-api:8080/api/v1/fsw/directory`，与服务名保持一致）。

### 3. 客户端

```bash
cd sip_terminal_app
flutter pub get
flutter run            # 或 flutter build apk --release --split-per-abi
```

登录页「服务器地址」支持两种格式：

| 格式 | API | SIP |
|---|---|---|
| `https://api.example.com/sipapi` | https 域名 + 路径前缀 | wss://api.example.com/ws |
| `192.168.1.10`（纯 IP，本机开发） | http://IP:8080/api/v1 | wss://IP:7443/ws |

> 安卓模拟器访问宿主机用 `10.0.2.2`。

### 4. 打电话

1. 两台设备分别注册（各自获得分机号，如 1001、1002）
2. 拨号盘输入对方分机号 → 呼叫 → 接听
3. 挂断后双方「历史」Tab 自动出现话单（未接/拒接/无应答分类）

## 端口清单

| 端口 | 协议 | 用途 |
|---|---|---|
| 8080 | TCP | Go API |
| 5060 | UDP | SIP（传统客户端，可选） |
| 5066 | TCP | SIP over WS |
| 7443 | TCP | SIP over WSS |
| 16384-16404 | UDP | RTP 媒体 |

## 安全注意事项

- [ ] 替换默认 `JWT_SECRET`
- [ ] `/api/v1/fsw/directory` 会下发 SIP 凭证，**只允许容器内网访问**，严禁公网反代
- [ ] FreeSWITCH ACL（`locals.v4`）按需收敛网段，公网部署必须收紧
- [ ] 生产环境为 WSS 配置正式证书，避免客户端跳过校验

## 测试

```bash
cd server && go test ./... -count=1          # 服务端（含并发注册 -race 用例）
cd sip_terminal_app && flutter test          # 客户端（44 个用例）
```

## License

MIT
