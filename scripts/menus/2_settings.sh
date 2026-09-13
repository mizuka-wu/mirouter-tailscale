# 设置菜单

settings() {
    while true; do
        # 脱敏显示 auth_key
        local key_display="未配置"
        [ -n "$auth_key" ] && key_display="${auth_key:0:12}..."

        comp_box "\033[30;47m Tailscale 设置 \033[0m"
        content_line "1) 网关 IP       \033[36m$gateway_ip\033[0m"
        content_line "2) Auth Key      \033[36m$key_display\033[0m"
        content_line "3) 子网路由      \033[36m${routes:-未配置}\033[0m"
        content_line "4) SOCKS5 端口   \033[36m$socks_port\033[0m"
        content_line "5) 出口节点      \033[36m$use_exit_node\033[0m"
        content_line "6) Accept DNS    \033[36m$accept_dns\033[0m"
        content_line "7) SNAT 子网     \033[36m$snat_subnet\033[0m"
        content_line "8) Tailscale 版本 \033[36m$ts_version\033[0m"
        content_line "9) 自定义下载源  \033[36m${pkg_url:-默认}\033[0m"
        btm_box "0) 返回"
        read -r -p "请选择 > " num
        echo ""

        case "$num" in
        "" | 0) break ;;
        1)
            read -r -p "网关IP [$gateway_ip]: " input
            [ -n "$input" ] && setconfig gateway_ip "$input" && gateway_ip="$input"
            ;;
        2)
            read -r -p "Auth Key: " input
            [ -n "$input" ] && setconfig auth_key "$input" && auth_key="$input"
            ;;
        3)
            read -r -p "子网路由 (逗号分隔，如 192.168.1.0/24,192.168.31.0/24): " input
            [ -n "$input" ] && setconfig routes "$input" && routes="$input"
            ;;
        4)
            read -r -p "SOCKS5 端口 [$socks_port]: " input
            [ -n "$input" ] && setconfig socks_port "$input" && socks_port="$input"
            ;;
        5)
            if [ "$use_exit_node" = "ON" ]; then
                setconfig use_exit_node OFF && use_exit_node="OFF"
            else
                setconfig use_exit_node ON && use_exit_node="ON"
            fi
            msg_alert "出口节点: $use_exit_node"
            ;;
        6)
            if [ "$accept_dns" = "true" ]; then
                setconfig accept_dns false && accept_dns="false"
            else
                setconfig accept_dns true && accept_dns="true"
            fi
            msg_alert "Accept DNS: $accept_dns"
            ;;
        7)
            if [ "$snat_subnet" = "true" ]; then
                setconfig snat_subnet false && snat_subnet="false"
            else
                setconfig snat_subnet true && snat_subnet="true"
            fi
            msg_alert "SNAT Subnet: $snat_subnet"
            ;;
        8)
            read -r -p "Tailscale 版本号 [$ts_version]: " input
            if [ -n "$input" ]; then
                setconfig ts_version "$input" && ts_version="$input"
                # 清除自定义URL，使用默认模板
                setconfig pkg_url ""
                pkg_url=""
                # 重新加载
                PKG_URL="https://pkgs.tailscale.com/stable/tailscale_${ts_version}_${arch}.tgz"
            fi
            ;;
        9)
            read -r -p "自定义下载源URL (留空恢复默认): " input
            if [ -n "$input" ]; then
                setconfig pkg_url "$input" && pkg_url="$input"
                PKG_URL="$input"
            else
                setconfig pkg_url "" && pkg_url=""
                PKG_URL="https://pkgs.tailscale.com/stable/tailscale_${ts_version}_${arch}.tgz"
            fi
            ;;
        *)
            errornum
            ;;
        esac
    done
}
