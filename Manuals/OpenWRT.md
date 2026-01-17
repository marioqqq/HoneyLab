## Disable IPv6
```bash
uci set 'network.lan.ipv6=0'
uci set 'network.wan.ipv6=0'
uci set 'dhcp.lan.dhcpv6=disabled'
/etc/init.d/odhcpd disable
uci commit

uci -q delete dhcp.lan.dhcpv6
uci -q delete dhcp.lan.ra
uci commit dhcp
/etc/init.d/odhcpd restart

uci set network.lan.delegate="0"
uci commit network
/etc/init.d/network restart

/etc/init.d/odhcpd disable
/etc/init.d/odhcpd stop

uci -q delete network.globals.ula_prefix
uci commit network
/etc/init.d/network restart
```

## Adguard Home
https://openwrt.org/docs/guide-user/services/dns/adguard-home
```
opkg update
opkg install adguardhome
```
```
service adguardhome enable
service adguardhome start
```
Settings for Adguard
```
NET_ADDR=$(/sbin/ip -o -4 addr list br-lan | awk 'NR==1{ split($4, ip_addr, "/"); print ip_addr[1]; exit }')
NET_ADDR6=$(/sbin/ip -o -6 addr list br-lan scope global | awk '$4 ~ /^fd|^fc/ { split($4, ip_addr, "/"); print ip_addr[1]; exit }')
echo "Router IPv4 : ""${NET_ADDR}"
echo "Router IPv6 : ""${NET_ADDR6}"
 
uci set dhcp.@dnsmasq[0].port="54"
uci set dhcp.@dnsmasq[0].domain="lan"
uci set dhcp.@dnsmasq[0].local="/lan/"
uci set dhcp.@dnsmasq[0].expandhosts="1"
uci set dhcp.@dnsmasq[0].cachesize="0"
uci set dhcp.@dnsmasq[0].noresolv="1"
uci -q del dhcp.@dnsmasq[0].server
 
uci -q del dhcp.lan.dhcp_option
uci -q del dhcp.lan.dns
 
uci add_list dhcp.lan.dhcp_option='3,'"${NET_ADDR}"
 
uci add_list dhcp.lan.dhcp_option='6,'"${NET_ADDR}" 
 
uci add_list dhcp.lan.dhcp_option='15,'"lan"
 
uci add_list dhcp.lan.dns="$NET_ADDR6"
 
uci commit dhcp
service dnsmasq restart
service odhcpd restart
exit 0
```