# mirouter-tailscale

小米/红米路由器 Tailscale 管理脚本，严格参考 [ShellCrash](https://github.com/juewuy/ShellCrash) 的架构设计。

解决原厂系统闪存空间不足的问题：二进制文件运行在内存盘 (`/tmp`)，状态文件持久化到 `/data`，脚本全自动下载、启动、守护、崩溃恢复。

## 快速安装

```sh
# SSH 登录路由器后执行
# 国内推荐
sh -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/mizuka-wu/mirouter-tailscale@main/install.sh)"

# 备用
sh -c "$(curl -fsSL https://raw.githubusercontent.com/mizuka-wu/mirouter-tailscale/main/install.sh)"
```

安装完成后输入 `tsm` 打开管理菜单。

## 使用

```
tsm                    # 交互式管理菜单
tsm -s start           # 命令行启动
tsm -s stop            # 命令行停止
tsm -s restart         # 命令行重启
tsm -s status          # 命令行查看状态
```

菜单界面：

```
 ==========================================================
  Tailscale 管理脚本
 ==========================================================
  运行状态: 运行中 (PID: 1234)  |  自启: ON
 ---------------------------------------------------------
 1) 启动服务
 2) 设置
 3) 停止服务
 4) 开机自启
 5) 运行状态
 6) 更新版本
 7) 卸载

 0) 退出
 ==========================================================
```

## 前置条件

- 路由器已获取 SSH 权限
- Tailscale Auth Key（从 https://login.tailscale.com/admin/settings/keys 生成）
- 路由器能访问外网（用于下载 Tailscale 二进制，也可使用局域网下载源）

## 启动流程

### 小米设备 (mi_snapshot)

小米设备通过 `uci firewall include` 注册开机脚本，与 ShellCrash 使用相同机制：

```
路由器开机
    │
    ▼
防火墙触发 snapshot_init.sh
    │
    ├─ 等待 LAN 接口就绪: while ! ip a | grep -q lan (最多 90s)
    ├─ 等待网关连通: ping gateway_ip (最多 60s)
    ├─ 执行 monitor.sh
    └─ 注册 cron 守护: * * * * * monitor.sh (每分钟巡检)
```

### monitor.sh (核心守护逻辑)

cron 每分钟调用一次，负责拉起服务：

```
monitor.sh
    │
    ├─ 防并发锁: [ -f /tmp/ts_monitor.lock ] && exit 0
    ├─ ping 网关 → 网络不通则退出等待下次
    │
    ├─ pidof tailscaled → 进程存在?
    │   ├─ 不存在
    │   │   ├─ /tmp/tailscale_run/tailscaled 存在?
    │   │   │   ├─ 不存在 → curl 下载 tar.gz → 解压 → chmod +x
    │   │   │   └─ 存在 → 跳过下载
    │   │   └─ 启动 tailscaled (userspace-networking + socks5)
    │   └─ 存在 → 跳过
    │
    ├─ 等待就绪: 循环 20s 检查 tailscale status
    └─ tailscale up (幂等操作)
        ├─ --authkey
        ├─ --advertise-routes (子网路由)
        ├─ --advertise-exit-node (出口节点)
        ├─ --accept-dns
        └─ --snat-subnet-routes
```

### 保守模式 (非小米设备 / 备用)

如果 `uci firewall` 不可用，可通过菜单 [4] 开启保守模式，仅依赖 cron 轮询，不依赖 rc.local 或 uci。

## 各脚本职责

### install.sh — 一键安装器

| 步骤 | 函数 | 说明 |
|------|------|------|
| 1 | `check_user` | 必须 root 权限 |
| 2 | `check_systype` | 识别 mi_snapshot / Padavan / asusrouter / generic |
| 3 | `check_arch` | `uname -ms` 检测 arm64 / armv7 / amd64 / mipsle |
| 4 | `setdir` | 小米默认 `/data`，其他可选目录 |
| 5 | `gettar` | curl 下载 GitHub tar.gz → 解压到 TSDIR |
| 6 | `init.sh` | 运行初始化脚本 |

### scripts/init.sh — 初始化

- 创建目录结构 (configs/ state/ starts/ scripts/)
- 运行 `check_cpucore` 写入架构
- `chmod +x` 所有脚本
- 写入 `/etc/profile` 环境变量 + `alias tsm`
- 创建 `/usr/bin/tsm` 快捷命令
- 小米设备额外拷贝 `snapshot_init.sh` 到 `/data/`

### scripts/menu.sh — 主菜单入口

- 加载所有 libs (get_config → set_config → set_cron → check_cpucore → check_autostart → logger)
- 加载所有 menus (tui_layout → common → 1~6 → uninstall)
- `ckstatus`: 检查进程 PID、自启状态、首次运行引导配置
- 主循环: 7 个菜单项 + 0 退出
- 支持 `-s` 命令行参数

### scripts/start.sh — 服务控制

- 加载 libs + 启动/停止模块
- `case` 分发: start / stop / restart / status / up / cronset

### scripts/check.sh — 环境预检

在实际启动前验证所有前置条件，不启动任何服务：

```
[1/8] 用户权限       → root?
[2/8] CPU 架构       → arm64/armv7/amd64?
[3/8] /data 分区     → 存在且可写?
[4/8] 安装目录       → TSDIR 存在? ts.cfg 存在?
[5/8] 脚本权限       → 所有 .sh 可执行?
[6/8] 配置项         → auth_key 已配置?
[7/8] 网络连通性     → 网关可达? pkgs.tailscale.com 可达?
[8/8] Tailscale 二进制 → 已下载? 进程运行中?
```

输出 PASS/FAIL/WARN 汇总，有失败项会告诉你具体原因。

## libs/ 工具库

| 脚本 | 函数 | 说明 |
|------|------|------|
| `get_config.sh` | — | 加载 ts.cfg，设所有默认值，计算 PKG_URL / BIN_TS / BIN_TSD |
| `set_config.sh` | `setconfig(key, value, [file])` | sed 删旧行 + printf 写新行到 .cfg |
| `set_cron.sh` | `cronadd(file)` | crontab 或直接写 crondir |
| | `cronload()` | 读取当前 crontab |
| | `cronset(keyword, new_line)` | 删除含 keyword 的行 + 添加新行 |
| `check_autostart.sh` | `check_autostart()` | 检查 uci firewall / rc.local / cron |
| `check_cpucore.sh` | `check_cpucore()` | uname 检测架构写入 arch 变量 |
| `logger.sh` | `ts_logger(level, msg)` | 终端彩色输出 + 写日志文件 |

## menus/ 菜单

| 脚本 | 菜单项 | 功能 |
|------|--------|------|
| `1_start.sh` | [1] 启动 | 检查 PID → 下载二进制 → 启动 tailscaled → 等待就绪 → tailscale up → 注册 cron |
| `2_settings.sh` | [2] 设置 | 9 项可配置: 网关IP / Auth Key / 子网路由 / 端口 / 出口节点 / DNS / SNAT / 版本 / 下载源 |
| `3_stop.sh` | [3] 停止 | killall tailscaled → 清除锁文件 |
| `4_setboot.sh` | [4] 自启 | uci firewall include (小米) / rc.local (通用) / 保守模式 (仅cron) |
| `5_status.sh` | [5] 状态 | PID / 二进制 / 自启状态 / 配置详情 / tailscale status |
| `6_update.sh` | [6] 更新 | 输入新版本号 → 停服务 → 删旧二进制 → 下次启动自动下载 |
| `uninstall.sh` | [7] 卸载 | 停服务 → 清 cron → 删 uci → 还原 rc.local → 删环境变量 → 删 TSDIR |

## starts/ 启动脚本

| 脚本 | 触发方式 | 说明 |
|------|----------|------|
| `snapshot_init.sh` | uci firewall include | 小米开机初始化: 等网络 → 执行 monitor → 注册 cron |
| `monitor.sh` | cron 每分钟 | 核心守护: 检查进程 → 下载 → 启动 → 上线 |

## 配置项

配置文件: `/data/tailscale/configs/ts.cfg` (通过 `tsm` 菜单修改)

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `gateway_ip` | 上级网关 IP，用于检测网络就绪 | `192.168.1.1` |
| `auth_key` | Tailscale 认证密钥 | **必填** |
| `routes` | 宣告的子网路由 (逗号分隔) | — |
| `socks_port` | SOCKS5 代理端口 | `1055` |
| `use_exit_node` | 是否作为出口节点 | `ON` |
| `accept_dns` | 是否接受 Tailscale DNS | `false` |
| `snat_subnet` | 是否启用 SNAT | `false` |
| `ts_version` | Tailscale 版本号 | `1.78.1` |
| `arch` | CPU 架构 | 自动检测 |
| `pkg_url` | 自定义下载源 URL | 官网 |

## 目录结构

```
/data/tailscale/                       # TSDIR (持久化)
├── configs/
│   └── ts.cfg                         # 配置文件 (key=value)
├── state/
│   └── tailscaled.state               # 登录凭证 (几KB)
├── scripts/
│   ├── menu.sh                        # 主菜单入口
│   ├── start.sh                       # 服务控制 (start/stop/restart)
│   ├── init.sh                        # 初始化
│   ├── check.sh                       # 环境预检
│   ├── libs/                          # 工具库
│   │   ├── get_config.sh
│   │   ├── set_config.sh
│   │   ├── set_cron.sh
│   │   ├── check_autostart.sh
│   │   ├── check_cpucore.sh
│   │   └── logger.sh
│   ├── menus/                         # 菜单模块
│   │   ├── tui_layout.sh              # TUI 布局引擎
│   │   ├── common.sh                  # 通用组件
│   │   ├── 1_start.sh ~ 6_update.sh
│   │   └── uninstall.sh
│   └── starts/                        # 启动脚本
│       ├── snapshot_init.sh           # 小米开机初始化
│       └── monitor.sh                 # Cron 监控守护

/tmp/tailscale_run/                    # 内存运行目录 (重启清空)
├── tailscale                          # Tailscale 客户端 (~25MB)
└── tailscaled                         # Tailscale 守护进程 (~25MB)
```

## 常见问题

### 官网下载太慢？

在菜单 [2] 设置 → [9] 自定义下载源 中改为局域网地址。在 NAS 或小主机上搭建简单 HTTP 服务：

```sh
# 在 NAS 上
python3 -m http.server 8000 --directory /path/to/tailscale/

# 然后在路由器 tsm 菜单中设置下载源为:
# http://192.168.31.12:8000/tailscale_1.78.1_arm64.tgz
```

### 重启后配置丢了？

不会。所有配置和脚本在 `/data/tailscale/`，这是用户分区，重启不丢。二进制文件在内存盘会丢失，但 cron 守护会自动重新下载，登录凭证在 `/data` 中，无需重新认证。

### 提示 NoState 或 context canceled？

正常现象。`tailscaled` 刚启动还没连上控制平面，脚本内置了 20 秒等待，一般几秒后状态就会变 online。

### 占用多少闪存？

脚本约 50KB + 配置文件约 1KB + 状态文件约 4KB。二进制在内存盘，闪存零占用。

### 如何验证是否工作？

```sh
tsm -s status                              # 查看运行状态
/tmp/tailscale_run/tailscale status        # Tailscale 网络状态
/tmp/tailscale_run/tailscale ping <peer>   # 测试连通性
```

## 与 ShellCrash 的对应关系

| ShellCrash | mirouter-tailscale | 说明 |
|---|---|---|
| `install.sh` | `install.sh` | 一键安装器 |
| `menu.sh` | `scripts/menu.sh` | 主菜单入口 |
| `start.sh` | `scripts/start.sh` | 服务控制 |
| `init.sh` | `scripts/init.sh` | 初始化 |
| `libs/get_config.sh` | `scripts/libs/get_config.sh` | 加载配置 |
| `libs/set_config.sh` | `scripts/libs/set_config.sh` | 写入配置 |
| `libs/set_cron.sh` | `scripts/libs/set_cron.sh` | Cron 管理 |
| `libs/check_autostart.sh` | `scripts/libs/check_autostart.sh` | 自启状态检查 |
| `libs/check_cpucore.sh` | `scripts/libs/check_cpucore.sh` | 架构检测 |
| `menus/tui_layout.sh` | `scripts/menus/tui_layout.sh` | TUI 布局引擎 |
| `menus/common.sh` | `scripts/menus/common.sh` | 通用组件 |
| `menus/1_start.sh` ~ `9_upgrade.sh` | `scripts/menus/1_start.sh` ~ `6_update.sh` | 各功能菜单 |
| `starts/snapshot_init.sh` | `scripts/starts/snapshot_init.sh` | 小米开机初始化 |

## 致谢

- [ShellCrash](https://github.com/juewuy/ShellCrash) — 架构和管理模式参考
- [dgj8300 (CSDN)](https://blog.csdn.net/dgj8300) — 小米路由器 Tailscale 安装系列文章
- [恩山论坛 8467692](https://www.right.com.cn/forum/thread-8467692-1-1.html) — 实操方案参考

## License

MIT
