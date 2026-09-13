# mirouter-tailscale

小米路由器 Tailscale 管理脚本，严格参考 [ShellCrash](https://github.com/juewuy/ShellCrash) 的架构和管理模式设计。

## 与 ShellCrash 的对应关系

| ShellCrash | mirouter-tailscale | 说明 |
|---|---|---|
| `install.sh` | `install.sh` | 一键安装器，检测系统/架构/目录 |
| `menu.sh` | `scripts/menu.sh` | 主菜单入口，加载所有模块 |
| `start.sh` | `scripts/start.sh` | 服务控制 (start/stop/restart) |
| `init.sh` | `scripts/init.sh` | 初始化：目录/权限/环境变量/别名 |
| `libs/get_config.sh` | `scripts/libs/get_config.sh` | 加载配置 + 默认值 |
| `libs/set_config.sh` | `scripts/libs/set_config.sh` | `setconfig` 函数写 key=value |
| `libs/set_cron.sh` | `scripts/libs/set_cron.sh` | `cronset`/`cronload`/`cronadd` |
| `libs/check_autostart.sh` | `scripts/libs/check_autostart.sh` | 检查自启状态 |
| `libs/check_cpucore.sh` | `scripts/libs/check_cpucore.sh` | 检测 CPU 架构 |
| `menus/tui_layout.sh` | `scripts/menus/tui_layout.sh` | TUI 布局 (content_line/separator_line) |
| `menus/common.sh` | `scripts/menus/common.sh` | 通用组件 (comp_box/btm_box/msg_alert) |
| `menus/1_start.sh` | `scripts/menus/1_start.sh` | 启动服务 + 下载二进制 |
| `menus/2_settings.sh` | `scripts/menus/2_settings.sh` | 设置菜单 |
| `menus/3_stop.sh` | `scripts/menus/3_stop.sh` | 停止服务 |
| `menus/4_setboot.sh` | `scripts/menus/4_setboot.sh` | 开机自启设置 |
| `menus/5_status.sh` | `scripts/menus/5_status.sh` | 运行状态 |
| `menus/6_update.sh` | `scripts/menus/6_update.sh` | 更新版本 |
| `menus/uninstall.sh` | `scripts/menus/uninstall.sh` | 卸载 |
| `starts/snapshot_init.sh` | `scripts/starts/snapshot_init.sh` | 小米设备开机初始化 |

## 启动流程 (小米设备)

```
路由器开机
    │
    ▼
firewall include 触发 snapshot_init.sh
    │
    ├─ 等待 LAN 接口就绪 (ip a | grep lan)
    ├─ 等待网关连通 (ping gateway_ip)
    ├─ 执行 monitor.sh (下载/启动/上线)
    └─ 注册 cron 守护 (每分钟巡检)
           │
           ▼
       monitor.sh (cron 调用)
           ├─ 防并发锁
           ├─ ping 网关 → 网络就绪?
           ├─ tailscaled 存在?
           │   ├─ 不存在 → 下载二进制 → 启动 tailscaled
           │   └─ 存在 → 跳过
           ├─ 等待 tailscaled 就绪 (20s)
           └─ tailscale up (幂等操作)
```

## 核心特点

- **内存运行** — 二进制在 `/tmp/tailscale_run` (内存盘)，闪存零占用
- **状态持久化** — 登录凭证在 `/data/tailscale/state`，重启免认证
- **ShellCrash 同款启动** — `uci firewall include` + `snapshot_init.sh`
- **TUI 菜单** — 与 ShellCrash 一致的终端界面风格
- **cron 守护** — 每分钟巡检，崩溃自愈

## 快速安装

```sh
# SSH 登录路由器后
sh -c "$(curl -fsSL https://raw.githubusercontent.com/YOUR_USER/mirouter-tailscale/main/install.sh)"
```

## 使用

```sh
tsm                    # 打开管理菜单
tsm -s start           # 命令行启动
tsm -s stop            # 命令行停止
tsm -s restart         # 命令行重启
tsm -s status          # 命令行查看状态
```

## 目录结构

```
/data/tailscale/                   # TSDIR
├── configs/
│   └── ts.cfg                     # 配置文件 (key=value)
├── state/
│   └── tailscaled.state           # 登录凭证
├── scripts/
│   ├── menu.sh                    # 主菜单入口
│   ├── start.sh                   # 服务控制
│   ├── init.sh                    # 初始化
│   ├── libs/
│   │   ├── get_config.sh          # 加载配置
│   │   ├── set_config.sh          # 写入配置
│   │   ├── set_cron.sh            # Cron 管理
│   │   ├── check_autostart.sh     # 自启状态检查
│   │   ├── check_cpucore.sh       # 架构检测
│   │   └── logger.sh              # 日志
│   ├── menus/
│   │   ├── tui_layout.sh          # TUI 布局
│   │   ├── common.sh              # 通用组件
│   │   ├── 1_start.sh             # 启动
│   │   ├── 2_settings.sh          # 设置
│   │   ├── 3_stop.sh              # 停止
│   │   ├── 4_setboot.sh           # 开机自启
│   │   ├── 5_status.sh            # 状态
│   │   ├── 6_update.sh            # 更新
│   │   └── uninstall.sh           # 卸载
│   └── starts/
│       ├── snapshot_init.sh       # 小米开机初始化
│       └── monitor.sh             # Cron 监控守护
└── install.sh                     # 安装脚本备份

/tmp/tailscale_run/                # 内存运行目录
├── tailscale                      # 客户端
└── tailscaled                     # 守护进程
```

## 配置项

配置文件: `/data/tailscale/configs/ts.cfg`

| 变量 | 说明 | 默认值 |
|---|---|---|
| `gateway_ip` | 上级网关 IP | `192.168.1.1` |
| `auth_key` | Tailscale Auth Key | 必填 |
| `routes` | 子网路由 | — |
| `socks_port` | SOCKS5 端口 | `1055` |
| `use_exit_node` | 出口节点 | `ON` |
| `accept_dns` | Accept DNS | `false` |
| `snat_subnet` | SNAT Subnet | `false` |
| `ts_version` | 版本号 | `1.78.1` |
| `arch` | 架构 | 自动检测 |
| `pkg_url` | 自定义下载源 | 官网 |

## 常见问题

### 官网下载太慢？
在菜单 [2] 设置 → [9] 自定义下载源 中改为局域网地址：
```
http://192.168.31.12:8000/tailscale_1.78.1_arm64.tgz
```

### 重启后 Tailscale 还在吗？
二进制会丢失（内存盘），但 cron 守护会自动重新下载。登录状态在 `/data` 中，无需重新认证。

### 如何验证？
```sh
tsm -s status
/tmp/tailscale_run/tailscale status
```

## 致谢

- [ShellCrash](https://github.com/juewuy/ShellCrash) — 架构和管理模式参考
- [dgj8300 (CSDN)](https://blog.csdn.net/dgj8300) — 小米路由器 Tailscale 系列文章
- [恩山论坛 8467692](https://www.right.com.cn/forum/thread-8467692-1-1.html) — 实操方案参考

## License

MIT
