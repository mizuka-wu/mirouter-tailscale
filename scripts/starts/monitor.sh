#!/bin/sh
# Tailscale 监控守护脚本 (cron 每分钟调用)

TSDIR="/data/tailscale"
CFG_PATH="$TSDIR/configs/ts.cfg"
TMP_DIR="/tmp/tailscale_run"
BIN_TS="$TMP_DIR/tailscale"
BIN_TSD="$TMP_DIR/tailscaled"
STATE_DIR="$TSDIR/state"
STATE_FILE="$STATE_DIR/tailscaled.state"
LOCK_FILE="/tmp/ts_monitor.lock"
LOG_FILE="/tmp/tailscale_run/monitor.log"

log() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null
}

# 加载配置
[ -f "$CFG_PATH" ] && . "$CFG_PATH"
test_host="${test_host:-223.5.5.5}"
ts_version="${ts_version:-1.78.1}"
arch="${arch:-arm64}"
accept_dns="${accept_dns:-false}"
snat_subnet="${snat_subnet:-false}"
ts_mode="${ts_mode:-tun}"

# 防并发锁
[ -f "$LOCK_FILE" ] && exit 0
touch "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# 1. 等待网络就绪
if ! ping -c 1 -W 1 "$test_host" >/dev/null 2>&1; then
    log "网络未就绪 ($test_host 不可达)"
    exit 0
fi

# 2. 进程不存在则拉起
if ! pidof tailscaled >/dev/null 2>&1; then

    # 2.1 下载二进制 (如果内存中没有)
    if [ ! -x "$BIN_TSD" ]; then
        mkdir -p "$TMP_DIR"
        cd "$TMP_DIR" || exit 0

        log "开始下载 Tailscale v${ts_version} ..."

        download_ok=0
        for url in \
            "${pkg_url}" \
            "https://pkgs.tailscale.com/stable/tailscale_${ts_version}_${arch}.tgz" \
            "https://ghfast.top/https://github.com/tailscale/tailscale/releases/download/v${ts_version}/tailscale_${ts_version}_${arch}.tgz" \
            "https://ghproxy.cn/https://github.com/tailscale/tailscale/releases/download/v${ts_version}/tailscale_${ts_version}_${arch}.tgz"; do

            [ -z "$url" ] && continue
            host=$(echo "$url" | sed 's|https\?://||' | cut -d'/' -f1)
            log "尝试下载: $host"

            curl -L --connect-timeout 10 --max-time 300 -o tailscale.tgz "$url" 2>/tmp/ts_monitor_curl.log
            if [ $? -eq 0 ] && [ -s tailscale.tgz ]; then
                download_ok=1
                log "下载成功: $host"
                break
            else
                err=$(cat /tmp/ts_monitor_curl.log 2>/dev/null | tail -1)
                log "下载失败: $host - $err"
            fi
        done

        if [ "$download_ok" -ne 1 ]; then
            log "所有下载源失败"
            rm -f tailscale.tgz /tmp/ts_monitor_curl.log
            exit 0
        fi

        tar zxf tailscale.tgz >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            log "解压失败"
            rm -f tailscale.tgz
            exit 0
        fi

        local_dir="tailscale_${ts_version}_${arch}"
        mv "$local_dir/tailscale" "$TMP_DIR/" 2>/dev/null
        mv "$local_dir/tailscaled" "$TMP_DIR/" 2>/dev/null

        chmod +x "$BIN_TS" "$BIN_TSD"
        rm -rf tailscale.tgz "$local_dir" /tmp/ts_monitor_curl.log
        log "二进制就绪"
    fi

    # 2.2 启动 tailscaled
    mkdir -p "$STATE_DIR"

    if [ "$ts_mode" = "tun" ] && [ -c /dev/net/tun ]; then
        "$BIN_TSD" -state "$STATE_FILE" >/dev/null 2>&1 &
        log "启动 tailscaled (tun 模式)"
    else
        "$BIN_TSD" \
            -state "$STATE_FILE" \
            --tun=userspace-networking \
            --socks5-server=localhost:1055 \
            --outbound-http-proxy-listen=localhost:1055 \
            >/dev/null 2>&1 &
        log "启动 tailscaled (userspace 模式)"
    fi
fi

# 3. 等待服务就绪
i=0
while [ $i -lt 20 ]; do
    "$BIN_TS" status >/dev/null 2>&1 && break
    sleep 1
    i=$((i+1))
done

# 4. 执行上线
UP_ARGS="--timeout=20s"
[ -n "$auth_key" ] && UP_ARGS="$UP_ARGS --authkey=$auth_key"
UP_ARGS="$UP_ARGS --accept-dns=$accept_dns"
UP_ARGS="$UP_ARGS --snat-subnet-routes=$snat_subnet"
[ -n "$routes" ] && UP_ARGS="$UP_ARGS --advertise-routes=$routes"

# shellcheck disable=SC2086
"$BIN_TS" up $UP_ARGS >/dev/null 2>&1

log "tailscale up 完成"
exit 0
