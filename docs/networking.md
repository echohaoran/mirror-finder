# 固定 IP 与 DHCP 恢复

菜单 11 和 12 只操作默认路由对应的网卡，避免猜测用户要配置的网络接口。支持的配置
后端按优先级为：macOS `networksetup`、NetworkManager、Netplan、systemd-networkd 和
RHEL 系传统 `ifcfg-*` 文件。

配置固定 IP 时需输入 IPv4 地址、连续子网掩码和默认网关。脚本将掩码转换为 CIDR，
生成或更新对应后端配置后重新应用网络。恢复 DHCP 时，NetworkManager/macOS 直接改回
自动寻址；Netplan 与 systemd-networkd 删除脚本生成的专属配置文件；ifcfg 切回
`BOOTPROTO=dhcp`。

所有被覆盖或删除的配置会备份至 `~/.mirror-finder/backups/`。这两项操作会中断网络，
在 SSH 会话中只能在有带外控制台、可容忍断连时执行。
