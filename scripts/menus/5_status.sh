# 状态查看

show_status() {
    comp_box "\033[30;47m Tailscale 运行状态 \033[0m"

    local PID
    PID=$(pidof tailscaled 2>/dev/null | awk '{print $NF}')
    if [ -n "$PID" ]; then
        content_line "进程:    \033[32m运行中\033[0m (PID: $PID)"
    else
        content_line "进程:    \033[31m未运行\033[0m"
    fi

    [ -x "$BIN_TSD" ] && bin_text="\033[32m已就绪\033[0m" || bin_text="\033[33m未下载\033[0m"
    content_line "二进制:  $bin_text"

    check_autostart && auto_text="\033[32mON\033[0m" || auto_text="\033[31mOFF\033[0m"
    content_line "自启:    $auto_text"

    [ "$tun_available" = "1" ] && tun_text="\033[32m支持\033[0m" || tun_text="\033[31m不支持\033[0m"
    content_line "Tun:     $tun_text"
    content_line "模式:    $ts_mode"

    separator_line "-"
    content_line "Auth Key:  ${auth_key:+已配置}${auth_key:-\033[31m未配置\033[0m}"
    content_line "子网路由:  ${routes:-未配置}"
    content_line "测试地址:  $test_host"
    content_line "版本:     $ts_version ($arch)"
    content_line "节点名:   ${hostname:-$(uname -n)}"

    if [ -n "$PID" ] && [ -x "$BIN_TS" ]; then
        separator_line "-"
        content_line "\033[36mTailscale 网络:\033[0m"
        separator_line "-"
        line_break
        "$BIN_TS" status 2>/dev/null
    fi

    separator_line "="
}
