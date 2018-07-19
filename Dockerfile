FROM alpine

LABEL MAINTAINER "motofans.club" \
    ARCHITECTURE "amd64"

# 系统环境
ENV APK_MIRROR="dl-cdn.alpinelinux.org" \
    APK_MIRROR_SCHEME="http" \
    BASED_PKG="gnutls-utils iptables libnl3 geoip readline gpgme ca-certificates libcrypto1.0 libev libsodium mbedtls pcre udns" \
    BUILD_PKG="wget py-pip linux-headers autoconf g++ gcc make libev-dev curl tar xz nettle-dev gnutls-dev protobuf-c-dev talloc-dev linux-pam-dev readline-dev http-parser-dev lz4-dev geoip-dev libseccomp-dev libnl3-dev krb5-dev freeradius-client-dev automake build-base gettext-dev libsodium-dev libtool mbedtls-dev openssl-dev pcre-dev udns-dev"

# 应用版本
ENV OC_VERSION=0.12.1 \
    SS_LIBEV_VERSION=3.0.5

# 系统配置 
RUN set -x \
    && echo "This ia a docker image of Ocserv." \
    && echo "****************************************************************************" \
    && echo "Start Building the Docker Image, Please Wait ..." \
    && echo -e "\033[33m -> Modifing APK reposiroties config ...\033[0m" \
    && sed -i "s/dl-cdn.alpinelinux.org/${APK_MIRROR}/g" /etc/apk/repositories \
    && sed -i "s/http/${APK_MIRROR_SCHEME}/g" /etc/apk/repositories \
    && echo -e "\033[33m -> Updating APK repositories ...\033[0m" \
    && apk update \
    && echo -e "\033[33m -> Upgrading System ...\033[0m" \
    && apk upgrade \
    && echo -e "\033[33m -> Installing Base Package ...\033[0m" \
    && apk add --no-cache ${BASED_PKG} \
    && apk add --no-cache --virtual .build-deps ${BUILD_PKG} \
    && echo -e "\033[33m -> Done! \033[0m"

# 编译安装 Ocserv
RUN set -x \
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
    && mkdir -p /etc/ocserv 

# 安装 V2Ray

ADD https://storage.googleapis.com/v2ray-docker/v2ray /usr/bin/v2ray/
ADD https://storage.googleapis.com/v2ray-docker/v2ctl /usr/bin/v2ray/
ADD https://storage.googleapis.com/v2ray-docker/geoip.dat /usr/bin/v2ray/
ADD https://storage.googleapis.com/v2ray-docker/geosite.dat /usr/bin/v2ray/

RUN set -x \
    mkdir /var/log/v2ray/ &&\
    chmod +x /usr/bin/v2ray/v2ctl && \
    chmod +x /usr/bin/v2ray/v2ray

# 清理系统
RUN rm -rf /src \
    && OC_RUN_Deps="$( \
    scanelf --needed --nobanner /usr/local/sbin/ocserv \
    | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
    | xargs -r apk info --installed \
    | sort -u \
    )" \
    && SS_RUN_Deps="$( \
    scanelf --needed --nobanner /usr/bin/ss-local \
    | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
    | xargs -r apk info --installed \
    | sort -u \
    )" \
    && apk del .build-deps \
    && apk add --virtual .oc-run-deps $OC_RUN_Deps \
    && apk add --virtual .ss-run-deps $SS_RUN_Deps \
    && rm -rf /var/cache/apk/*
