# Terminal UI 布局工具 (参考 ShellCrash)

TABLE_WIDTH=56

FULL_EQ="============================================================"
FULL_DASH="- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - "

content_line() {
    raw_input="$1"
    if [ -z "$raw_input" ]; then
        printf " \033[%dG||\n" "$TABLE_WIDTH"
        return
    fi
    printf ' %b' "$raw_input"
    # 计算可见宽度并补齐到 TABLE_WIDTH
    local visible
    visible=$(printf '%b' "$raw_input" | sed 's/\x1b\[[0-9;]*m//g')
    local vlen=${#visible}
    local pad=$((TABLE_WIDTH - vlen - 2))
    [ $pad -lt 1 ] && pad=1
    printf '%*s' "$pad" ''
    printf '||\n'
}

sub_content_line() {
    if [ -z "$1" ]; then
        printf " \033[%dG||\n" "$TABLE_WIDTH"
        return
    fi
    content_line "   $1"
}

separator_line() {
    local separatorType="$1"
    local lenLimit=$((TABLE_WIDTH - 1))
    if [ "$separatorType" = "=" ]; then
        printf "%s||\n" "$(printf "%.${lenLimit}s" "$FULL_EQ")"
    else
        printf "%s||\n" "$(printf "%.${lenLimit}s" "$FULL_DASH")"
    fi
}

line_break() {
    printf "\n"
}
