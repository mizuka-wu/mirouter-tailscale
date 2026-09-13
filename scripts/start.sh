#!/bin/sh
# Tailscale 服务控制入口 (参考 ShellCrash start.sh)

# 初始化目录
[ -z "$TSDIR" ] && TSDIR=$(
    cd "$(dirname "$0")/.."
    pwd
)

# 加载工具
. "$TSDIR/scripts/libs/get_config.sh"
. "$TSDIR/scripts/libs/set_config.sh"
. "$TSDIR/scripts/libs/set_cron.sh"
. "$TSDIR/scripts/libs/check_cpucore.sh"
. "$TSDIR/scripts/libs/logger.sh"

# 加载启动菜单 (用于 start_service 等函数)
. "$TSDIR/scripts/menus/tui_layout.sh"
. "$TSDIR/scripts/menus/common.sh"
. "$TSDIR/scripts/menus/1_start.sh"
. "$TSDIR/scripts/menus/3_stop.sh"

case "$1" in

start)
    [ -n "$(pidof tailscaled)" ] && $0 stop
    start_service
    ;;
stop)
    stop_service
    ;;
restart)
    $0 stop
    sleep 1
    $0 start
    ;;
status)
    # 简洁版本: 用于命令行
    PID=$(pidof tailscaled 2>/dev/null | awk '{print $NF}')
    if [ -n "$PID" ]; then
        echo "Tailscale 运行中 (PID: $PID)"
        [ -x "$BIN_TS" ] && "$BIN_TS" status 2>/dev/null
    else
        echo "Tailscale 未运行"
    fi
    ;;
up)
    # 仅执行 tailscale up (不启动进程)
    [ -x "$BIN_TS" ] && ts_up
    ;;
cronset)
    # 供外部调用设置 cron
    cronset "$2" "$3"
    ;;
*)
    echo "用法: $0 {start|stop|restart|status|up}"
    exit 1
    ;;
esac
