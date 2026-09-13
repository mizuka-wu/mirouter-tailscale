# 设置菜单

settings() {
    while true; do
        local key_display="未配置"
        [ -n "$auth_key" ] && key_display="${auth_key:0:12}..."

        if [ "$ts_mode" = "tun" ]; then
            mode_display="\033[32mTun\033[0m"
        else
            mode_display="\033[33mUserspace\033[0m"
        fi
        [ "$tun_available" != "1" ] && mode_display="$mode_display \033[31m(无tun)\033[0m"

        comp_box "\033[30;47m Tailscale 设置 \033[0m"
        content_line "1) Auth Key       \033[36m$key_display\033[0m"
        content_line "2) 子网路由       \033[36m${routes:-未配置}\033[0m"
        content_line "3) 运行模式       $mode_display"
        content_line "4) 测试地址       \033[36m$test_host\033[0m"
        content_line "5) Tailscale 版本 \033[36m$ts_version\033[0m"
        content_line "6) 自定义下载源   \033[36m${pkg_url:-默认}\033[0m"
        btm_box "0) 返回"
        read -r -p "请选择 > " num
        echo ""

        case "$num" in
        "" | 0) break ;;
        1)
            comp_box "\033[36mAuth Key\033[0m" \
                "路由器加入 Tailscale 网络的凭证" \
                "获取: https://login.tailscale.com/admin/settings/keys" \
                "" \
                "留空则启动后需手动在网页确认登录"
            separator_line "-"
            read -r -p "Auth Key: " input
            [ -n "$input" ] && setconfig auth_key "$input" && auth_key="$input"
            ;;
        2)
            comp_box "\033[36m子网路由\033[0m" \
                "宣告给 Tailscale 的内网网段" \
                "其他 Tailscale 设备可通过此路由访问你的内网" \
                "" \
                "例如路由器是 192.168.3.1:" \
                "  填 192.168.3.0/24" \
                "  NAS (192.168.3.x) 就能被远程访问"
            separator_line "-"
            read -r -p "子网路由: " input
            [ -n "$input" ] && setconfig routes "$input" && routes="$input"
            ;;
        3)
            comp_box "\033[36m运行模式\033[0m" \
                "\033[32mTun\033[0m — 内核级路由，子网路由必须用这个" \
                "  需要 /dev/net/tun，小米 AX6000 等设备支持" \
                "" \
                "\033[33mUserspace\033[0m — 兼容模式，不依赖 tun" \
                "  通过 SOCKS5 代理工作，其他设备需配代理" \
                "  子网路由功能受限"
            separator_line "-"
            if [ "$tun_available" = "1" ]; then
                content_line "当前内核: \033[32m支持 Tun\033[0m"
            else
                content_line "当前内核: \033[31m不支持 Tun\033[0m"
            fi
            separator_line "-"
            if [ "$tun_available" = "1" ]; then
                if [ "$ts_mode" = "tun" ]; then
                    read -r -p "切换为 Userspace? [y/N]: " x
                    case "$x" in [yY]*) setconfig ts_mode userspace && ts_mode="userspace"; msg_alert "已切换" ;; esac
                else
                    read -r -p "切换为 Tun? [y/N]: " x
                    case "$x" in [yY]*) setconfig ts_mode tun && ts_mode="tun"; msg_alert "已切换" ;; esac
                fi
            else
                msg_alert "\033[33m内核不支持 Tun，无法切换\033[0m"
            fi
            ;;
        4)
            read -r -p "网络测试地址 (检测网络就绪) [$test_host]: " input
            [ -n "$input" ] && setconfig test_host "$input" && test_host="$input"
            ;;
        5)
            read -r -p "Tailscale 版本号 [$ts_version]: " input
            if [ -n "$input" ]; then
                setconfig ts_version "$input" && ts_version="$input"
                setconfig pkg_url "" && pkg_url=""
            fi
            ;;
        6)
            read -r -p "自定义下载源URL (留空恢复默认): " input
            if [ -n "$input" ]; then
                setconfig pkg_url "$input" && pkg_url="$input"
            else
                setconfig pkg_url "" && pkg_url=""
            fi
            ;;
        *)
            errornum
            ;;
        esac
    done
}
