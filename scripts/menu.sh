#!/bin/sh
# Tailscale 管理菜单 (参考 ShellCrash menu.sh)

TSDIR=$(
    cd "$(dirname "$0")/.."
    pwd
)

CFG_PATH="$TSDIR/configs/ts.cfg"

# 加载配置，失败则初始化
. "$TSDIR/scripts/libs/get_config.sh"
[ ! -f "$CFG_PATH" ] && . "$TSDIR/scripts/init.sh" >/dev/null 2>&1
[ ! -d "$TMP_DIR" ] && mkdir -p "$TMP_DIR"

# 通用工具
. "$TSDIR/scripts/libs/set_config.sh"
. "$TSDIR/scripts/libs/set_cron.sh"
. "$TSDIR/scripts/libs/check_cpucore.sh"
. "$TSDIR/scripts/libs/check_autostart.sh"
. "$TSDIR/scripts/libs/logger.sh"

# TUI 界面
. "$TSDIR/scripts/menus/tui_layout.sh"
. "$TSDIR/scripts/menus/common.sh"
. "$TSDIR/scripts/menus/1_start.sh"
. "$TSDIR/scripts/menus/2_settings.sh"
. "$TSDIR/scripts/menus/3_stop.sh"
. "$TSDIR/scripts/menus/4_setboot.sh"
. "$TSDIR/scripts/menus/5_status.sh"
. "$TSDIR/scripts/menus/6_update.sh"
. "$TSDIR/scripts/menus/uninstall.sh"

# 主菜单状态检查
ckstatus() {
    PID=$(pidof tailscaled 2>/dev/null | awk '{print $NF}')
    if [ -n "$PID" ]; then
        run="\033[32m运行中\033[0m (PID: $PID)"
    else
        run="\033[31m未运行\033[0m"
    fi
    check_autostart && auto="\033[32mON\033[0m" || auto="\033[31mOFF\033[0m"

    # 首次运行检查: 无配置则引导
    if [ -z "$auth_key" ] && [ ! -f "$TSDIR/.initialized" ]; then
        comp_box "\033[33m首次使用，请先进行配置\033[0m"
        settings
        touch "$TSDIR/.initialized"
    fi
}

# 主菜单
main_menu() {
    while true; do
        ckstatus

        top_box "\033[30;47m Tailscale 管理脚本 \033[0m"
        content_line "运行状态: $run  |  自启: $auto"
        separator_line "-"
        btm_box "1) \033[32m启动服务\033[0m" \
            "2) \033[36m设置\033[0m" \
            "3) \033[31m停止服务\033[0m" \
            "4) \033[33m开机自启\033[0m" \
            "5) \033[32m运行状态\033[0m" \
            "6) \033[36m更新版本\033[0m" \
            "7) \033[31m卸载\033[0m" \
            "" \
            "0) 退出"
        read -r -p "请选择 > " num

        case "$num" in
        "" | 0)
            line_break
            exit 0
            ;;
        1)
            start_service
            ;;
        2)
            settings
            ;;
        3)
            stop_service
            ;;
        4)
            setboot
            ;;
        5)
            show_status
            ;;
        6)
            update_version
            ;;
        7)
            uninstall
            ;;
        *)
            errornum
            ;;
        esac
    done
}

# 入口
case "$1" in
"")
    main_menu
    ;;
-s)
    "$TSDIR/scripts/start.sh" "$2" "$3"
    ;;
-u)
    uninstall
    ;;
*)
    echo "用法: menu.sh [-s start|stop|restart|status] [-u]"
    ;;
esac
