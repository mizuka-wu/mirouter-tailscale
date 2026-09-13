#!/bin/sh
# 小米设备开机初始化脚本
# 通过 uci firewall include 触发 (与 ShellCrash 一致)

TSDIR="$(uci get firewall.tailscale.path 2>/dev/null | sed 's|/starts.*||')"
[ -z "$TSDIR" ] && TSDIR="/data/tailscale"

# 防止重复启动
pidof tailscaled >/dev/null 2>&1 && exit 0

# 加载配置
CFG_PATH="$TSDIR/configs/ts.cfg"
[ -f "$CFG_PATH" ] || exit 1
. "$CFG_PATH"
gateway_ip="${gateway_ip:-192.168.1.1}"

# 等待网络就绪 (与 ShellCrash 一致: 等待 LAN 接口出现)
i=0
while ! ip a | grep -q lan; do
    [ $i -gt 30 ] && exit 1
    i=$((i + 1))
    sleep 3
done

# 额外等待网关连通 (Tailscale 下载需要外网)
n=0
while [ $n -lt 20 ]; do
    ping -c 1 -W 1 "$gateway_ip" >/dev/null 2>&1 && break
    sleep 3
    n=$((n+1))
done

# 启动监控脚本
MONITOR="$TSDIR/starts/monitor.sh"
if [ -x "$MONITOR" ]; then
    # 清除残留锁
    rm -f /tmp/ts_monitor.lock
    "$MONITOR" >/dev/null 2>&1
fi

# 注册 cron 守护 (兜底)
sed -i '/ts_monitor/d' /etc/crontabs/root 2>/dev/null
echo "* * * * * $MONITOR >/dev/null 2>&1 #ts_monitor" >> /etc/crontabs/root
/etc/init.d/cron restart 2>/dev/null

# 启动自定义脚本 (如有)
[ -s /data/auto_start.sh ] && /bin/sh /data/auto_start.sh &
