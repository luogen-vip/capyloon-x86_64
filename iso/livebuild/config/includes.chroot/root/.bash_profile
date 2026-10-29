# /root/.bash_profile - Capyloon x86_64 console helper
# Auto-launches the disk installer when booted with 'capyloon.installer'
# kernel parameter (selected from the GRUB menu), otherwise shows a banner.

if grep -qE "capyloon\.installer|capyloon-installer" /proc/cmdline 2>/dev/null; then
    echo "检测到 GRUB 安装模式，启动磁盘安装器..."
    echo ""
    exec /usr/sbin/capyloon-installer --auto
fi

if [ -f /etc/motd ]; then
    cat /etc/motd
fi
