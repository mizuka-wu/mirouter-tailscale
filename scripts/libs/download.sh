# 多镜像下载工具
# 用法: ts_download <保存路径> <镜像列表(换行分隔)>
# 返回: result=200 成功, result=失败

ts_download() {
    local save_path="$1"
    local mirrors="$2"
    result=""

    for url in $mirrors; do
        [ -z "$url" ] && continue

        if curl --version >/dev/null 2>&1; then
            result=$(curl -w %{http_code} --connect-timeout 8 --max-time 180 -sLko "$save_path" "$url" 2>/dev/null)
            [ -n "$(echo $result | grep -e ^2)" ] && result="200"
        elif wget --version >/dev/null 2>&1; then
            wget -q --no-check-certificate --timeout=8 -O "$save_path" "$url" 2>/dev/null
            [ $? -eq 0 ] && result="200"
        fi

        if [ "$result" = "200" ]; then
            # 验证文件非空
            if [ -s "$save_path" ]; then
                return 0
            else
                rm -f "$save_path"
                result=""
            fi
        fi
    done

    return 1
}
