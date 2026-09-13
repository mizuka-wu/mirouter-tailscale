# Terminal UI 布局工具 (参考 ShellCrash)
# 兼容 busybox ash

TABLE_WIDTH=56

# 生成分隔线字符串
_gen_line() {
    local ch="$1"
    local line=""
    local i=0
    while [ $i -lt $((TABLE_WIDTH - 1)) ]; do
        line="${line}${ch}"
        i=$((i+1))
    done
    echo "$line"
}

# ANSI 转义 (兼容 busybox)
ESC=$(printf '\033')

content_line() {
    local raw_input="$1"
    if [ -z "$raw_input" ]; then
        printf " %${TABLE_WIDTH}s||\n" ""
        return
    fi
    # 输出内容
    printf ' %b' "$raw_input"
    # 计算可见宽度 (去掉 ANSI 转义序列)
    local visible
    visible=$(printf '%b' "$raw_input" | sed "s/${ESC}\[[0-9;]*m//g")
    local vlen=${#visible}
    local pad=$((TABLE_WIDTH - vlen - 2))
    [ $pad -lt 1 ] && pad=1
    printf '%*s' "$pad" ''
    printf '||\n'
}

sub_content_line() {
    if [ -z "$1" ]; then
        printf " %${TABLE_WIDTH}s||\n" ""
        return
    fi
    content_line "   $1"
}

separator_line() {
    local stype="$1"
    local line
    if [ "$stype" = "=" ]; then
        line=$(_gen_line "=")
    else
        line=$(_gen_line "-")
    fi
    printf '%s||\n' "$line"
}

line_break() {
    printf "\n"
}
