FROM ccr.ccs.tencentyun.com/based-image/alpine:based

ENV BASED_PKG_1="bash tzdata gnutls-utils iptables libtool libnl3 geoip readline gpgme ca-certificates libcrypto1.0 libev libsodium mbedtls pcre udns" \
    BASED_PKG_2="gettext-dev libsodium-dev mbedtls-dev openssl-dev pcre-dev udns-dev nettle-dev gnutls-dev protobuf-c-dev talloc-dev linux-pam-dev readline-dev http-parser-dev lz4-dev geoip-dev libseccomp-dev libnl3-dev krb5-dev freeradius-client-dev" \
    BUILD_PKG="wget curl libev-dev py-pip linux-headers autoconf g++ gcc make tar xz automake build-base"

# 安装 OCserv 与 V2RAY
ENV OC_VERSION 1.1.2
ENV V2RAY_VERSION v4.27.5 
ENV V2RAY_LOG_DIR /var/log/v2ray
ENV V2RAY_CONFIG_DIR /etc/v2ray/
ENV V2RAY_DOWNLOAD_URL https://github.com/v2fly/v2ray-core/releases/download/${V2RAY_VERSION}/v2ray-linux-64.zip

RUN echo -e "\033[33m -> Installing Based Package ...\033[0m" \
    && apk add --no-cache ${BASED_PKG_1} \
    && apk add --no-cache ${BASED_PKG_2} \
    && apk add --no-cache --virtual .build-deps ${BUILD_PKG} \
    && echo -e "\033[33m -> Installing Ocserv ...\033[0m" \
    && mkdir /src \
    && cd /src \
    && OC_FILE="ocserv-$OC_VERSION" \
    && wget ftp://ftp.infradead.org/pub/ocserv/$OC_FILE.tar.xz \
    && tar xJf $OC_FILE.tar.xz \
    && rm -rf $OC_FILE.tar.xz \
    && cd $OC_FILE \
    && sed -i '/#define DEFAULT_CONFIG_ENTRIES /{s/96/200/}' src/vpn.h \
    && ./configure \
    && make -j"$(nproc)" \
    && make install \
    && rm -rf /src \
    && mkdir -p /etc/ocserv/certs \
    && echo -e "\033[33m -> Installing V2Ray Client ...\033[0m" \
    && mkdir -p ${V2RAY_LOG_DIR} \
    && mkdir -p ${V2RAY_CONFIG_DIR} \
    && curl -L -H "Cache-Control: no-cache" -o /tmp/v2ray.zip ${V2RAY_DOWNLOAD_URL} \
    && unzip /tmp/v2ray.zip -d /tmp/ \
    && mv /tmp/v2ray /usr/bin \
    && mv /tmp/v2ctl /usr/bin \
    && mv /tmp/geoip.dat /usr/bin \
    && mv /tmp/geosite.dat /usr/bin \
    && chmod +x /usr/bin/v2ray \
    && chmod +x /usr/bin/v2ctl \
    && OC_RUN_Deps="$( \
    scanelf --needed --nobanner /usr/local/sbin/ocserv \
    | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
    | xargs -r apk info --installed \
    | sort -u \
    )" \
    && apk del .build-deps \
    && apk add --virtual .oc-run-deps $OC_RUN_Deps \
    && rm -rf /tmp/* \
    && rm -rf /var/cache/apk/* \
    && echo -e "\033[33m -> ALL IS WELL ...\033[0m"
