#!/bin/sh
set -xe

CONFIG_FILE=/etc/ocserv/ocserv.conf
CLIENT="${VPN_USERNAME}@${VPN_DOMAIN}"

echo "$PORT"
echo "$VPN_DOMAIN"
echo "$VPN_IP"
echo "$VPN_NETWORK"
echo "$VPN_NETMASK"
echo "$VPN_USERNAME"
echo "$VPN_PASSWORD"
echo "$V2RAY_SERVER"
echo "$V2RAY_PORT"
echo "$V2RAY_ID"
echo "$V2RAY_ALTERID"
echo "$OC_GENERATE_KEY"
echo "$RADIUS_SHAREKEY"
echo "$RADIUS_SERVER"

function changeConfig() {
	local prop=$1
	local var=$2
	if [ -n "$var" ]; then
		echo "[INFO] Setting $prop to $var"
		sed -i "/$prop\s*=/ c $prop=$var" $CONFIG_FILE
	fi
}

# Select Server Certs
if [ "$OC_GENERATE_KEY" = "false" ]; then
	changeConfig "server-key" "/etc/ocserv/certs/${VPN_DOMAIN}.key"
	changeConfig "server-cert" "/etc/ocserv/certs/${VPN_DOMAIN}.crt"
else
	changeConfig "server-key" "/etc/ocserv/certs/${VPN_DOMAIN}.self-signed.key"
	changeConfig "server-cert" "/etc/ocserv/certs/${VPN_DOMAIN}.self-signed.crt"
fi

# Init Ocserv
/init.sh

# Enable TUN device
if [ ! -e /dev/net/tun ]; then
	mkdir -p /dev/net
	mknod /dev/net/tun c 10 200
	chmod 600 /dev/net/tun
fi

# OCServ Network Settings
sed -i -e "s@^ipv4-network =.*@ipv4-network = ${VPN_NETWORK}@" \
	-e "s@^default-domain =.*@default-domain = ${VPN_DOMAIN}@" \
	-e "s@^ipv4-netmask =.*@ipv4-netmask = ${VPN_NETMASK}@" $CONFIG_FILE
#changeConfig "udp-port" "$PORT"
changeConfig "tcp-port" "$PORT"

# Config V2Ray-Client
sed -i "s/d.c.b.a/${V2RAY_SERVER}/g" /etc/v2ray/config.json
sed -i "s/10011/${V2RAY_PORT}/g" /etc/v2ray/config.json
sed -i "s/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/${V2RAY_ID}/g" /etc/v2ray/config.json
sed -i "s/64/${V2RAY_ALTERID}/g" /etc/v2ray/config.json

# Radius Client Config
cat > /etc/radiusclient/radiusclient.conf <<_EOF_
nas-identifier acray
authserver 		$RADIUS_SERVER
acctserver 		$RADIUS_SERVER
servers			/etc/radiusclient/servers
dictionary 		/etc/radiusclient/dictionary
login_radius    /usr/sbin/login.radius
seqfile         /var/run/radius.seq
mapfile         /etc/radiusclient/port-id-map
default_realm
radius_timeout	10
radius_retries	3
bindaddr		*
_EOF_

# Radius Share Key
cat > /etc/radiusclient/servers << _EOF_
$RADIUS_SERVER		$RADIUS_SHAREKEY
_EOF_

# 自动适应 MTU
iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
# 伪装 VPN 子网流量
iptables -t nat -A POSTROUTING -s ${VPN_NETWORK}/${VPN_NETMASK} -j MASQUERADE

# Run ACRay Server
exec nohup /usr/bin/v2ray -config=/etc/v2ray/config.json >/dev/null 2>%1 &
exec nohup ocserv -c /etc/ocserv/ocserv.conf -f -d 1 "$@"