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
```bash
opkg update
opkg install adguardhome
```
```bash
service adguardhome enable
service adguardhome start
```
Settings for Adguard
```bash
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

## Tailscale
```bash
opkg update
opkg install tailscale
```

```bash
/etc/init.d/tailscale enable
/etc/init.d/tailscale start
```
If it fails `tailscaled &`

```bash
uci add firewall zone
uci set firewall.@zone[-1].name='tailscale'
uci set firewall.@zone[-1].input='ACCEPT'
uci set firewall.@zone[-1].output='ACCEPT'
uci set firewall.@zone[-1].forward='ACCEPT'
uci set firewall.@zone[-1].masq='1'
uci set firewall.@zone[-1].device='tailscale0'
```

```bash
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='lan'
uci set firewall.@forwarding[-1].dest='tailscale'
```

```bash
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='tailscale'
uci set firewall.@forwarding[-1].dest='lan'
```

```bash
uci commit firewall
/etc/init.d/firewall restart
```

```bash
uci set network.lan.delegate='1'
uci commit network
/etc/init.d/network restart
```

```bash
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
```

[TS_AUTHKEY setup](./Headscale.md)
```bash
tailscale up \
  --authkey=TS_AUTHKEY \
  --login-server=https://your.headscale.domain \
  --accept-routes
```

## VLAN
Step 1: Configure the Switch VLAN
```
1. Go to Network → Switch in LuCI
2. Modify existing VLANs:
   - VLAN 1 (your main LAN):
     - LAN Port 2: off (remove it from main LAN)
     - Keep other ports as they are

   - VLAN 2 (WAN):
     - LAN Port 2: off (should already be off)
     - Keep as is
3. Add a new VLAN row:
   - VLAN 10 (new KVM VLAN):
     - VLAN ID: 10
     - CPU (eth0): tagged
     - LAN Port 1: off
     - LAN Port 2: untagged ← Your KVM port
     - LAN Port 3: off
     - LAN Port 4: off
     - WAN Port: off
4. Click Save & Apply
```
Step 2: Create the KVM Network Interface
```
1. Go to Network → Interfaces
2. Click Add new interface
3. Configure:
    - Name: kvm
    - Protocol: Static address
    - Click Create interface
4. In the General Settings tab:
    - Device: Click Configure... and create a bridge device
      - Select eth0.10 as the bridge port
    - IPv4 address: xx.xx.x.1
    - IPv4 netmask: 255.255.255.0
5. In the Advanced Settings tab: (options to ensure use of AdGuard Home)
    - Use custom DNS servers: Your AdGuard Home IP
6. In the DHCP Server tab:
    - Check Enable DHCP server
    - Start: 100
    - Limit: 100
    - Under Advanced Settings:
      - Add DHCP Option: 6,Your AdGuard Home IP (if you have custom DNS)
7. In the Firewall Settings tab:
    - Create / Assign firewall-zone: Select unspecified or create new zone kvm
8. Click Save & Apply
```
Step 3: Configure Firewall Zones
```
1. Go to Network → Firewall
2. Create a new zone for KVM:
  - Input: accept
  - Output: accept
  - Forward: reject
  - Masquerading: unchecked
  - MSS clamping: unchecked
  - Covered networks: kvm
3. Inter-Zone Forwarding (at the bottom of zone settings):
  - DO NOT add any forwarding from kvm to other zones here
  - We'll use specific rules instead
4. Click Save & Apply
```
Step 4: Create Specific Firewall Rules
```
Go to Network → Firewall → Traffic Rules, add these rules:
Rule 1: Allow access FROM your LAN TO KVMs
  - Click Add
  - Name: Allow LAN to KVM
  - Source zone: lan
  - Destination zone: kvm
  - Action: accept
  - Click Save

Rule 2: Allow DNS queries FROM KVMs TO AdGuard Home (if you have custom DNS)
  - Click Add
  - Name: Allow KVM DNS to AdGuard
  - Source zone: kvm
  - Destination zone: lan
  - Destination address: 10.20.10.11
  - Destination port: 53
  - Protocol: TCP+UDP
  - Action: accept
  - Click Save

Rule 3 (Optional but recommended): Explicitly block KVM to WAN
  - Click Add
  - Name: Block KVM to WAN
  - Source zone: kvm
  - Destination zone: wan
  - Action: reject
  - Click Save

Click Save & Apply at the bottom
```
Step 5: Verify Configuration
```
lan → kvm: accept
kvm → lan: reject (default, but DNS rule allows port 53 only - if set)
kvm → wan: reject
```