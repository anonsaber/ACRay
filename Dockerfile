FROM daocloud.io/subaru/acray:based

LABEL MAINTAINER "motofans.club" \
    ARCHITECTURE "amd64"

ENV PORT=443 \  
    VPN_DOMAIN=motofans.club \
    VPN_IP=a.b.c.d \
    VPN_NETWORK=100.64.1.0 \
    VPN_NETMASK=255.255.255.0 \
    VPN_USERNAME=opsvpn \
    VPN_PASSWORD=opsvpn \
    V2RAY_SERVER=d.c.b.a \
    V2RAY_PORT=10011 \
    V2RAY_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
    V2RAY_ALTERID=64 \
    OC_CERT_AND_PLAIN=true \
    OC_GENERATE_KEY=true

RUN echo "Make some dirs..." \
    && mkdir -p /etc/pre-config \
    && mkdir -p /etc/ocserv/certs \
    && mkdir -p /etc/ocserv/config-per-group \
    && mkdir -p /etc/ocserv/config-per-user

COPY ocserv.conf /etc/pre-config/ocserv.conf
COPY Fully /etc/pre-config/Fully
COPY Common /etc/pre-config/Common
COPY Android /etc/pre-config/Android

COPY config.json /etc/v2ray/config.json

COPY entrypoint.sh /entrypoint.sh

RUN chmod a+x /entrypoint.sh

VOLUME [ "/etc/ocserv" ]

ENTRYPOINT ["/entrypoint.sh"]
