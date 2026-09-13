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
[ -z "$gateway_ip" ] && gateway_ip="192.168.1.1"
[ -z "$socks_port" ] && socks_port="1055"
[ -z "$ts_version" ] && ts_version="1.78.1"
[ -z "$arch" ] && arch="arm64"
[ -z "$accept_dns" ] && accept_dns="false"
[ -z "$snat_subnet" ] && snat_subnet="false"
[ -z "$use_exit_node" ] && use_exit_node="ON"
[ -z "$network_check" ] && network_check="ON"

# 计算派生变量
BIN_TS="$TMP_DIR/tailscale"
BIN_TSD="$TMP_DIR/tailscaled"
STATE_FILE="$STATE_DIR/tailscaled.state"

# Tailscale 二进制镜像列表 (优先国内 CDN)
TS_PKG_MIRRORS="
${pkg_url}
https://ghfast.top/https://github.com/tailscale/tailscale/releases/download/v${ts_version}/tailscale_${ts_version}_${arch}.tgz
https://ghproxy.cn/https://github.com/tailscale/tailscale/releases/download/v${ts_version}/tailscale_${ts_version}_${arch}.tgz
https://pkgs.tailscale.com/stable/tailscale_${ts_version}_${arch}.tgz
"
