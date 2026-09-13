# 参数1=变量名，参数2=变量值，参数3=文件路径(可选)
setconfig() {
    [ -z "$3" ] && configpath="$TSDIR/configs/ts.cfg" || configpath="$3"
    sed -i "/^${1}=.*/d" "$configpath"
    printf '%s=%s\n' "$1" "$2" >>"$configpath"
}
