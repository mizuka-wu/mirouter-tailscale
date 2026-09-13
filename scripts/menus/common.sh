# 通用菜单组件 (参考 ShellCrash)

msg_alert() {
    _sleep_time=1
    if [ "$1" = "-t" ] && [ -n "$2" ]; then
        _sleep_time="$2"; shift 2
    fi
    line_break
    separator_line "="
    for line in "$@"; do
        content_line "$line"
    done
    separator_line "="
    sleep "$_sleep_time"
}

comp_box() {
    line_break
    separator_line "="
    for line in "$@"; do
        content_line "$line"
    done
    separator_line "="
}

top_box() {
    line_break
    separator_line "="
    for line in "$@"; do
        content_line "$line"
    done
}

btm_box() {
    for line in "$@"; do
        content_line "$line"
    done
    separator_line "="
}

common_success() {
    msg_alert "\033[32m操作成功\033[0m"
}

common_failed() {
    msg_alert "\033[31m操作失败\033[0m"
}

errornum() {
    msg_alert "\033[31m输入错误，请重新选择！\033[0m"
}
