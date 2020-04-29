# ACRay
## 前言

通常，我们直接在设备上连接国外 VPS 上搭建的 SS-Server / V2Ray Server 来实现科学上网。

用这样的方法，可能会遇到一些问题，比如 IP 被 BAN 掉，不同线路的访问速度差距较大，客户端配置较为繁琐，在企业环境应用起来尤其如此...

你可能也会直接在 VPS 上架设 VPN...但是这样的办法也会产生问题，比如，路由表的控制难以精确，造成部分站点的无法访问。

另外，无论使用上述哪个办法，DNS 解析全球 CDN 站点时可能将 IP 解析到国外节点这个问题都很难解决，这会造成本土站点访问速度下降，且浪费不必要的流量...

那么有没有在企业环境下比较完美的办法？

## 参考文献

* [分流中转: https://sosonemo.me/strongswan-to-shadowsocks.html](https://sosonemo.me/strongswan-to-shadowsocks.html)

## 我的设想

**使用 Ocserv + V2Ray-Local 实现智能分流**

### Ocserv

Cisco Anyconnect 是思科推出的一款企业级 VPN。其背后的开源技术是[OpenConnect](http://en.wikipedia.org/wiki/OpenConnect)。简单来说就是平时使用 UDP 的[DTLS](http://en.wikipedia.org/wiki/Datagram_Transport_Layer_Security)协议进行加密，掉线时自动使用 TCP 的 TLS 协议进行备份恢复，因此相对其它 VPN 比较稳定；而且广泛被大企业采用，不容易被误杀；加之比较小众，架设起来不太容易，也吸引不了很多的火力。

### V2Ray

V2Ray 是一个模块化的代理软件包，它的目标是提供常用的代理软件模块，简化网络代理软件的开发。

![ACRay.png](https://github.com/XiaFanGit/ACRay/raw/master/ACRay.png)

**基于这个方案，我们的浏览器去访问网站时大致是这样一个过程:**

1. Anyconnect 链接 Ocserv 后 ，Ocserv 推送 Route Table，DNS 以及 PAC 到 Client
2. Anyconnect 将 Route Table 中的 IP 访问流量截获到 Ocserv，用于访问 Proxy Server 及其他的内部地址
3. Anyconnect 根据获取的 PAC，对符合规则的流量进行 Proxy，在远程服务器 V2ray Local 完成解析和访问
4. 对于既不存在 Route Table 中，也不符合 PAC 规则的流量，通过 Ocserv 推送的 DNS 在 Ocserv 完成解析，并在 Client 直接访问
5. 对于上述访问流程的控制，Route Table 的优先级高于 PAC
6. Ocserv 推送的 DNS 地址可以是公共 DNS 也可以是私有的

**需要的必要条件:**

* 国内一台公网服务器节点: Ocserv + V2ray-Local
* 国外一台服务器节点: V2ray-Server

**需要自行准备的:**

* OpenLDAP + Radius Server 用作认证系统
 
## 部署 ACRay

本问仅介绍如何在国内节点部署 Ocserv + V2Ray-Local，并不介绍如何在国外 VPS 上部署 V2Ray Server。

由于 Ocserv 的安装较为复杂，为了简化部署，我写了一份 Dockerfile，本文将通过 Docker 完成 ACRay 的部署。

项目地址: https://github.com/XiaFanGit/ACRay

**docker-compose.yml**

```yml
version: '2'

volumes:
  acray-per-group:
    external:
      name: acray-per-group
  acray-certs:
    external:
      name: acray-certs

services:
  acray:
    image: daocloud.io/subaru/acray
    hostname: acray
    container_name: acray
    restart: always
    networks:
      overlay-net:
        ipv4_address: 172.31.255.254
    environment:
    - PORT=999
    - VPN_DOMAIN=motofans.club
    - VPN_IP=123.45.67.89
    - CLIENT_IP=123.45.67.90
    - V2RAY_SERVER=ray.motofans.club
    - V2RAY_PORT=10011
    - V2RAY_ID=a2e57082-6d69-461e-xxxx-6a0095bf6f46
    - V2RAY_ALTERID=64
    - VPN_NETWORK=100.64.2.0
    - VPN_NETMASK=255.255.255.0
    - OC_GENERATE_KEY=false
    - RADIUS_SERVER=radius-server
    - RADIUS_SHAREKEY=Saber@965mi251
    - PAC_URL=https://git.motofans.club/xiafan/ACRay/raw/pac/pub.pac
    ports:
    - 999:999
    - 1080:1080
    volumes:
    - acray-certs:/etc/ocserv/certs
    - acray-per-group:/etc/ocserv/config-per-group
    cap_add:
    - NET_ADMIN

networks:
  overlay-net:
    external: true
```
