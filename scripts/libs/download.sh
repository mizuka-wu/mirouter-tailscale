# 多镜像下载工具
# 用法: ts_download <保存路径> <URL1> <URL2> ...
# 返回: result=200 成功

ts_download() {
    save_path="$1"
    shift
    result=""

    for url in "$@"; do
        [ -z "$url" ] && continue

        host=$(echo "$url" | sed 's|https\?://||' | cut -d'/' -f1)
        echo "  尝试: $host ..."

        curl -w "%{http_code}" --connect-timeout 10 --max-time 300 -sLko "$save_path" "$url" 2>/dev/null > /tmp/ts_dl_code.txt
        http_code=$(cat /tmp/ts_dl_code.txt 2>/dev/null)

        if echo "$http_code" | grep -q '^2' && [ -s "$save_path" ]; then
            result="200"
            echo "  ✓ 下载成功: $host"
            rm -f /tmp/ts_dl_code.txt
            return 0
        else
            echo "  ✗ 失败 (HTTP $http_code)"
        fi

        rm -f "$save_path" 2>/dev/null
    done

    echo ""
    echo "  所有下载源均失败"
    rm -f /tmp/ts_dl_code.txt
    return 1
}
