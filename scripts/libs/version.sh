# 脚本版本号
SCRIPT_VERSION="1.0.0"

# 检查是否有新版本
check_script_update() {
    latest_tag=$(curl -sL "https://api.github.com/repos/mizuka-wu/mirouter-tailscale/releases/latest" 2>/dev/null | sed -n 's/.*"tag_name": *"v\?\([^"]*\)".*/\1/p' | head -1)
    if [ -n "$latest_tag" ] && [ "$latest_tag" != "$SCRIPT_VERSION" ]; then
        echo "\033[33m脚本有新版本: v${latest_tag} (当前: v${SCRIPT_VERSION})\033[0m"
        echo "更新: curl -fsSL https://raw.githubusercontent.com/mizuka-wu/mirouter-tailscale/main/install.sh -o /tmp/ts_install.sh && sh /tmp/ts_install.sh"
        return 0
    fi
    return 1
}
