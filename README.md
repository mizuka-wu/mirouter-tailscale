# mirouter-tailscale

小米/红米路由器 Tailscale 管理脚本，参考 [ShellCrash](https://github.com/juewuy/ShellCrash) 架构设计。

> ⚠️ **实验性项目** — 目前仅在 **红米 BE6500 Pro** (arm64, tun 可用) 上验证通过。其他设备可能需要调整，欢迎反馈。

## 当前验证环境

| 设备 | 架构 | 系统 | Tun | 状态 |
|------|------|------|-----|------|
| 红米 BE6500 Pro | arm64 | mi_snapshot | ✓ | ✅ 验证通过 |
| 小米 AX6000 | arm64 | mi_snapshot | 待验证 | ❓ |
| 其他小米路由器 | - | mi_snapshot | 待验证 | ❓ |
| OpenWrt | - | - | 待验证 | ❓ |

如果你在其他设备上测试过，请提 [Issue](https://github.com/mizuka-wu/mirouter-tailscale/issues) 反馈。

## 安装

### 一键安装

```sh
curl -fsSL https://raw.githubusercontent.com/mizuka-wu/mirouter-tailscale/main/install.sh -o /tmp/ts_install.sh && sh /tmp/ts_install.sh
```

> ⚠️ 不要用 `curl | sh` 管道方式，脚本有交互式选择，管道会导致 `read` 无法读取输入。

### 安装后使用

```sh
tsm                    # 打开管理菜单
tsm -s start           # 命令行启动
tsm -s stop            # 命令行停止
tsm -s restart         # 命令行重启
tsm -s status          # 命令行查看状态
```

## 典型场景：远程访问家庭 NAS

```
外网 iPhone (Tailscale/Surge)
        │
        ▼ Tailscale 网络
小米路由器 (Tailscale subnet router, 宣告 192.168.3.0/24)
        │
        ▼
NAS (192.168.3.x)
```

### 配置步骤

1. 路由器上执行安装脚本
2. `tsm` → [1] 填入 Auth Key（从 https://login.tailscale.com/admin/settings/keys 获取）
3. `tsm` → [2] 设置节点名称（默认 XiaoQiang）
4. `tsm` → [3] 确认子网路由（自动检测，如 192.168.3.0/24）
5. [1] 启动服务
6. 去 https://console.tailscale.com/admin/machines → 找到路由器 → Edit route settings → 勾选允许子网
7. iPhone 安装 Tailscale 或配置 Surge，登录同一账号
8. 直接访问 NAS IP

### Surge 配置示例

```
[Proxy]
Tailscale mizuka = tailscale, section-name=mizuka

[Policy Group]
家庭子网 = select, DIRECT, Tailscale mizuka

[SSID Policy]
你的WiFi名称 = 家庭子网:DIRECT

[Rule]
DOMAIN-SUFFIX,ts.net,Tailscale mizuka
IP-CIDR,100.64.0.0/10,Tailscale mizuka,no-resolve
IP-CIDR,192.168.3.0/24,家庭子网,no-resolve
```

- 在家连 WiFi → 直连 NAS
- 外出用蜂窝 → 走 Tailscale 访问 NAS

## 设置菜单

```
=========================================================
 Tailscale 设置
=========================================================
1) Auth Key       tskey-auth-k...
2) 节点名称       BE6500Pro
3) 子网路由       192.168.3.0/24 (自动检测)
4) 运行模式       Tun (内核路由)
5) 测试地址       223.5.5.5
6) Tailscale 版本 1.102.4
7) 自定义下载源   默认
0) 返回
=========================================================
```

### 配置说明

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| Auth Key | 路由器加入 Tailscale 的凭证 | 必填 |
| 节点名称 | Tailscale 网络中显示的设备名 | 系统主机名 |
| 子网路由 | 宣告给 Tailscale 的内网网段 | 自动检测 |
| 运行模式 | Tun（需要 /dev/net/tun）或 Userspace | 自动检测 |
| 测试地址 | 检测网络是否就绪的 ping 地址 | 223.5.5.5 |
| Tailscale 版本 | 二进制版本号 | 1.102.4 |
| 自定义下载源 | 局域网 HTTP 源，加速下载 | 官网 |

## 运行模式

### Tun 模式（推荐）

需要内核支持 `/dev/net/tun`。Tailscale 创建虚拟网卡，内核级路由。子网路由功能完整。

```
iPhone (Tailscale) → 路由器 tun 网卡 → LAN → NAS
```

### Userspace 模式

不依赖 tun，通过 SOCKS5 代理工作。子网路由功能受限，其他设备需手动配置代理。

```
iPhone (配代理) → SOCKS5 路由器IP:1055 → Tailscale
```

## 目录结构

```
/data/tailscale/                       # TSDIR
├── configs/
│   └── ts.cfg                         # 配置文件
├── state/
│   └── tailscaled.state               # 登录凭证
├── scripts/
│   ├── menu.sh                        # 主菜单
│   ├── start.sh                       # 服务控制
│   ├── init.sh                        # 初始化
│   ├── check.sh                       # 环境预检
│   ├── libs/                          # 工具库
│   └── menus/                         # 菜单模块
└── starts/
    ├── snapshot_init.sh               # 小米开机初始化
    └── monitor.sh                     # Cron 监控守护

/tmp/tailscale_run/                    # 内存运行目录
├── tailscale                          # 客户端 (~25MB)
├── tailscaled                         # 守护进程 (~25MB)
└── monitor.log                        # 监控日志
```

- 脚本+配置在 `/data`（~100KB，持久化）
- 二进制在 `/tmp`（~50MB，内存盘，重启清空后自动重新下载）
- 登录凭证在 `/data/tailscale/state`（重启免认证）

## 版本管理

- 脚本版本通过 GitHub release 分发
- Tailscale 二进制版本在菜单 [6] 更新版本 中管理
- 安装脚本通过 `raw.githubusercontent.com` 获取最新版

## 启动流程

```
路由器开机
    │
    ▼
firewall include 触发 snapshot_init.sh
    │
    ├─ 等待 LAN 接口就绪 (ip a | grep lan)
    ├─ 等待网关连通 (ping test_host)
    ├─ 执行 monitor.sh
    └─ 注册 cron 守护 (每分钟巡检)
           │
           ▼
       monitor.sh
           ├─ 防并发锁
           ├─ ping 测试地址 → 网络就绪?
           ├─ tailscaled 存在?
           │   ├─ 不存在 → 多镜像下载 → 解压 → 启动
           │   └─ 存在 → 跳过
           ├─ 等待就绪 (20s)
           └─ tailscale up (幂等)
```

## 常见问题

### 下载失败？
路由器可能无法访问 GitHub。脚本会依次尝试多个源（pkgs.tailscale.com → ghfast.top → ghproxy.cn）。也可以在设置里配置局域网 HTTP 下载源。

### 重启后 Tailscale 还在吗？
二进制会丢失（内存盘），但 cron 守护会自动重新下载。登录状态在 `/data`，无需重新认证。

### 无法访问子网设备？
1. 确认已在 https://console.tailscale.com/admin/machines 审批子网路由
2. 确认 SNAT 已开启（默认已开启）
3. 如果通过 Surge 访问，确认 Surge 规则包含子网 IP 段

### 占用多少闪存？
约 100KB。二进制在内存中运行，不占闪存。

## 致谢

- [ShellCrash](https://github.com/juewuy/ShellCrash) — 架构参考
- [dgj8300 (CSDN)](https://blog.csdn.net/dgj8300) — 小米路由器 Tailscale 系列文章
- [恩山论坛](https://www.right.com.cn/forum/thread-8467692-1-1.html) — 实操方案参考

## License

MIT
