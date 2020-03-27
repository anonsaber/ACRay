FROM ccr.ccs.tencentyun.com/based-image/alpine:based

LABEL MAINTAINER "motofans.club" \
      ARCHITECTURE "amd64"

ARG TZ="Asia/Shanghai"

# 系统环境
ENV TZ ${TZ}
ENV TERM=xterm
ENV APK_MIRROR="mirrors.aliyun.com" \
    APK_MIRROR_SCHEME="http" \
    BASED_PKG_1="bash tzdata gnutls-utils iptables libtool libnl3 geoip readline gpgme ca-certificates libcrypto1.0 libev libsodium mbedtls pcre udns" \
    BASED_PKG_2="gettext-dev libsodium-dev mbedtls-dev openssl-dev pcre-dev udns-dev nettle-dev gnutls-dev protobuf-c-dev talloc-dev linux-pam-dev readline-dev http-parser-dev lz4-dev geoip-dev libseccomp-dev libnl3-dev krb5-dev freeradius-client-dev" \
    BUILD_PKG="wget curl libev-dev py-pip linux-headers autoconf g++ gcc make tar xz automake build-base"

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
    && apk add --no-cache ${BASED_PKG_1} \
    && apk add --no-cache ${BASED_PKG_2} \
    && apk add --no-cache --virtual .build-deps ${BUILD_PKG} \
    && echo -e "\033[33m -> Done! \033[0m"

# 应用版本
ENV OC_VERSION=0.12.2

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
    && rm -rf /src \
    && mkdir -p /etc/ocserv

# 安装 V2Ray
ENV V2RAY_VERSION v4.22.1 
ENV V2RAY_LOG_DIR /var/log/v2ray
ENV V2RAY_CONFIG_DIR /etc/v2ray/
ENV V2RAY_DOWNLOAD_URL https://github.com/v2ray/v2ray-core/releases/download/${V2RAY_VERSION}/v2ray-linux-64.zip

RUN mkdir -p \ 
    ${V2RAY_LOG_DIR} \
    ${V2RAY_CONFIG_DIR} \
    /tmp/v2ray \
    && curl -L -H "Cache-Control: no-cache" -o /tmp/v2ray/v2ray.zip ${V2RAY_DOWNLOAD_URL} \
    && unzip /tmp/v2ray/v2ray.zip -d /tmp/v2ray/ \
    && mv /tmp/v2ray/v2ray-${V2RAY_VERSION}-linux-64/v2ray /usr/bin \
    && mv /tmp/v2ray/v2ray-${V2RAY_VERSION}-linux-64/v2ctl /usr/bin \
    && mv /tmp/v2ray/v2ray-${V2RAY_VERSION}-linux-64/geoip.dat /usr/bin \
    && mv /tmp/v2ray/v2ray-${V2RAY_VERSION}-linux-64/geosite.dat /usr/bin \
    && chmod +x /usr/bin/v2ray \
    && chmod +x /usr/bin/v2ctl \
    && rm -rf /tmp/v2ray \
    && ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone

# 清理系统
RUN OC_RUN_Deps="$( \
    scanelf --needed --nobanner /usr/local/sbin/ocserv \
    | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
    | xargs -r apk info --installed \
    | sort -u \
    )" \
    && apk del .build-deps \
    && apk add --virtual .oc-run-deps $OC_RUN_Deps \
    && rm -rf /var/cache/apk/*
