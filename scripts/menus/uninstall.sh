# 卸载

uninstall() {
    comp_box "\033[31m卸载 Tailscale\033[0m" \
        "所有配置和状态将被清除！"
    btm_box "1) 确认卸载" \
        "0) 取消"
    read -r -p "请选择 > " res
    if [ "$res" != '1' ]; then
        msg_alert "\033[33m已取消\033[0m"
        return
    fi

    # 停止服务
    killall tailscaled 2>/dev/null
    sleep 1
    killall -9 tailscaled 2>/dev/null

    # 移除 cron
    cronset "ts_monitor"

    # 移除 uci firewall
    uci delete firewall.tailscale 2>/dev/null
    uci commit firewall 2>/dev/null

    # 还原 rc.local
    if [ -f /etc/rc.local.ts_bak ]; then
        cp /etc/rc.local.ts_bak /etc/rc.local 2>/dev/null
    else
        cat > /etc/rc.local << 'RCEOF'
#!/bin/sh
exit 0
RCEOF
        chmod +x /etc/rc.local
    fi

    # 移除环境变量
    sed -i '/alias tsm=/d' /etc/profile 2>/dev/null
    sed -i '/export TSDIR=/d' /etc/profile 2>/dev/null
    [ -w ~/.zshrc ] && {
        sed -i '/alias tsm=/d' ~/.zshrc 2>/dev/null
        sed -i '/export TSDIR=/d' ~/.zshrc 2>/dev/null
    }

    # 删除安装目录
    if [ -n "$TSDIR" ] && [ "$TSDIR" != '/' ]; then
        rm -rf "$TSDIR"
    fi

    # 清理临时文件
    rm -rf "$TMP_DIR"
    rm -f "$LOCK_FILE"
    rm -f /usr/bin/tsm

    comp_box "\033[32m卸载完成！\033[0m" \
        "\033[33m如需重新安装，请重新执行 install.sh\033[0m"
    line_break
    sleep 1
    exit 0
}
