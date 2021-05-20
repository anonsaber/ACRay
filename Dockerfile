FROM ccr.ccs.tencentyun.com/emiya-app/acray:based
    
COPY ocserv.conf /etc/ocserv/ocserv.conf
COPY config.json /etc/v2ray/config.json

COPY entrypoint.sh /entrypoint.sh
COPY init.sh /init.sh

RUN chmod a+x /entrypoint.sh
RUN chmod a+x /init.sh

VOLUME [ "/etc/ocserv/certs" ]

ENTRYPOINT ["/entrypoint.sh"]
