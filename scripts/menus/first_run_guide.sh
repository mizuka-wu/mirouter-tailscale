# 首次运行引导

first_run_guide() {
    [ -f "$TSDIR/.initialized" ] && return

    comp_box "\033[36m首次使用引导\033[0m"

    if [ "$ts_mode" = "tun" ]; then
        content_line "运行模式: \033[32mTun\033[0m"
        content_line ""
        content_line "Tun 模式下 Tailscale 创建虚拟网卡，内核级路由。"
        content_line "其他 Tailscale 设备可直接通过 IP 访问你的内网。"
        content_line ""
        content_line "例如: iPhone (Tailscale/Surge) → 直接访问 NAS IP"
        content_line "无需代理配置，直接通过 IP 访问"
    else
        content_line "运行模式: \033[33mUserspace\033[0m"
        content_line ""
        content_line "当前内核不支持 Tun，使用 SOCKS5 代理模式。"
        content_line "其他设备需配置代理才能走 Tailscale。"
        content_line ""
        content_line "连接方式: SOCKS5 代理 路由器IP:${socks_port:-1055}"
        content_line "例如 Surge: 代理类型 SOCKS5, 地址路由器IP, 端口1055"
    fi

    separator_line "-"
    content_line "请先完成以下配置:"
    content_line "  [1] 填入 Auth Key (必需)"
    content_line "  [2] 确认子网路由"
    separator_line "="

    touch "$TSDIR/.initialized"
}
