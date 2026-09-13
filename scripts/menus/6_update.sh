# 更新版本

update_version() {
    comp_box "\033[30;47m 更新 Tailscale \033[0m"
    content_line "当前版本: \033[36m$ts_version\033[0m"
    separator_line "-"
    read -r -p "请输入新版本号 (如 1.80.0，直接回车取消): " input
    if [ -z "$input" ]; then
        msg_alert "\033[33m已取消\033[0m"
        return
    fi

    setconfig ts_version "$input"
    ts_version="$input"
    # 清除自定义URL
    setconfig pkg_url ""
    pkg_url=""
    PKG_URL="https://pkgs.tailscale.com/stable/tailscale_${ts_version}_${arch}.tgz"

    # 停止服务
    if pidof tailscaled >/dev/null 2>&1; then
        content_line "正在停止旧版本..."
        killall tailscaled 2>/dev/null
        sleep 1
        killall -9 tailscaled 2>/dev/null
    fi

    # 清除旧二进制
    rm -rf "$TMP_DIR"
    content_line "已清除旧版本，将在下次启动时自动下载 v${ts_version}"

    msg_alert "\033[32m版本已更新为 $ts_version\033[0m"
}
