# 加载配置文件
[ -z "$TSDIR" ] && TSDIR=$(
    cd "$(dirname "$0")/.."
    pwd
)
CFG_PATH="$TSDIR/configs/ts.cfg"
STATE_DIR="$TSDIR/state"
TMP_DIR="/tmp/tailscale_run"
LOCK_FILE="/tmp/ts_monitor.lock"

# 确保配置文件存在
[ -f "$CFG_PATH" ] || echo '# Tailscale 配置文件，不明勿动！' >"$CFG_PATH"
. "$CFG_PATH"

# 默认值
[ -z "$test_host" ] && test_host="223.5.5.5"
[ -z "$ts_version" ] && ts_version="1.102.4"
[ -z "$arch" ] && arch="arm64"
[ -z "$accept_dns" ] && accept_dns="false"
[ -z "$snat_subnet" ] && snat_subnet="true"
[ -z "$hostname" ] && hostname="$(uname -n)"

# 自动检测 tun 支持
check_tun_support() {
    [ -c /dev/net/tun ] && { tun_available=1; return; }
    modprobe tun 2>/dev/null
    [ -c /dev/net/tun ] && { tun_available=1; return; }
    tun_available=0
}
check_tun_support

# 自动设置运行模式 (不手动选，自动判断)
if [ "$tun_available" = "1" ]; then
    ts_mode="tun"
else
    ts_mode="userspace"
fi

# 自动检测子网路由 (从 LAN 接口读取)
auto_detect_routes() {
    local lan_cidr
    # 方法1: ubus (小米/OpenWrt)
    lan_cidr=$(ubus call network.interface.lan status 2>/dev/null | grep -oE '"address":"[0-9.]+"' | grep -oE '[0-9.]+')
    if [ -z "$lan_cidr" ]; then
        # 方法2: 从 ip addr 读 br-lan / lan 接口
        lan_cidr=$(ip addr show br-lan 2>/dev/null | grep 'inet ' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    fi
    if [ -z "$lan_cidr" ]; then
        # 方法3: 从 ip route 读默认 LAN
        lan_cidr=$(ip route 2>/dev/null | grep 'src' | grep -v 'default' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    fi
    if [ -n "$lan_cidr" ]; then
        # 192.168.3.100 → 192.168.3.0/24
        auto_routes=$(echo "$lan_cidr" | sed 's/\.[0-9]*$/.0\/24/')
    fi
}
auto_detect_routes

# 如果没配置过路由，使用自动检测的
if [ -z "$routes" ] && [ -n "$auto_routes" ]; then
    routes="$auto_routes"
fi

# 计算派生变量
BIN_TS="$TMP_DIR/tailscale"
BIN_TSD="$TMP_DIR/tailscaled"
STATE_FILE="$STATE_DIR/tailscaled.state"

# Tailscale 二进制下载镜像列表
