#!/bin/sh

set -xe

CONFIG_FILE=/etc/ocserv/ocserv.conf
CLIENT="${VPN_USERNAME}@${VPN_DOMAIN}"
echo "$PORT"
echo "$VPN_DOMAIN"
echo "$VPN_NETWORK"
echo "$VPN_NETMASK"
echo "$VPN_USERNAME"
echo "$VPN_PASSWORD"
echo "$SS_IP"
echo "$SS_PORT"
echo "$SS_PASS"
echo "$SS_METHOD"
echo "$OC_CERT_AND_PLAIN"
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

cat >ocserv-client.tmpl <<_EOF_
cn = "client@${VPN_DOMAIN}"
uid = "client@${VPN_DOMAIN}"
unit = "ocserv"
expiration_days = 3650
signing_key
tls_www_client
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

# Generate Client Certs
if [ ! -f /etc/ocserv/certs/"${CLIENT}".p12 ]; then
  echo "[INFO] generating client certs"
  # gen client keys
  certtool --generate-privkey \
           --outfile "${CLIENT}"-key.pem

  certtool --generate-certificate \
           --load-privkey "${CLIENT}"-key.pem \
           --load-ca-certificate ocserv-ca-cert.pem \
           --load-ca-privkey ocserv-ca-key.pem \
           --template ocserv-client.tmpl \
           --outfile "${CLIENT}"-cert.pem

  certtool --to-p12 \
           --pkcs-cipher 3des-pkcs12 \
           --load-ca-certificate ocserv-ca-cert.pem \
           --load-certificate "${CLIENT}"-cert.pem \
           --load-privkey "${CLIENT}"-key.pem \
           --outfile "${CLIENT}".p12 \
           --outder \
           --p12-name "${VPN_DOMAIN}" \
           --password "${VPN_PASSWORD}"
fi

rm ocserv-ca.tmpl
rm ocserv-server.tmpl
rm ocserv-client.tmpl

# Enable TUN device
if [ ! -e /dev/net/tun ]; then
	mkdir -p /dev/net
	mknod /dev/net/tun c 10 200
	chmod 600 /dev/net/tun
fi

# User Settings
if [ "$OC_CERT_AND_PLAIN" = "true" ]; then
	echo "${VPN_PASSWORD}" | ocpasswd -c /etc/ocserv/ocpasswd -g "nocn" "${VPN_USERNAME}"
else
	echo -n "${VPN_PASSWORD}${RANDOM}" | md5sum | sha256sum | ocpasswd -c /etc/ocserv/ocpasswd -g "nocn" "${VPN_USERNAME}"
fi

# Network Settings
sed -i -e "s@^ipv4-network =.*@ipv4-network = ${VPN_NETWORK}@" \
	-e "s@^ipv4-netmask =.*@ipv4-netmask = ${VPN_NETMASK}@" $CONFIG_FILE

changeConfig "tcp-port" "$PORT"
changeConfig "udp-port" "$PORT"

# Enable NAT forwarding
# sysctl -w net.ipv4.ip_forward=1
# iptables -t nat -A POSTROUTING -j MASQUERADE
# iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
iptables -t nat -A POSTROUTING -s ${VPN_NETWORK}/${VPN_NETMASK} -j MASQUERADE

# Config Privoxy
cd /etc/privoxy
mv config config.bak
cat >config <<_EOF_
confdir /etc/privoxy
logdir /var/log/privoxy
actionsfile match-all.action 
actionsfile default.action   
actionsfile user.action
filterfile default.filter
filterfile user.filter      
logfile privoxy.log
listen-address  172.31.1.2:8118
forward-socks5t / 172.31.1.2:1080 .
toggle  1
enable-remote-toggle  0
enable-remote-http-toggle  0
enable-edit-actions 0
enforce-blocks 0
buffer-limit 4096
enable-proxy-authentication-forwarding 0
forwarded-connect-retries  0
accept-intercepted-requests 0
allow-cgi-request-crunching 0
split-large-forms 0
keep-alive-timeout 5
tolerate-pipelining 1
socket-timeout 300
_EOF_

# Config SS-Local
cd /etc
cat >shadowsocks.conf <<_EOF_
{
    "server":"${SS_IP}",
    "server_port":${SS_PORT},
    "local_address": "172.31.1.2",
    "local_port":1080,
    "password":"${SS_PASS}",
    "timeout":"600",
    "method":"${SS_METHOD}"
}
_EOF_

# Run OPPS Server
exec nohup ss-local -c /etc/shadowsocks.conf >/dev/null 2>%1 &
exec nohup privoxy /etc/privoxy/config >/dev/null 2>%1 &
exec nohup ocserv -c /etc/ocserv/ocserv.conf -f -d 1 "$@"
