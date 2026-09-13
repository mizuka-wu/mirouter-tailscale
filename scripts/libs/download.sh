# 多镜像下载工具
# 用法: ts_download <保存路径> <镜像列表(换行分隔)>
# 返回: result=200 成功

ts_download() {
    local save_path="$1"
    local mirrors="$2"
    result=""

    for url in $mirrors; do
        [ -z "$url" ] && continue

        # 显示正在尝试的源
        local host=$(echo "$url" | sed 's|https\?://||' | cut -d'/' -f1)
        echo "  尝试: $host ..."

        if curl --version >/dev/null 2>&1; then
            local http_code
            http_code=$(curl -w %{http_code} --connect-timeout 10 --max-time 300 -Lko "$save_path" "$url" 2>/tmp/ts_curl_err.log)
            if echo "$http_code" | grep -q '^2' && [ -s "$save_path" ]; then
                result="200"
                echo "  ✓ 下载成功: $host"
                return 0
            else
                local err=$(cat /tmp/ts_curl_err.log 2>/dev/null | tail -1)
                echo "  ✗ 失败 (HTTP $http_code): $err"
            fi
        elif wget --version >/dev/null 2>&1; then
            wget --no-check-certificate --timeout=10 -O "$save_path" "$url" 2>/tmp/ts_wget_err.log
            if [ $? -eq 0 ] && [ -s "$save_path" ]; then
                result="200"
                echo "  ✓ 下载成功: $host"
                return 0
            else
                local err=$(cat /tmp/ts_wget_err.log 2>/dev/null | tail -1)
                echo "  ✗ 失败: $err"
            fi
        fi

        rm -f "$save_path" 2>/dev/null
    done

    echo ""
    echo "  所有下载源均失败"
    rm -f /tmp/ts_curl_err.log /tmp/ts_wget_err.log
    return 1
}
