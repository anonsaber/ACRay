#!/bin/sh
set -xe

# Creat Tmpl Files
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
if [ "$OC_GENERATE_KEY" != "false" ] && [ ! -f /etc/ocserv/certs/"${VPN_DOMAIN}".self-signed.crt ]; then
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

# Remove Tmpl Files
rm ocserv-ca.tmpl
rm ocserv-server.tmpl
