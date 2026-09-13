# 启动服务

start_service() {
    if pidof tailscaled >/dev/null 2>&1; then
        msg_alert "\033[33mTailscale 已在运行 (PID: $(pidof tailscaled | awk '{print $NF}'))\033[0m"
        return 0
    fi

    if [ -z "$auth_key" ]; then
        comp_box "\033[31m未配置 Auth Key！\033[0m" \
            "请先在 [2] 设置 中配置 Auth Key"
        return 1
    fi

    comp_box "\033[36m正在启动 Tailscale ...\033[0m"

    mkdir -p "$TMP_DIR" "$STATE_DIR"

    if [ ! -x "$BIN_TSD" ]; then
        content_line "\033[33m内存中无二进制文件，正在下载...\033[0m"
        separator_line "-"
        if ! download_binary; then
            comp_box "\033[31m下载失败！\033[0m" \
                "请检查下载源或网络连接" \
                "可在 [2] 设置 中配置局域网下载源"
            return 1
        fi
    fi

    # 根据模式启动 tailscaled
    if [ "$ts_mode" = "tun" ] && [ -c /dev/net/tun ]; then
        content_line "启动模式: \033[32mTun\033[0m"
        "$BIN_TSD" -state "$STATE_FILE" >/dev/null 2>&1 &
    else
        content_line "启动模式: \033[33mUserspace\033[0m"
        "$BIN_TSD" \
            -state "$STATE_FILE" \
            --tun=userspace-networking \
            --socks5-server=localhost:1055 \
            --outbound-http-proxy-listen=localhost:1055 \
            >/dev/null 2>&1 &
    fi

    content_line "等待 tailscaled 就绪..."
    i=0
    while [ $i -lt 20 ]; do
        "$BIN_TS" status >/dev/null 2>&1 && break
        sleep 1
        i=$((i+1))
    done

    if ! pidof tailscaled >/dev/null 2>&1; then
        comp_box "\033[31m启动失败！\033[0m" \
            "请检查日志: $TMP_DIR/ts.log"
        return 1
    fi

    ts_up

    PID=$(pidof tailscaled | awk '{print $NF}')
    comp_box "\033[32mTailscale 已启动\033[0m" \
        "PID: $PID  模式: $ts_mode"

    # 子网路由审批提示
    if [ -n "$routes" ]; then
        separator_line "-"
        content_line "\033[33m重要：请到 Tailscale 后台审批子网路由\033[0m"
        content_line ""
        content_line "  打开: \033[36mhttps://console.tailscale.com/admin/machines\033[0m"
        content_line "  找到本设备 → 三点菜单 → Edit route settings"
        content_line "  勾选允许 $routes"
        content_line ""
        content_line "  不审批的话，其他设备无法访问子网"
    fi
    separator_line "="

    setup_monitor_cron
    return 0
}

download_binary() {
    mkdir -p "$TMP_DIR"
    echo "  正在从镜像源下载 Tailscale v${ts_version} ..."

    dl_urls=""
    [ -n "$pkg_url" ] && dl_urls="$pkg_url"
    dl_urls="$dl_urls https://pkgs.tailscale.com/stable/tailscale_${ts_version}_${arch}.tgz"
    dl_urls="$dl_urls https://ghfast.top/https://github.com/tailscale/tailscale/releases/download/v${ts_version}/tailscale_${ts_version}_${arch}.tgz"
    dl_urls="$dl_urls https://ghproxy.cn/https://github.com/tailscale/tailscale/releases/download/v${ts_version}/tailscale_${ts_version}_${arch}.tgz"

    ts_download "$TMP_DIR/tailscale.tgz" $dl_urls
    if [ "$result" != "200" ]; then
        return 1
    fi

    content_line "下载完成，正在解压..."
    cd "$TMP_DIR" || return 1
    tar zxf tailscale.tgz >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        rm -f tailscale.tgz
        return 1
    fi
    local_dir="tailscale_${ts_version}_${arch}"
    mv "$local_dir/tailscale" "$TMP_DIR/" 2>/dev/null
    mv "$local_dir/tailscaled" "$TMP_DIR/" 2>/dev/null
    chmod +x "$BIN_TS" "$BIN_TSD"
    rm -rf tailscale.tgz "$local_dir"
    [ -x "$BIN_TSD" ] && return 0 || return 1
}

ts_up() {
    UP_ARGS="--timeout=20s"
    [ -n "$auth_key" ] && UP_ARGS="$UP_ARGS --authkey=$auth_key"
    [ -n "$hostname" ] && UP_ARGS="$UP_ARGS --hostname=$hostname"
    UP_ARGS="$UP_ARGS --accept-dns=$accept_dns"
    UP_ARGS="$UP_ARGS --snat-subnet-routes=$snat_subnet"
    [ -n "$routes" ] && UP_ARGS="$UP_ARGS --advertise-routes=$routes"
    # shellcheck disable=SC2086
    "$BIN_TS" up $UP_ARGS >/dev/null 2>&1
}

setup_monitor_cron() {
    monitor="$TSDIR/scripts/starts/monitor.sh"
    if [ -x "$monitor" ]; then
        cronset "ts_monitor" "* * * * * $monitor >/dev/null 2>&1 #ts_monitor"
        content_line "\033[32m已配置 cron 守护 (每分钟巡检)\033[0m"
    fi
}
