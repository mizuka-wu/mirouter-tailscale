# 设置菜单

settings() {
    while true; do
        key_display="未配置"
        [ -n "$auth_key" ] && key_display="${auth_key:0:12}..."

        if [ "$ts_mode" = "tun" ]; then
            mode_display="\033[32mTun\033[0m (内核路由)"
        else
            mode_display="\033[33mUserspace\033[0m (兼容模式)"
        fi

        route_display="${routes:-\033[31m未配置\033[0m}"
        [ -n "$auto_routes" ] && [ "$routes" = "$auto_routes" ] && route_display="$routes (自动检测)"

        host_display="${hostname:-$(uname -n)}"

        comp_box "\033[30;47m Tailscale 设置 \033[0m"
        content_line "1) Auth Key       \033[36m$key_display\033[0m"
        content_line "2) 节点名称       \033[36m$host_display\033[0m"
        content_line "3) 子网路由       \033[36m$route_display\033[0m"
        content_line "4) 运行模式       $mode_display"
        content_line "5) 测试地址       \033[36m$test_host\033[0m"
        content_line "6) Tailscale 版本 \033[36m$ts_version\033[0m"
        content_line "7) 自定义下载源   \033[36m${pkg_url:-默认}\033[0m"
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
            comp_box "\033[36m节点名称\033[0m" \
                "在 Tailscale 网络中显示的设备名称" \
                "留空则使用系统主机名: $(uname -n)"
            separator_line "-"
            read -r -p "节点名称 [${hostname:-$(uname -n)}]: " input
            if [ -n "$input" ]; then
                setconfig hostname "$input" && hostname="$input"
            fi
            ;;
        3)
            comp_box "\033[36m子网路由\033[0m" \
                "宣告给 Tailscale 的内网网段" \
                "其他 Tailscale 设备可通过此访问你的内网 (如 NAS)" \
                "" \
                "多个网段用逗号分隔: 192.168.3.0/24,192.168.1.0/24"
            if [ -n "$auto_routes" ]; then
                content_line ""
                content_line "自动检测到: \033[32m$auto_routes\033[0m"
            fi
            separator_line "-"
            read -r -p "子网路由 [${routes}]: " input
            [ -n "$input" ] && setconfig routes "$input" && routes="$input"
            ;;
        4)
            comp_box "\033[36m运行模式\033[0m" \
                "\033[32mTun\033[0m: 内核级路由，子网路由必须用这个" \
                "  需要 /dev/net/tun，小米 AX6000 等支持" \
                "" \
                "\033[33mUserspace\033[0m: 兼容模式，不依赖 tun" \
                "  通过 SOCKS5 代理工作，子网路由受限"
            separator_line "-"
            if [ "$tun_available" = "1" ]; then
                content_line "当前内核: \033[32m支持 Tun\033[0m → 自动选择 Tun 模式"
            else
                content_line "当前内核: \033[31m不支持 Tun\033[0m → 自动选择 Userspace 模式"
            fi
            separator_line "="
            ;;
        5)
            read -r -p "网络测试地址 (检测网络就绪) [$test_host]: " input
            [ -n "$input" ] && setconfig test_host "$input" && test_host="$input"
            ;;
        6)
            read -r -p "Tailscale 版本号 [$ts_version]: " input
            if [ -n "$input" ]; then
                setconfig ts_version "$input" && ts_version="$input"
                setconfig pkg_url "" && pkg_url=""
            fi
            ;;
        7)
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
