# 自动检测 CPU 架构 (参考 ShellCrash)
check_cpucore() {
    cputype=$(uname -ms | tr ' ' '_' | tr '[A-Z]' '[a-z]')
    [ -n "$(echo $cputype | grep -E "linux.*armv.*")" ] && arch="armv5"
    [ -n "$(echo $cputype | grep -E "linux.*armv7.*")" ] && [ -n "$(cat /proc/cpuinfo | grep vfp)" ] && arch="armv7"
    [ -n "$(echo $cputype | grep -E "linux.*aarch64.*|linux.*armv8.*")" ] && arch="arm64"
    [ -n "$(echo $cputype | grep -E "linux.*86_64.*")" ] && arch="amd64"
    [ -n "$(echo $cputype | grep -E "linux.*86.*")" ] && arch="386"
    if [ -n "$(echo $cputype | grep -E "linux.*mips.*")" ]; then
        mipstype=$(echo -n I | hexdump -o 2>/dev/null | awk '{ print substr($2,6,1); exit}')
        [ "$mipstype" = "0" ] && arch="mips-softfloat" || arch="mipsle-softfloat"
    fi
    [ -z "$arch" ] && arch="arm64"
    setconfig arch "$arch"
}
