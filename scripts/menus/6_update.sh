# 更新版本

update_version() {
    comp_box "\033[30;47m 更新 Tailscale \033[0m"
    content_line "当前版本: \033[36m$ts_version\033[0m"
    separator_line "-"

    # 查询最新版本
    content_line "正在查询最新版本..."
    latest=$(curl -sL "https://pkgs.tailscale.com/stable/?mode=json" 2>/dev/null | sed -n 's/.*tailscale_\([0-9.]*\)_arm64.tgz.*/\1/p' | head -1)
    if [ -n "$latest" ]; then
        content_line "最新版本: \033[32m$latest\033[0m"
    else
        content_line "最新版本: \033[33m查询失败\033[0m"
    fi

    separator_line "-"
    content_line "1) 更新到最新版本"
    content_line "2) 手动指定版本号"
    btm_box "0) 返回"
    read -r -p "请选择 > " num

    case "$num" in
    "" | 0) return ;;
    1)
        if [ -z "$latest" ]; then
            msg_alert "\033[31m无法获取最新版本，请手动指定\033[0m"
            return
        fi
        new_version="$latest"
        ;;
    2)
        read -r -p "请输入版本号: " new_version
        [ -z "$new_version" ] && return
        ;;
    *)
        errornum
        return
        ;;
    esac

    if [ "$new_version" = "$ts_version" ]; then
        msg_alert "\033[33m版本相同，无需更新\033[0m"
        return
    fi

    comp_box "\033[36m正在更新: $ts_version → $new_version\033[0m"

    # 1. 停止服务
    content_line "停止当前服务..."
    if pidof tailscaled >/dev/null 2>&1; then
        killall tailscaled 2>/dev/null
        sleep 1
        killall -9 tailscaled 2>/dev/null
    fi
    rm -f "$LOCK_FILE"

    # 2. 清除旧二进制
    content_line "清除旧版本二进制..."
    rm -rf "$TMP_DIR"

    # 3. 更新配置
    setconfig ts_version "$new_version"
    ts_version="$new_version"
    setconfig pkg_url "" && pkg_url=""

    # 4. 重新启动 (会自动下载新版本)
    content_line "准备下载新版本 v${new_version}..."
    separator_line "-"
    start_service
}
