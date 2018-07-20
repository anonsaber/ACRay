FROM daocloud.io/subaru/acray:based

LABEL MAINTAINER "motofans.club" \
    ARCHITECTURE "amd64"

ENV PORT=443 \  
    VPN_DOMAIN=motofans.club \
    VPN_IP=4.3.2.1 \
    VPN_NETWORK=100.64.1.0 \
    VPN_NETMASK=255.255.255.0 \
    VPN_USERNAME=opsvpn \
    VPN_PASSWORD=opsvpn \
    V2RAY_SERVER=1.2.3.4 \
    V2RAY_PORT=10011 \
    V2RAY_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
    V2RAY_ALTERID=64 \
    OC_CERT_AND_PLAIN=true \
    OC_GENERATE_KEY=true

RUN echo "Make some dirs..." \
    && mkdir -p /etc/ocserv/certs \
    && mkdir -p /etc/ocserv/config-per-group \
    && mkdir -p /etc/ocserv/config-per-user

COPY config.json /etc/v2ray/config.json
COPY ocserv.conf /etc/ocserv
COPY entrypoint.sh /entrypoint.sh
COPY nolocal /etc/ocserv/config-per-group/nolocal
COPY nocn /etc/ocserv/config-per-group/nocn

RUN chmod a+x /entrypoint.sh

VOLUME [ "/etc/ocserv/config-per-group" ]
VOLUME [ "/etc/ocserv/config-per-user" ]
VOLUME [ "/etc/ocserv/certs" ]

ENTRYPOINT ["/entrypoint.sh"]