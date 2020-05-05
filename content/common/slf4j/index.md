---
title: Java日志门面系统
date: 2020-02-08
categories: ["java","log"]
---

一个线上程序的运行情况监测，日志扮演着极其重要的角色。Java发展了20年，日志系统也是百家争鸣，不同历史时期出现的开源组件往往有着不同的日志实现，应用的整合难度陡升。所幸Simple Logging Facade for Java（SLF4J）对各种日志框架进行了抽象。如其名字，它对开发者提供了统一的门面，允许开发者在部署时插入所需的日志框架。

<!--more-->

### 如何使用

使用它很简单，引入对应的依赖。

```
<dependency>
  <groupId>org.slf4j</groupId>
  <artifactId>slf4j-api</artifactId>
  <version>1.7.28</version>
</dependency>
```

然后获取对应的logger，即可进行日志操作。

```
package com.lihongkun.labs.slf4j;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class Application 
{
    public static void main( String[] args )
    {
        Logger logger = LoggerFactory.getLogger(Application.class);
        logger.info("Hello World");
    }
}
```

执行结果是

```
SLF4J: Failed to load class "org.slf4j.impl.StaticLoggerBinder".
SLF4J: Defaulting to no-operation (NOP) logger implementation
SLF4J: See http://www.slf4j.org/codes.html#StaticLoggerBinder for further details.
```

提示是没有绑定对应的日志框架实现， 也就是slf4j-api并不能单独使用。要正常打印日志需要对应的日志框架实现。我们先使用官方提供的简单实现。

```
<dependency>
  <groupId>org.slf4j</groupId>
  <artifactId>slf4j-simple</artifactId>
  <version>1.7.28</version>
</dependency>
```

引入后重新运行程序，正常输出日志。

```
[main] INFO com.lihongkun.labs.slf4j.Application - Hello World
```

### 选择实现

SLF4J需要选择一个日志框架的实现，并且也可以很容易去切换。

![](concrete-bindings.png)

官方提供了一张图形象表示了SLF4J日志实现框架的选择，如果没有选择或者使用了slf4j-nop 则不会输出任何的日志，所有日志行为都导向了/dev/null。同时官方也提供了一个简单的实现也就是上面例子提到的slf4j-simple。

SLF4J 作者在它的基础上还发起一个日志实现框架 logback项目，天生直接支持，只需要引入对应的包即可实现。

```
<dependency> 
  <groupId>ch.qos.logback</groupId>
  <artifactId>logback-classic</artifactId>
  <version>1.2.3</version>
</dependency>
```

其他的日志框架 如 log4j，jdk logging实现均需要通过一个适配层来转到，即图中的第三和第四列所表示的日志流向。多了一个Adaptation layer，除了引入实现包 ， 还需要引入适配的依赖。

```
<!-- slf4j 适配到 common logging -->
<dependency> 
  <groupId>org.slf4j</groupId>
  <artifactId>slf4j-jcl</artifactId>
  <version>x.y.z</version>
</dependency>

<!-- slf4j 适配到 log4j -->
<dependency> 
  <groupId>org.slf4j</groupId>
  <artifactId>slf4j-log4j12</artifactId>
  <version>x.y.z</version>
</dependency>


<!-- slf4j 适配到 jdk logging  -->
<dependency> 
  <groupId>org.slf4j</groupId>
  <artifactId>slf4j-jdk14</artifactId>
  <version>x.y.z</version>
</dependency>
```

### 桥接到SLF4J 

在选择完应用的日志实现框架以后，应用日志已经能正常使用了。但是早期的很多框架并不是直接使用SLF4J 来输出日志的，它们直接依赖于各种各样的日志框架，并非是你所选择的实现。那么此时这些组件或者框架在你应用中的行为所输出的日志并不会在你的日志中。所以需要把其他直接依赖于具体实现的日志给桥接到SLF4J 。所幸社区提供了一整套的方案。

![](legacy.png)

其中比较早期的日志API分别是 log4j ，common logging，jdk logging。上图分别演示了 当你SLF4J 选择logback、log4j 、jdk logging的时候如何去桥接。对应到单个API的化则是选择不同的依赖包即可。

```
<!-- common logging 桥接到slf4j -->
<dependency> 
  <groupId>org.slf4j</groupId>
  <artifactId>jcl-over-slf4j</artifactId>
  <version>x.y.z</version>
</dependency>

<!-- log4j 桥接到slf4j -->
<dependency> 
  <groupId>org.slf4j</groupId>
  <artifactId>log4j-over-slf4j</artifactId>
  <version>x.y.z</version>
</dependency>

<!-- jdk logging 桥接到slf4j -->
<dependency> 
  <groupId>org.slf4j</groupId>
  <artifactId>jul-to-slf4j</artifactId>
  <version>x.y.z</version>
</dependency>
```

如何桥接依赖于你选择的日志实现框架，图示画的非常清晰。

### 桥接死循环

桥接是一个比较好的特性， 但是用不好。可能就直接翻车了，比如下面的依赖引入。

```
<dependency> 
  <groupId>org.slf4j</groupId>
  <artifactId>log4j-over-slf4j</artifactId>
  <version>x.y.z</version>
</dependency>

<dependency> 
  <groupId>org.slf4j</groupId>
  <artifactId>slf4j-log4j12</artifactId>
  <version>x.y.z</version>
</dependency>
```

第一个是吧 log4j 的日志输出行为给转到SLF4J ，第二个是选择SLF4J 的日志实现为 log4j 。是不是有什么不对 ？两个行为是相互逆向的，这就成了死循环，日志直接不会打印。

结论是，slf4j-jdk14 和 jul-to-slf4j、slf4j-log4j12和log4j-over-slf4j、slf4j-jcl和jcl-over-slf4j 这三对内部两个之间不能同时存在。

