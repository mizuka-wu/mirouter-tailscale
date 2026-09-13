# 开机自启设置

# 小米设备：通过 uci firewall include 注册 (与 ShellCrash 一致)
allow_autostart_xiaomi() {
    local init_path="$TSDIR/starts/snapshot_init.sh"
    uci delete firewall.tailscale 2>/dev/null
    uci set firewall.tailscale=include
    uci set firewall.tailscale.type='script'
    uci set firewall.tailscale.path="$init_path"
    uci set firewall.tailscale.enabled='1'
    uci commit firewall
}

# 保守模式：通过 rc.local
allow_autostart_rclocal() {
    if ! grep -q 'tailscale' /etc/rc.local 2>/dev/null; then
        # 备份
        cp /etc/rc.local /etc/rc.local.ts_bak 2>/dev/null
        # 写入
        cat > /etc/rc.local << RCEOF
#!/bin/sh
[ -x $TSDIR/starts/snapshot_init.sh ] && $TSDIR/starts/snapshot_init.sh >/dev/null 2>&1 &
exit 0
RCEOF
        chmod +x /etc/rc.local
    fi
}

disable_autostart() {
    # 移除 uci firewall include
    uci delete firewall.tailscale 2>/dev/null
    uci commit firewall 2>/dev/null
    # 移除 rc.local
    if [ -f /etc/rc.local.ts_bak ]; then
        cp /etc/rc.local.ts_bak /etc/rc.local 2>/dev/null
    else
        cat > /etc/rc.local << 'RCEOF'
#!/bin/sh
exit 0
RCEOF
        chmod +x /etc/rc.local
    fi
    # 移除 cron 守护
    cronset "ts_monitor"
    # 移除保守模式启动脚本
    rm -f "$TSDIR/starts/start_legacy.sh"
}

setboot() {
    while true; do
        check_autostart && auto_set="\033[32mON\033[0m" || auto_set="\033[31mOFF\033[0m"
        # 保守模式标记
        [ -f "$TSDIR/.dis_startup" ] && start_old=ON || start_old=OFF

        comp_box "\033[30;47m 开机自启设置 \033[0m"
        content_line "1) 开机自启     $auto_set"
        content_line "2) 保守模式     \033[36m$start_old\033[0m   (通过cron轮询, 兼容性更好)"
        content_line "3) 查看启动日志"
        btm_box "0) 返回"
        read -r -p "请选择 > " num

        case "$num" in
        "" | 0) break ;;
        1)
            if check_autostart; then
                disable_autostart
                msg_alert "\033[33m已关闭开机自启\033[0m"
            else
                # 小米设备用 uci firewall, 其他用 rc.local
                if [ -f /data/etc/crontabs/root ]; then
                    allow_autostart_xiaomi
                else
                    allow_autostart_rclocal
                fi
                # 同时设置 cron 守护作为兜底
                setup_monitor_cron
                rm -f "$TSDIR/.dis_startup"
                msg_alert "\033[32m已开启开机自启\033[0m"
            fi
            ;;
        2)
            if [ "$start_old" = "OFF" ]; then
                # 开启保守模式：仅依赖 cron，不依赖 uci/rc.local
                disable_autostart
                setup_monitor_cron
                touch "$TSDIR/.dis_startup"
                msg_alert "\033[33m已开启保守模式 (仅 cron 守护)\033[0m"
            else
                rm -f "$TSDIR/.dis_startup"
                msg_alert "\033[32m已关闭保守模式\033[0m"
            fi
            ;;
        3)
            if [ -s "$TMP_DIR/ts.log" ]; then
                line_break
                separator_line "="
                tail -20 "$TMP_DIR/ts.log" | while IFS= read -r line; do
                    content_line "$line"
                done
                separator_line "="
            else
                msg_alert "\033[33m暂无日志\033[0m"
            fi
            ;;
        *)
            errornum
            ;;
        esac
    done
}
