---
title: 网络延时
date: 2019-01-14
categories: ["network"]
---

分布式系统中 , 网络是一个不稳定的存在.一些接口的调用通常存在不稳定或者是延时的问题.除了要做好监控外,这里介绍一下简单的快速定位命令.

<!--more-->

#### 概念

**域名解析延时** 与远程主机连接时需要将域名解析为IP地址.

**ping延时** 用来衡量主机对之间包括网络跳跃的网络延时.

**连接延时** 传输任何数据之前建立的网络连接所需要的时间,一般指三次握手的时间.

**首字节延时** 也称第一字节到达时间(TTFB),表示的是从连接建立到接收到第一个字节的时间.

### Ping

ping 是一个很常用的命令, 通常使用来测试两个主机之间的连通性.如下图

```
[vagrant@localhost ~]$ ping www.lihongkun.com
PING www.lihongkun.com (121.42.96.116) 56(84) bytes of data.
64 bytes from www.lihongkun.com (121.42.96.116): icmp_seq=1 ttl=50 time=42.6 ms
64 bytes from www.lihongkun.com (121.42.96.116): icmp_seq=2 ttl=50 time=47.1 ms
64 bytes from www.lihongkun.com (121.42.96.116): icmp_seq=3 ttl=50 time=48.0 ms
64 bytes from www.lihongkun.com (121.42.96.116): icmp_seq=4 ttl=50 time=42.0 ms
64 bytes from www.lihongkun.com (121.42.96.116): icmp_seq=5 ttl=50 time=52.9 ms
64 bytes from www.lihongkun.com (121.42.96.116): icmp_seq=6 ttl=50 time=41.7 ms
^C
--- www.lihongkun.com ping statistics ---
6 packets transmitted, 6 received, 0% packet loss, time 5389ms
rtt min/avg/max/mdev = 41.706/45.768/52.937/4.048 ms
```

一般情况下是不准确的.ICMP echo路由器处理的优先级会比较低,但是也可以简单看出来网络的稳定性和延时.

### CURL

curl命令经常使用来模拟请求,当然他也能使用来监测请求返回的各个阶段的指标 , 命令如下

```
[vagrant@localhost ~]$ curl -o /dev/null -s -w %{http_code}:%{content_type}:%{time_namelookup}:%{time_connect}:%{time_pretransfer}:%{time_starttransfer}:%{time_total}:%{speed_download} www.lihongkun.com
200:text/html; charset=UTF-8:0.012:0.065:0.065:0.317:0.470:38751.000
```

输出结果很难看 , -w 可以支持模板文件. 那么就创建一个模板文件 curl_format.txt

```
\n
                  http_code:  %{http_code}\n
               content_type:  %{content_type}\n
            time_namelookup:  %{time_namelookup}\n
               time_connect:  %{time_connect}\n
           time_pretransfer:  %{time_pretransfer}\n
         time_starttransfer:  %{time_starttransfer}\n
                            ----------\n
                 time_total:  %{time_total}\n
             speed_download:  %{speed_download}\n
\n
```

执行以下结果就好看多了

```
[vagrant@localhost ~]$ curl -o /dev/null -s -w "@curl_format.txt" www.lihongkun.com

                  http_code:  200
               content_type:  text/html; charset=UTF-8
            time_namelookup:  0.012
               time_connect:  0.062
           time_pretransfer:  0.062
         time_starttransfer:  0.310
                            ----------
                 time_total:  0.472
             speed_download:  38572.000
```

time_namelookup 为DNS延时 12 ms

time_connect 为连接延时 , 三次握手时间是 (62-12)ms

time_pretransfer 从请求开始到响应开始传输的时间

time_starttransfer 从请求开始到第一个字节将要传输的时间 , 首字节延迟

time_total : 请求花费的全部时间

其中的 (time_starttransfer - time_pretransfer) 基本上可以判定为服务器的处理响应时间



在一些特定的场景下,应用对延时的要求非常高,可以通过此命令来迅速定位下延时到底是物理上的原因还是应用处理时间达不到性能要求.比如 部署在 北京 A 应用 使用HTTP协议调用 外部应用B 设置了60 ms的超时时间, time_connect 是 30 ms , 服务器处理响应时间花了40 ms. 这样的数据基本上可以判断B应用是部署在南方.地域上的差距导致了30 ms , 迁移一下应用的部署地域 , 延时可以立竿见影地解决.





