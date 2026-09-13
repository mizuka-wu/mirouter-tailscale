# 日志工具
ts_logger() {
    local level="INFO"
    local color="\033[0m"
    case "$1" in
        error) level="ERROR"; color="\033[1;31m"; shift ;;
        warn)  level="WARN "; color="\033[1;33m"; shift ;;
        info)  level="INFO "; color="\033[1;32m"; shift ;;
    esac
    printf "${color}[%s]\033[0m %s\n" "$level" "$1"
    # 写入日志文件
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $1" >> "$TMP_DIR/ts.log" 2>/dev/null
}
