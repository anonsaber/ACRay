FROM daocloud.io/subaru/acray:based

LABEL MAINTAINER "motofans.club"

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
    OC_GENERATE_KEY=true \
    RADIUS_SERVER=radius.motofans.club \
    RADIUS_SHAREKEY=yoursharekey

RUN mkdir -p /etc/ocserv/certs
    
COPY ocserv.conf /etc/ocserv/ocserv.conf
COPY config.json /etc/v2ray/config.json

COPY entrypoint.sh /entrypoint.sh
COPY init.sh /init.sh

RUN chmod a+x /entrypoint.sh
RUN chmod a+x /init.sh

VOLUME [ "/etc/ocserv/certs" ]

ENTRYPOINT ["/entrypoint.sh"]