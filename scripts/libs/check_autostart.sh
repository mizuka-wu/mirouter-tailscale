# 检查开机自启状态
check_autostart() {
    # 小米设备：检查 uci firewall include
    if uci get firewall.tailscale >/dev/null 2>&1; then
        [ "$(uci get firewall.tailscale.enabled 2>/dev/null)" != "0" ] && return 0
    fi
    # 保守模式：检查 rc.local
    if [ -f /etc/rc.local ] && grep -q 'tailscale' /etc/rc.local 2>/dev/null; then
        return 0
    fi
    # 检查 cron 守护
    if cronload 2>/dev/null | grep -q 'monitor.sh'; then
        return 0
    fi
    return 1
}
