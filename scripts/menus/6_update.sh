# 更新版本

update_version() {
    comp_box "\033[30;47m 更新 Tailscale \033[0m"
    content_line "当前二进制版本: \033[36m$("$BIN_TS" version 2>/dev/null | head -1 || echo "未安装")\033[0m"
    content_line "配置版本:       \033[36mv${ts_version}\033[0m"
    separator_line "-"

    # 查询最新版本
    content_line "正在查询最新版本..."
    latest=$(curl -sL "https://pkgs.tailscale.com/stable/?mode=json" 2>/dev/null | sed -n 's/.*tailscale_\([0-9.]*\)_arm64.tgz.*/\1/p' | head -1)
    if [ -n "$latest" ]; then
        content_line "最新版本: \033[32mv${latest}\033[0m"
    else
        content_line "最新版本: \033[33m查询失败\033[0m"
    fi

    separator_line "-"
    content_line "1) 更新到最新版本"
    content_line "2) 手动指定版本号"
    btm_box "0) 返回"
    read -r -p "请选择 > " num

    case "$num" in
    "" | 0) return ;;
    1)
        if [ -z "$latest" ]; then
            msg_alert "\033[31m无法获取最新版本，请手动指定\033[0m"
            return
        fi
        new_version="$latest"
        ;;
    2)
        read -r -p "请输入版本号: " new_version
        [ -z "$new_version" ] && return
        ;;
    *)
        errornum
        return
        ;;
    esac

    if [ "$new_version" = "$ts_version" ] && [ -x "$BIN_TSD" ]; then
        msg_alert "\033[33m版本相同且二进制已存在，无需更新\033[0m"
        return
    fi

    comp_box "\033[36m正在更新: → v${new_version}\033[0m"

    # 1. 停止服务
    if pidof tailscaled >/dev/null 2>&1; then
        content_line "停止当前服务..."
        killall tailscaled 2>/dev/null
        sleep 1
        killall -9 tailscaled 2>/dev/null
    fi
    rm -f "$LOCK_FILE"

    # 2. 清除旧二进制
    content_line "清除旧版本..."
    rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"

    # 3. 更新配置
    setconfig ts_version "$new_version"
    ts_version="$new_version"
    setconfig pkg_url "" && pkg_url=""

    # 4. 下载新版本 (使用多镜像)
    content_line "下载 Tailscale v${new_version} ..."

    dl_urls=""
    dl_urls="$dl_urls https://pkgs.tailscale.com/stable/tailscale_${new_version}_${arch}.tgz"
    dl_urls="$dl_urls https://ghfast.top/https://github.com/tailscale/tailscale/releases/download/v${new_version}/tailscale_${new_version}_${arch}.tgz"
    dl_urls="$dl_urls https://ghproxy.cn/https://github.com/tailscale/tailscale/releases/download/v${new_version}/tailscale_${new_version}_${arch}.tgz"

    ts_download "$TMP_DIR/tailscale.tgz" $dl_urls
    if [ "$result" != "200" ]; then
        comp_box "\033[31m下载失败！\033[0m" \
            "请检查网络或手动下载后放到 $TMP_DIR/"
        return 1
    fi

    # 5. 解压
    content_line "解压中..."
    cd "$TMP_DIR" || return 1
    tar zxf tailscale.tgz >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        rm -f tailscale.tgz
        comp_box "\033[31m解压失败\033[0m"
        return 1
    fi

    local_dir="tailscale_${new_version}_${arch}"
    mv "$local_dir/tailscale" "$TMP_DIR/" 2>/dev/null
    mv "$local_dir/tailscaled" "$TMP_DIR/" 2>/dev/null
    chmod +x "$BIN_TS" "$BIN_TSD"
    rm -rf tailscale.tgz "$local_dir"

    if [ ! -x "$BIN_TSD" ]; then
        comp_box "\033[31m更新失败：二进制文件不存在\033[0m"
        return 1
    fi

    actual_ver=$("$BIN_TS" version 2>/dev/null | head -1)
    comp_box "\033[32m更新成功！\033[0m" \
        "新版本: $actual_ver"

    # 6. 重新启动服务
    separator_line "-"
    content_line "正在重启服务..."
    separator_line "-"
    start_service
}
