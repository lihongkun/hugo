---
title: SHELL命令分组统计
date: 2020-09-06
categories: ["linux","shell"]
---

> 从一个访问日志中，找出访问最多的IP所有访问的URL列表。

这是一个真实的面试题，目的在考察SEHLL基础的使用。对于这个日志所需要关注的信息只有IP和URL。

<!--more-->

```
127.0.0.1  /user/add 
127.0.0.3  /user/add
127.0.0.2  /user/add
127.0.0.2  /user/update
127.0.0.2  /user/delete
```

首先需要找出访问最多的IP,awk可以对文本进行分割

```
awk '{print $1}' access.log
127.0.0.1
127.0.0.3
127.0.0.2
127.0.0.2
127.0.0.2
```

排序和去重统计

```
awk '{print $1}' access.log |sort|uniq -c      
1 127.0.0.1      
3 127.0.0.2      
1 127.0.0.3
```

此时需要从中选出统计值最大的IP，把整个列表按降序排序，然后取其中第一个。

```
awk '{print $1}' access.log |sort|uniq -c |sort -nr      
3 127.0.0.2      
1 127.0.0.3      
1 127.0.0.1
```

取出后，再次用awk进行，分割。

```
awk '{print $1}' access.log |sort|uniq -c |sort -nr |head -1|awk '{print $2}'
127.0.0.2
```

如此访问最大的IP则出来了，再次使用grep则可以找出它所访问的列表。

**【扩展】**

简单的次数统计思路可以使用 sort 和 uniq来做，awk的功能其实更强大。

```
 awk '{ s[$1]++;} END { max=0;ip="";for(i in s) { if(max <= s[i]) ip=i ;} print ip}' access.log
```

首先进行分组统计，END后进行循环找出其中次数最多的IP。一个命令直接搞定。

这里是单个次数的相加，如果有需要进行日志中进行数值的分组统计，也是可以的。

```
127.0.0.1  10
127.0.0.3  20
127.0.0.2  1
127.0.0.2  2
127.0.0.2  2
```

对IP后的值进行统计相加则是

```
 $ awk '{ s[$1]+=$2;} END { for(i in s) { print i" "s[i] }}' sum.log
 127.0.0.1 10
 127.0.0.2 5
 127.0.0.3 20
```

很多时候Excel透视图不熟悉，顺手就用SHELL搞定了。




  