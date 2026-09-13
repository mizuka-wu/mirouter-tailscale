# Cron 定时任务管理 (参考 ShellCrash)

crondir="$(crond -h 2>&1 | grep -oE 'Default:.*' | awk -F ":" '{print $2}' | tr -d ' ')"
[ ! -w "$crondir" ] && crondir="/data/etc/crontabs"
[ ! -w "$crondir" ] && crondir="/etc/crontabs"
[ ! -w "$crondir" ] && crondir="/var/spool/cron/crontabs"
[ ! -w "$crondir" ] && crondir="/var/spool/cron"
[ -z "$USER" ] && USER=$(whoami 2>/dev/null)
tmpcron=/tmp/ts_cron_tmp
touch "$tmpcron"

cronadd() {
    if crontab -h 2>&1 | grep -q '\-l'; then
        crontab "$1"
    elif [ -w "$crondir" ]; then
        cat "$1" >"$crondir"/"$USER" && cru a REFRESH "0 0 1 1 * /bin/true" 2>/dev/null
    else
        echo "找不到可用的crond或者crontab应用！"
    fi
}

cronload() {
    if crontab -h 2>&1 | grep -q '\-l'; then
        crontab -l
    elif [ -f "$crondir/$USER" ]; then
        cat "$crondir"/"$USER" 2>/dev/null
    else
        return 1
    fi
}

# 参数1=要移除的关键字, 参数2=要添加的任务语句
cronset() {
    cronload | grep -v '^$' | grep -vF "$1" >"$tmpcron"
    [ -n "$2" ] && echo "$2" >>"$tmpcron"
    cronadd "$tmpcron"
    rm -f "$tmpcron"
}
