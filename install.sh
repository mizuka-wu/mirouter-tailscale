#!/bin/sh
# ===========================================
#  Tailscale 一键安装脚本 (小米路由器)
#  参考 ShellCrash 安装模式
#
#  用法:
#    sh install.sh
#
#  远程安装:
#    sh -c "$(curl -fsSL https://raw.githubusercontent.com/YOUR_USER/mirouter-tailscale/main/install.sh)"
# ===========================================

echo ""
echo "***********************************************"
echo "**                                           **"
echo "**          Tailscale 小米路由器安装          **"
echo "**          参考 ShellCrash 模式             **"
echo "**                                           **"
echo "***********************************************"
echo ""

# ---- 内置工具 ----
cecho() {
    printf '%b\n' "$*"
}
dir_avail() {
    df -h >/dev/null 2>&1 && h="$2"
    df -P $h "${1:-.}" 2>/dev/null | awk 'NR==2 {print $4}'
}
ckcmd() {
    command -v "$1" >/dev/null 2>&1
}
webget() {
    if curl --version >/dev/null 2>&1; then
        progress='-s'
        result=$(curl -w %{http_code} --connect-timeout 5 "$progress" -Lko "$1" "$2")
        [ -n "$(echo $result | grep -e ^2)" ] && result="200"
    elif wget --version >/dev/null 2>&1; then
        wget -q --no-check-certificate --timeout=3 -O "$1" "$2"
        [ $? -eq 0 ] && result="200"
    fi
}

# ---- 环境检查 ----
check_user() {
    if [ "$(id -u)" -ne 0 ]; then
        cecho "\033[31m请以 root 用户运行此脚本！\033[0m"
        exit 1
    fi
}

check_systype() {
    [ -f "/data/etc/crontabs/root" ] && systype=mi_snapshot
    [ -d "/etc/storage/started_script.sh" ] && systype=Padavan
    [ -d "/jffs" ] && systype=asusrouter
    [ -z "$systype" ] && systype=generic
}

check_arch() {
    cputype=$(uname -ms | tr ' ' '_' | tr '[A-Z]' '[a-z]')
    [ -n "$(echo $cputype | grep -E "linux.*aarch64.*|linux.*armv8.*")" ] && arch="arm64"
    [ -n "$(echo $cputype | grep -E "linux.*armv7.*")" ] && arch="armv7"
    [ -n "$(echo $cputype | grep -E "linux.*86_64.*")" ] && arch="amd64"
    [ -z "$arch" ] && arch="arm64"
    cecho "检测到架构: \033[32m$arch\033[0m"
    cecho "检测到系统: \033[32m$systype\033[0m"
}

# ---- 选择安装目录 ----
setdir() {
    case "$systype" in
    mi_snapshot)
        cecho "\033[33m检测到小米设备，推荐安装到 /data 目录\033[0m"
        cecho "  /data 剩余空间: $(dir_avail /data -h)"
        dir=/data
        ;;
    *)
        cecho " 1 安装到 /data 目录 (小米设备推荐)"
        cecho " 2 安装到 /etc 目录"
        cecho " 3 安装到 /usr/share 目录"
        cecho " 0 退出安装"
        read -p "请选择 > " num
        case "$num" in
        1) dir=/data ;;
        2) dir=/etc ;;
        3) dir=/usr/share ;;
        *) echo "安装已取消"; exit 1 ;;
        esac
        ;;
    esac

    if [ ! -w "$dir" ]; then
        cecho "\033[31m没有 $dir 目录写入权限！\033[0m"
        exit 1
    fi

    cecho "目标目录: \033[32m$dir\033[0m  剩余空间: $(dir_avail "$dir" -h)"
    TSDIR="$dir/tailscale"
}

# ---- 下载并解压 ----
gettar() {
    cecho "正在从 GitHub 获取安装文件..."

    # 下载 (支持 GitHub release 或直接 tar.gz)
    local url="${INSTALL_URL:-https://github.com/YOUR_USER/mirouter-tailscale/archive/refs/heads/main.tar.gz}"
    webget /tmp/ts_install.tar.gz "$url"

    if [ "$result" != "200" ]; then
        cecho "\033[31m下载失败！\033[0m"
        cecho "请检查网络或使用其他安装源"
        exit 1
    fi

    mkdir -p "$TSDIR"
    tar -zxf /tmp/ts_install.tar.gz -C /tmp/ 2>/dev/null

    # 复制文件到目标目录 (GitHub archive 解压后的目录名)
    local src_dir="/tmp/mirouter-tailscale-main"
    if [ -d "$src_dir/scripts" ]; then
        cp -rf "$src_dir/scripts"/* "$TSDIR/" 2>/dev/null
        cp -f "$src_dir/install.sh" "$TSDIR/" 2>/dev/null
    else
        cecho "\033[31m解压失败，请检查安装包\033[0m"
        exit 1
    fi

    rm -rf /tmp/ts_install.tar.gz "$src_dir"
}

# ---- 执行安装 ----
install() {
    echo "-----------------------------------------------"
    gettar

    echo "-----------------------------------------------"
    cecho "正在执行初始化..."

    # 运行 init.sh
    export TSDIR
    . "$TSDIR/scripts/init.sh"

    echo "-----------------------------------------------"
    cecho "\033[32m安装成功！\033[0m"
    cecho ""
    cecho "  输入 \033[30;47m tsm \033[0m 命令即可管理 Tailscale"
    cecho ""
    cecho "  首次使用会自动引导配置 Auth Key 和子网路由"
    cecho "  Auth Key 获取: \033[36mhttps://login.tailscale.com/admin/settings/keys\033[0m"
    echo "-----------------------------------------------"
}

# ---- 检查旧安装 ----
check_dir() {
    if [ -d "$TSDIR" ] && [ -f "$TSDIR/scripts/menu.sh" ]; then
        cecho "检测到旧安装: \033[36m$TSDIR\033[0m"
        cecho " 1 覆盖安装 (保留配置)"
        cecho " 2 卸载旧版本并安装"
        cecho " 0 取消"
        read -p "请选择 > " num
        case "$num" in
        1)
            # 备份配置
            mkdir -p /tmp/ts_bak
            cp -f "$TSDIR/configs/ts.cfg" /tmp/ts_bak/ 2>/dev/null
            install
            # 还原配置
            [ -f /tmp/ts_bak/ts.cfg ] && cp -f /tmp/ts_bak/ts.cfg "$TSDIR/configs/"
            rm -rf /tmp/ts_bak
            ;;
        2)
            rm -rf "$TSDIR"
            install
            ;;
        *)
            cecho "\033[31m已取消安装\033[0m"
            exit 1
            ;;
        esac
    else
        install
    fi
}

# ---- 主流程 ----
check_user
check_systype
check_arch
setdir
check_dir
