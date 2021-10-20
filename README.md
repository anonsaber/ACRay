# ACRay

Docs: https://acray.motofans.club

**Support Device**: IOS/Windows/MacOS/Linux/ChromeOS/UWP/BlackBerry

**Don't Support Android Mobile**

![ACRay.png](https://github.com/XiaFanGit/ACRay/raw/master/ACRay.png)

**基于这个方案，我们的浏览器去访问网站时大致是这样一个过程:**

1. Anyconnect 链接 Ocserv 后 ，Ocserv 推送 Route Table，DNS 以及 PAC 到 Client
2. Anyconnect 将 Route Table 中的 IP 访问流量截获到 Ocserv，用于访问 Proxy Server 及其他的内部地址
3. Anyconnect 根据获取的 PAC，对符合规则的流量进行 Proxy，在远程服务器 V2ray Local 完成解析和访问
4. 对于既不存在 Route Table 中，也不符合 PAC 规则的流量，通过 Ocserv 推送的 DNS 在 Ocserv 完成解析，并在 Client 直接访问
5. 对于上述访问流程的控制，Route Table 的优先级高于 PAC
6. Ocserv 推送的 DNS 地址可以是公共 DNS 也可以是私有的
