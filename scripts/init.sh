#!/bin/sh
# Tailscale 初始化脚本 (参考 ShellCrash init.sh)
# 在安装后首次运行时执行

[ -z "$TSDIR" ] && TSDIR="/data/tailscale"
CFG_PATH="$TSDIR/configs/ts.cfg"

# 初始化目录
mkdir -p "$TSDIR/configs"
mkdir -p "$TSDIR/state"
mkdir -p "$TSDIR/starts"
mkdir -p "$TSDIR/scripts/libs"
mkdir -p "$TSDIR/scripts/menus"
mkdir -p "$TSDIR/scripts/starts"

# 初始化配置文件
[ -f "$CFG_PATH" ] || echo '# Tailscale 配置文件，不明勿动！' >"$CFG_PATH"

# 加载工具
. "$TSDIR/scripts/libs/set_config.sh"
. "$TSDIR/scripts/libs/set_cron.sh"
. "$TSDIR/scripts/libs/check_cpucore.sh"

# 检测架构
check_cpucore

# 批量授权脚本
for file in "$TSDIR/scripts/start.sh" \
    "$TSDIR/scripts/menu.sh" \
    "$TSDIR/scripts/starts/snapshot_init.sh" \
    "$TSDIR/scripts/starts/monitor.sh"; do
    [ -f "$file" ] && chmod +x "$file"
done

# 设置环境变量和别名
profile="/etc/profile"
if [ -n "$profile" ]; then
    # 移除旧条目
    sed -i '/alias tsm=/d' "$profile" 2>/dev/null
    sed -i '/export TSDIR=/d' "$profile" 2>/dev/null
    # 写入新条目
    echo "export TSDIR=$TSDIR" >>"$profile"
    echo "alias tsm='$TSDIR/scripts/menu.sh'" >>"$profile"
    # 适配 zsh
    if [ -w "$HOME/.zshrc" ]; then
        sed -i '/alias tsm=/d' "$HOME/.zshrc" 2>/dev/null
        sed -i '/export TSDIR=/d' "$HOME/.zshrc" 2>/dev/null
        echo "export TSDIR=$TSDIR" >>"$HOME/.zshrc"
        echo "alias tsm='$TSDIR/scripts/menu.sh'" >>"$HOME/.zshrc"
    fi
fi

# 创建快捷命令
if [ -d /usr/bin ]; then
    cat > /usr/bin/tsm << 'CMDEOF'
#!/bin/sh
TSDIR=${TSDIR:-/data/tailscale}
export TSDIR
exec "$TSDIR/scripts/menu.sh" "$@"
CMDEOF
    chmod +x /usr/bin/tsm 2>/dev/null
fi

# 保守模式启动脚本 (非小米设备 / 备用方案)
cat > "$TSDIR/starts/start_legacy.sh" << 'LEGEOF'
#!/bin/sh
# 保守模式: 通过 cron 轮询启动
TSDIR="${TSDIR:-/data/tailscale}"
MONITOR="$TSDIR/starts/monitor.sh"

# 设置 cron 守护
sed -i '/ts_monitor/d' /etc/crontabs/root 2>/dev/null
echo "* * * * * $MONITOR >/dev/null 2>&1 #ts_monitor" >> /etc/crontabs/root

# 部分系统 cron 目录不同
if [ -d /data/etc/crontabs ]; then
    sed -i '/ts_monitor/d' /data/etc/crontabs/root 2>/dev/null
    echo "* * * * * $MONITOR >/dev/null 2>&1 #ts_monitor" >> /data/etc/crontabs/root
fi

/etc/init.d/cron restart 2>/dev/null || true
LEGEOF
chmod +x "$TSDIR/starts/start_legacy.sh"

# 删除旧安装残留
rm -rf /tmp/*ailscale*.tgz
rm -rf /tmp/ts_cron_tmp

# 小米设备: 写入 snapshot_init.sh 到 /data/
if [ -f /data/etc/crontabs/root ]; then
    cp "$TSDIR/scripts/starts/snapshot_init.sh" /data/tailscale_init.sh 2>/dev/null
    sed -i "s|^TSDIR=.*|TSDIR=$TSDIR|" /data/tailscale_init.sh 2>/dev/null
fi

printf '\033[32m初始化完成！请输入\033[30;47m tsm \033[0;33m命令开始使用！\033[0m\n'
