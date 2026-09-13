#!/bin/sh
# Tailscale 环境检查脚本
# 在实际启动前运行，验证所有前置条件

TSDIR="${TSDIR:-/data/tailscale}"
CFG_PATH="$TSDIR/configs/ts.cfg"
TMP_DIR="/tmp/tailscale_run"
BIN_TSD="$TMP_DIR/tailscaled"
PASS=0
FAIL=0
WARN=0

cecho() { printf '%b\n' "$*"; }
check_pass() { cecho "  \033[32m[PASS]\033[0m $1"; PASS=$((PASS+1)); }
check_fail() { cecho "  \033[31m[FAIL]\033[0m $1"; FAIL=$((FAIL+1)); }
check_warn() { cecho "  \033[33m[WARN]\033[0m $1"; WARN=$((WARN+1)); }

cecho "\033[36m========================================\033[0m"
cecho "\033[36m  Tailscale 环境检查\033[0m"
cecho "\033[36m========================================\033[0m"
cecho ""

# 1. 权限检查
cecho "\033[1m[1/8] 用户权限\033[0m"
if [ "$(id -u)" -eq 0 ]; then
    check_pass "root 用户"
else
    check_fail "非 root 用户 ($(whoami))，需要 root 权限"
fi

# 2. 架构检查
cecho "\033[1m[2/8] CPU 架构\033[0m"
arch=$(uname -m)
cecho "  架构: $arch"
case "$arch" in
    aarch64|arm64|armv7l|armv8*) check_pass "支持的架构: $arch" ;;
    x86_64) check_pass "支持的架构: $arch" ;;
    *) check_warn "未测试的架构: $arch，可能需要手动指定 arch" ;;
esac

# 3. /data 分区检查
cecho "\033[1m[3/8] /data 分区\033[0m"
if [ -d /data ] && [ -w /data ]; then
    local_avail=$(df -P /data 2>/dev/null | awk 'NR==2 {print $4}')
    check_pass "/data 可写 (可用: ${local_avail}KB)"
else
    check_fail "/data 不存在或不可写"
fi

# 4. 安装目录检查
cecho "\033[1m[4/8] 安装目录\033[0m"
if [ -d "$TSDIR" ]; then
    check_pass "TSDIR=$TSDIR 存在"
else
    check_fail "TSDIR=$TSDIR 不存在，请先运行 install.sh"
fi
if [ -f "$TSDIR/configs/ts.cfg" ]; then
    check_pass "配置文件存在"
    . "$TSDIR/configs/ts.cfg"
else
    check_fail "配置文件不存在: $TSDIR/configs/ts.cfg"
fi

# 5. 脚本权限检查
cecho "\033[1m[5/8] 脚本权限\033[0m"
for script in "$TSDIR/scripts/menu.sh" "$TSDIR/scripts/start.sh" "$TSDIR/scripts/starts/monitor.sh" "$TSDIR/scripts/starts/snapshot_init.sh"; do
    if [ -x "$script" ]; then
        check_pass "$(basename $script) 可执行"
    elif [ -f "$script" ]; then
        check_warn "$(basename $script) 存在但不可执行，运行: chmod +x $script"
    else
        check_fail "$(basename $script) 不存在"
    fi
done

# 6. 配置检查
cecho "\033[1m[6/8] 配置项\033[0m"
test_host="${test_host:-192.168.1.1}"
cecho "  测试地址: $test_host"
if [ -n "$auth_key" ]; then
    check_pass "Auth Key 已配置"
else
    check_fail "Auth Key 未配置！请在 tsm 菜单 [2] 设置中配置"
fi
cecho "  子网路由: ${routes:-未配置}"
cecho "  出口节点: ${use_exit_node:-ON}"
cecho "  SOCKS5 端口: ${socks_port:-1055}"

# 7. 网络检查
cecho "\033[1m[7/8] 网络连通性\033[0m"
if ping -c 1 -W 2 "$test_host" >/dev/null 2>&1; then
    check_pass "网关 $test_host 可达"
else
    check_fail "网关 $test_host 不可达"
fi
# 检查 DNS
if ping -c 1 -W 2 pkgs.tailscale.com >/dev/null 2>&1; then
    check_pass "pkgs.tailscale.com 可达"
else
    check_warn "pkgs.tailscale.com 不可达 (可使用局域网下载源)"
fi

# 8. 二进制文件检查
cecho "\033[1m[8/8] Tailscale 二进制\033[0m"
if [ -x "$BIN_TSD" ]; then
    check_pass "tailscaled 已就绪 ($BIN_TSD)"
else
    check_warn "tailscaled 未下载 (启动时会自动下载)"
fi
if pidof tailscaled >/dev/null 2>&1; then
    check_pass "tailscaled 进程运行中"
else
    cecho "  tailscaled 未运行"
fi

# 汇总
cecho ""
cecho "\033[36m========================================\033[0m"
cecho "  结果: \033[32m${PASS} 通过\033[0m  \033[31m${FAIL} 失败\033[0m  \033[33m${WARN} 警告\033[0m"
if [ $FAIL -eq 0 ]; then
    cecho "  \033[32m环境检查通过，可以尝试启动！\033[0m"
else
    cecho "  \033[31m有 $FAIL 项检查失败，请先修复后再启动\033[0m"
fi
cecho "\033[36m========================================\033[0m"

exit $FAIL
