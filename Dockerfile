FROM daocloud.io/subaru/acray:based

LABEL MAINTAINER "motofans.club" \
    ARCHITECTURE "amd64"

ENV PORT=443 \  
    VPN_DOMAIN=i.motofans.club \
    VPN_NETWORK=100.64.1.0 \
    VPN_NETMASK=255.255.255.0 \
    VPN_USERNAME=opsvpn \
    VPN_PASSWORD=opsvpn \
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

VOLUME [ "/etc/ocserv/config-per-user" ]
VOLUME [ "/etc/ocserv/certs" ]

ENTRYPOINT ["/entrypoint.sh"]