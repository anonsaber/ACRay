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

# Creat TMPL
cd /etc/ocserv/certs

cat >ocserv-ca.tmpl <<_EOF_
cn = "ocserv Root CA"
organization = "ocserv"
serial = 1
expiration_days = 3650
ca
signing_key
cert_signing_key
crl_signing_key
_EOF_

cat >ocserv-server.tmpl <<_EOF_
cn = "${VPN_DOMAIN}"
dns_name = "${VPN_DOMAIN}"
organization = "${VPN_DOMAIN}"
serial = 2
expiration_days = 3650
signing_key
encryption_key
tls_www_server
_EOF_

# Generate CA
if [ ! -f /etc/ocserv/certs/ocserv-ca-key.pem ]; then
  echo "[INFO] generating root CA"
  # gen ca keys
  certtool --generate-privkey \
           --outfile ocserv-ca-key.pem           
  certtool --generate-self-signed \
           --load-privkey /etc/ocserv/certs/ocserv-ca-key.pem \
           --template ocserv-ca.tmpl \
           --outfile ocserv-ca-cert.pem
fi

# Generate Server Certs
if [ "$OC_GENERATE_KEY" != "false" ] && [ ! -f /etc/ocserv/certs/"${VPN_DOMAIN}".self-signed.crt ] ; then
  echo "[INFO] generating server certs"
  # gen server keys
  certtool --generate-privkey \
           --outfile "${VPN_DOMAIN}".self-signed.key
  certtool --generate-certificate \
           --load-privkey "${VPN_DOMAIN}".self-signed.key \
           --load-ca-certificate ocserv-ca-cert.pem \
           --load-ca-privkey ocserv-ca-key.pem \
           --template ocserv-server.tmpl \
           --outfile "${VPN_DOMAIN}".self-signed.crt
fi

rm ocserv-ca.tmpl
rm ocserv-server.tmpl

# Enable TUN device
if [ ! -e /dev/net/tun ]; then
	mkdir -p /dev/net
	mknod /dev/net/tun c 10 200
	chmod 600 /dev/net/tun
fi

# Creat User
echo "${VPN_PASSWORD}" | ocpasswd -c /etc/ocserv/ocpasswd -g "Common" "${VPN_USERNAME}"

# OCServ Group Settings
[ ! -f /etc/ocserv/config-per-group/Fully ] && cp /etc/pre-config/Fully /etc/ocserv/config-per-group
[ ! -f /etc/ocserv/config-per-group/Common ] && cp /etc/pre-config/Common /etc/ocserv/config-per-group
[ ! -f /etc/ocserv/config-per-group/Android ] && cp /etc/pre-config/Android /etc/ocserv/config-per-group

# OCServ Network Settings
sed -i -e "s@^ipv4-network =.*@ipv4-network = ${VPN_NETWORK}@" \
	-e "s@^default-domain =.*@default-domain = ${VPN_DOMAIN}@" \
	-e "s@^ipv4-netmask =.*@ipv4-netmask = ${VPN_NETMASK}@" $CONFIG_FILE
changeConfig "tcp-port" "$PORT"
changeConfig "udp-port" "$PORT"

# Config V2Ray
sed -i "s/d.c.b.a/${V2RAY_SERVER}/g" /etc/v2ray/config.json
sed -i "s/10011/${V2RAY_PORT}/g" /etc/v2ray/config.json
sed -i "s/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/${V2RAY_ID}/g" /etc/v2ray/config.json
sed -i "s/64/${V2RAY_ALTERID}/g" /etc/v2ray/config.json

# Enable NAT forwarding
# sysctl -w net.ipv4.ip_forward=1
# iptables -t nat -A POSTROUTING -j MASQUERADE
# 自动适应 MTU
iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
# 伪装 VPN 子网流量
iptables -t nat -A POSTROUTING -s ${VPN_NETWORK}/${VPN_NETMASK} -j MASQUERADE
# 创建 V2Ray NAT 表
iptables -t nat -N V2RAY
iptables -t nat -A PREROUTING -s ${VPN_NETWORK}/${VPN_NETMASK} -p tcp -j V2RAY
# 不转发 V2Ray NAT 表中访问部分地址的流量
iptables -t nat -A V2RAY -d ${VPN_IP}/24 -j RETURN
iptables -t nat -A V2RAY -d 119.29.29.29/24 -j RETURN
iptables -t nat -A V2RAY -d 8.8.8.8/24 -j RETURN
# 转发 V2Ray NAT 表中的流量到 V2Ray Local
iptables -t nat -A V2RAY -p tcp -j REDIRECT --to-ports 12345

# Run ACRay Server
exec nohup /usr/bin/v2ray -config=/etc/v2ray/config.json >/dev/null 2>%1 &
exec nohup ocserv -c /etc/ocserv/ocserv.conf -f -d 1 "$@"