# 设置菜单

settings() {
    while true; do
        local key_display="未配置"
        [ -n "$auth_key" ] && key_display="${auth_key:0:12}..."

        # 模式显示
        if [ "$ts_mode" = "tun" ]; then
            mode_display="\033[32mTun 模式\033[0m (内核级路由)"
        else
            mode_display="\033[33mUserspace 模式\033[0m (兼容模式，不支持子网路由)"
        fi

        comp_box "\033[30;47m Tailscale 设置 \033[0m"
        content_line "1) Auth Key       \033[36m$key_display\033[0m"
        content_line "2) 子网路由       \033[36m${routes:-未配置}\033[0m"
        content_line "3) 运行模式       $mode_display"
        content_line "4) 测试地址       \033[36m$test_host\033[0m"
        content_line "5) Accept DNS     \033[36m$accept_dns\033[0m"
        content_line "6) SNAT 子网      \033[36m$snat_subnet\033[0m"
        content_line "7) Tailscale 版本 \033[36m$ts_version\033[0m"
        content_line "8) 自定义下载源   \033[36m${pkg_url:-默认}\033[0m"

        # 出口节点: 仅 tun 模式可用
        if [ "$ts_mode" = "tun" ]; then
            content_line "9) 出口节点       \033[36m$use_exit_node\033[0m"
        fi

        btm_box "0) 返回"
        read -r -p "请选择 > " num
        echo ""

        case "$num" in
        "" | 0) break ;;
        1)
            read -r -p "Auth Key: " input
            [ -n "$input" ] && setconfig auth_key "$input" && auth_key="$input"
            ;;
        2)
            read -r -p "子网路由 (逗号分隔，如 192.168.3.0/24): " input
            [ -n "$input" ] && setconfig routes "$input" && routes="$input"
            ;;
        3)
            if [ "$tun_available" = "1" ]; then
                if [ "$ts_mode" = "tun" ]; then
                    setconfig ts_mode userspace && ts_mode="userspace"
                else
                    setconfig ts_mode tun && ts_mode="tun"
                fi
                msg_alert "已切换为: $ts_mode"
            else
                msg_alert "\033[33m当前内核不支持 tun，仅可使用 userspace 模式\033[0m"
            fi
            ;;
        4)
            read -r -p "网络测试地址 [$test_host]: " input
            [ -n "$input" ] && setconfig test_host "$input" && test_host="$input"
            ;;
        5)
            if [ "$accept_dns" = "true" ]; then
                setconfig accept_dns false && accept_dns="false"
            else
                setconfig accept_dns true && accept_dns="true"
            fi
            msg_alert "Accept DNS: $accept_dns"
            ;;
        6)
            if [ "$snat_subnet" = "true" ]; then
                setconfig snat_subnet false && snat_subnet="false"
            else
                setconfig snat_subnet true && snat_subnet="true"
            fi
            msg_alert "SNAT Subnet: $snat_subnet"
            ;;
        7)
            read -r -p "Tailscale 版本号 [$ts_version]: " input
            if [ -n "$input" ]; then
                setconfig ts_version "$input" && ts_version="$input"
                setconfig pkg_url "" && pkg_url=""
            fi
            ;;
        8)
            read -r -p "自定义下载源URL (留空恢复默认): " input
            if [ -n "$input" ]; then
                setconfig pkg_url "$input" && pkg_url="$input"
            else
                setconfig pkg_url "" && pkg_url=""
            fi
            ;;
        9)
            if [ "$ts_mode" = "tun" ]; then
                if [ "$use_exit_node" = "ON" ]; then
                    setconfig use_exit_node OFF && use_exit_node="OFF"
                else
                    setconfig use_exit_node ON && use_exit_node="ON"
                fi
                msg_alert "出口节点: $use_exit_node"
            else
                errornum
            fi
            ;;
        *)
            errornum
            ;;
        esac
    done
}
