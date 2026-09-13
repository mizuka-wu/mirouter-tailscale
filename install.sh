#!/bin/sh
# ===========================================
#  Tailscale 一键安装脚本 (小米路由器)
#  参考 ShellCrash 安装模式
#
#  远程安装:
#    sh -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/mizuka-wu/mirouter-tailscale@main/install.sh?$(date +%s))"
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
webget() {
    result=""
    if curl --version >/dev/null 2>&1; then
        result=$(curl -w %{http_code} --connect-timeout 8 --max-time 120 -sLko "$1" "$2")
        [ -n "$(echo $result | grep -e ^2)" ] && result="200"
    elif wget --version >/dev/null 2>&1; then
        wget -q --no-check-certificate --timeout=8 -O "$1" "$2"
        [ $? -eq 0 ] && result="200"
    fi
}

# ---- 选择安装源 ----
select_mirror() {
    local repo="mizuka-wu/mirouter-tailscale"
    local branch="main"
    local tar_file="mirouter-tailscale.tar.gz"

    cecho "\033[33m请选择安装源：\033[0m"
    cecho " 1 \033[32mjsdelivr CDN\033[0m        (国内推荐)"
    cecho " 2 \033[36mtestingcf.jsdelivr\033[0m (国内备用)"
    cecho " 3 \033[36mghfast.top\033[0m          (GitHub 代理)"
    cecho " 4 \033[36mghproxy.cn\033[0m           (GitHub 代理)"
    cecho " 5 \033[33mGitHub 直连\033[0m          (需科学上网)"
    cecho " 6 \033[33m手动输入\033[0m"
    cecho " 0 退出安装"
    echo "-----------------------------------------------"
    read -p "请输入相应数字 > " num

    case "$num" in
    1)
        SELECTED_URL="https://cdn.jsdelivr.net/gh/${repo}@${branch}/${tar_file}?$(date +%s)"
        ;;
    2)
        SELECTED_URL="https://testingcf.jsdelivr.net/gh/${repo}@${branch}/${tar_file}?$(date +%s)"
        ;;
    3)
        SELECTED_URL="https://ghfast.top/https://raw.githubusercontent.com/${repo}/${branch}/${tar_file}"
        ;;
    4)
        SELECTED_URL="https://ghproxy.cn/https://raw.githubusercontent.com/${repo}/${branch}/${tar_file}"
        ;;
    5)
        SELECTED_URL="https://raw.githubusercontent.com/${repo}/${branch}/${tar_file}"
        ;;
    6)
        read -p "请输入安装包 URL (tar.gz): " SELECTED_URL
        ;;
    *)
        echo "安装已取消"
        exit 0
        ;;
    esac

    cecho "  选定源: \033[36m$(echo $SELECTED_URL | sed 's|https://||' | cut -d'/' -f1)\033[0m"
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
        cecho "\033[33m检测到小米设备，安装到 /data 目录\033[0m"
        cecho "  /data 剩余空间: $(dir_avail /data -h)"
        cecho "  安装占用约 100KB (脚本+配置，Tailscale 二进制约 50MB 在内存中运行)"
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

# ---- Tun 检测 ----
check_tun() {
    if [ -c /dev/net/tun ]; then
        TUN_AVAILABLE=1
    else
        modprobe tun 2>/dev/null
        [ -c /dev/net/tun ] && TUN_AVAILABLE=1 || TUN_AVAILABLE=0
    fi
}

# ---- 自动检测子网 ----
detect_subnet() {
    local lan_ip
    lan_ip=$(ubus call network.interface.lan status 2>/dev/null | grep -oE '"address":"[0-9.]+"' | grep -oE '[0-9.]+')
    [ -z "$lan_ip" ] && lan_ip=$(ip addr show br-lan 2>/dev/null | grep 'inet ' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    [ -z "$lan_ip" ] && lan_ip=$(ip route 2>/dev/null | grep 'src' | grep -v 'default' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [ -n "$lan_ip" ]; then
        DETECTED_SUBNET=$(echo "$lan_ip" | sed 's/\.[0-9]*$/.0\/24/')
    fi
}

# ---- 下载并解压 ----
gettar() {
    cecho "正在下载安装文件..."
    rm -f /tmp/ts_install.tar.gz

    webget /tmp/ts_install.tar.gz "$SELECTED_URL"

    if [ "$result" != "200" ]; then
        cecho "\033[31m下载失败！\033[0m"
        cecho "  URL: $SELECTED_URL"
        cecho ""
        cecho "请检查网络，或重新运行选择其他安装源"
        exit 1
    fi

    cecho "下载完成，正在解压..."
    mkdir -p "$TSDIR"
    tar -zxf /tmp/ts_install.tar.gz -C "$TSDIR/" 2>/dev/null

    if [ ! -f "$TSDIR/scripts/menu.sh" ]; then
        cecho "\033[31m解压失败，请检查安装包\033[0m"
        rm -rf /tmp/ts_install.tar.gz
        exit 1
    fi

    rm -rf /tmp/ts_install.tar.gz
}

# ---- 安装后提示 ----
post_install_info() {
    echo ""
    separator="=============================================="

    cecho "\033[36m$separator\033[0m"
    cecho "\033[36m  运行模式说明\033[0m"
    cecho "\033[36m$separator\033[0m"

    if [ "$TUN_AVAILABLE" = "1" ]; then
        cecho ""
        cecho "  \033[32m✓ Tun 模式\033[0m (当前设备已支持)"
        cecho ""
        cecho "  Tun 模式下 Tailscale 创建虚拟网卡，内核级路由。"
        cecho "  这是子网路由 (subnet routing) 的工作模式。"
        cecho ""
        cecho "  工作原理:"
        cecho "    iPhone (Tailscale) → 路由器 tun 网卡 → LAN → NAS"
        cecho ""
        cecho "  其他 Tailscale 设备可以直接访问你宣告的子网"
        cecho "  例如: NAS (192.168.3.x)、路由器管理页等"
        cecho "  设备无需任何代理配置，直接通过 IP 访问"
        cecho ""
        cecho "  \033[33m配置步骤:\033[0m"
        cecho "    1. 输入 tsm 打开菜单"
        cecho "    2. [1] 填入 Auth Key"
        cecho "    3. [2] 确认子网路由 (自动检测: ${DETECTED_SUBNET:-请手动填写})"
        cecho "    4. [1] 启动服务"
        cecho "    5. iPhone 上安装 Tailscale/Surge 登录同一账号"
        cecho "    6. 直接访问 NAS IP 即可"
    else
        cecho ""
        cecho "  \033[33m✗ Tun 不可用\033[0m → 自动使用 Userspace 模式"
        cecho ""
        cecho "  当前内核不支持 /dev/net/tun，无法创建虚拟网卡。"
        cecho "  Tailscale 通过 SOCKS5 代理端口 (默认1055) 提供服务。"
        cecho ""
        cecho "  \033[33m限制:\033[0m"
        cecho "    - 子网路由 (advertise-routes) 功能受限"
        cecho "    - 其他设备无法直接通过 IP 访问内网"
        cecho "    - 只有支持 SOCKS5 代理的应用才能走 Tailscale"
        cecho ""
        cecho "  \033[33m连接方式:\033[0m"
        cecho "    需要在客户端设备上配置 SOCKS5 代理:"
        cecho "    代理地址: 路由器IP:1055"
        cecho ""
        cecho "    例如 Surge (iPhone):"
        cecho "      代理类型: SOCKS5"
        cecho "      地址: 192.168.3.1"
        cecho "      端口: 1055"
        cecho ""
        cecho "  \033[36m如果需要完整的子网路由功能:\033[0m"
        cecho "    方案1: 在 NAS 上直接安装 Tailscale (推荐)"
        cecho "    方案2: 尝试加载 tun 内核模块 (需要 tun.ko)"
        cecho "    方案3: 使用 ShellCrash 的 tun 安装方案"
    fi

    cecho ""
    cecho "\033[36m$separator\033[0m"
    cecho "\033[32m  安装完成！输入 tsm 开始配置\033[0m"
    cecho "\033[36m$separator\033[0m"
    cecho ""
}

# ---- 执行安装 ----
install() {
    echo "-----------------------------------------------"
    gettar

    echo "-----------------------------------------------"
    cecho "正在执行初始化..."

    export TSDIR
    . "$TSDIR/scripts/init.sh"

    check_tun
    detect_subnet
    post_install_info
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
            mkdir -p /tmp/ts_bak
            cp -f "$TSDIR/configs/ts.cfg" /tmp/ts_bak/ 2>/dev/null
            install
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
select_mirror
check_dir
