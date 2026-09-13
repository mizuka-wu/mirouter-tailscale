# 停止服务

stop_service() {
    if ! pidof tailscaled >/dev/null 2>&1; then
        msg_alert "\033[33mTailscale 未在运行\033[0m"
        return 0
    fi

    comp_box "\033[36m正在停止 Tailscale ...\033[0m"
    killall tailscaled 2>/dev/null
    sleep 1
    killall -9 tailscaled 2>/dev/null
    rm -f "$LOCK_FILE"

    msg_alert "\033[32mTailscale 已停止\033[0m"
}
