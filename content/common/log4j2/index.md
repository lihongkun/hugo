---
title: Log4j2日志框架
date: 2020-05-03
categories: ["java","log"]
---

log4j2是一个比较新的日志框架，作为log4j的升级版本，修复了它的锁竞争问题提升了性能，提供了丰富的组件支持以及良好的语义配置。<!--more-->

### 如何使用

同样使用SLF4J来进行日志的门面，需要引入以下依赖。

```
<properties>
    <log4j2.version>2.13.1</log4j2.version>
</properties>

<dependencies>
    <dependency>
        <groupId>org.apache.logging.log4j</groupId>
        <artifactId>log4j-core</artifactId>
        <version>${log4j2.version}</version>
    </dependency>
    <dependency>
        <groupId>org.apache.logging.log4j</groupId>
        <artifactId>log4j-slf4j-impl</artifactId>
        <version>${log4j2.version}</version>
    </dependency>
</dependencies>
```

编写配置文件，log4j2的配置文件相对其他的日志框架层次比较分明。

```
<?xml version="1.0" encoding="UTF-8"?>
<Configuration status="INFO">
    <Appenders>
        <Console name="LogToConsole" target="SYSTEM_OUT">
            <PatternLayout pattern="%d{yyyy-MM-dd HH:mm:ss} [%level] [%thread] [%logger{15}] \: %m%n"/>
        </Console>
    </Appenders>
    <Loggers>
        <Root level="info">
            <AppenderRef ref="LogToConsole"/>
        </Root>
    </Loggers>
</Configuration>
```

**Appenders**标签包含了所有的日志输出目的地，每个Appender都包含在其中，如上述代码声明的Console也是比较具备语义性的。**Loggers**标签包含了所有的日志输出器，同样也是突出了语义性。

```
package com.lihongkun.labs.log4j2;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Hello world!
 */
public class Application {

    private static final Logger LOGGER = LoggerFactory.getLogger(Application.class);

    public static void main(String[] args) {
        LOGGER.info("Hello World");
    }
}

// 输出为
2020-04-25 16:33:45 [INFO] [main] [com.lihongkun.labs.log4j2.Application] : Hello World
```

### 组件

log4j2在组件上的概念和logback一样都是继承自log4j，基本上没有什么差别。最大的差别在于其中的扩展实现。除了一些常见的Appender，比如日志文件大小和日期滚动，JDBC，邮件等等。它还对一些开源日志采集或者存储中间件进行了比较多的支持如flume-ng、kafka、mongodb等等，官方原生支持使用起来不用费一些力气去扩展。更多丰富的功能可参考 http://logging.apache.org/log4j/2.x/manual/appenders.html

### 异步

log4j最大的诟病就是在多线程环境下，锁竞争激烈，严重拖慢了应用。而升级版的log4j2提供了两种异步日志的方式：

1. AsyncAppender。内部使用的一个队列（ArrayBlockingQueue）和一个后台线程，日志先存入队列，后台线程从队列中取出日志。阻塞队列容易受到锁竞争的影响，当更多线程同时记录时性能可能会变差。
2. AsyncLogger。内部使用的是LMAX Disruptor技术，Disruptor是一个无锁的线程间通信库，它不是一个队列，不需要排队，从而产生更高的吞吐量和更低的延迟。

#### **AsyncAppender** 

这个组件在logback和log4j2 都是存在的，对比下它们的性能。

使用同样的代码进行基准测试,并通过调整@Threads的值调整测试的线程数，来测试不同并发线程下他们的性能表现。

```
public static void main(String[] args) throws RunnerException {
	Options opt = new OptionsBuilder()
			.include(Log4j2Jmh.class.getSimpleName())
			.forks(1)
			.warmupIterations(1)
			.measurementIterations(5)
			.build();

	new Runner(opt).run();
}

@Benchmark
@Threads(32)
public void async(){
	LOGGER.info("hello world");
}
```

测试机器情况

- 64位 windows 10
- 8GB内存
- Intel(R) Core(TM) i7-4510U @2.00GHz 2.60GHz



logback的日志文件异步配置如下

```
<Configuration>
	<appender name="FILE" class="ch.qos.logback.core.FileAppender">
        <file>logback-lab.log</file>
        <encoder>
            <pattern>%d{HH:mm:ss.SSS} [%thread] [%-5level] [%logger{30}] - %msg%n</pattern>
        </encoder>
    </appender>
    <appender name="ASYNC_FILE" class="ch.qos.logback.classic.AsyncAppender">
        <appender-ref ref="FILE"/>
    </appender>
    <root level="INFO">
        <appender-ref ref="ASYNC_FILE" />
    </root>
</Configuration>
```

吞吐表现异步比同步高了一个数量级，数据如下

| 线程数 | FileAppender(ops/s) | AsyncAppender(ops/s) |
| ------ | ------------------- | -------------------- |
| 1      | 229,312             | 7,538,561            |
| 2      | 138,359             | 4,879,026            |
| 4      | 115,662             | 3,948,502            |
| 8      | 136,350             | 4,018,552            |
| 16     | 133,302             | 4,040,151            |
| 32     | 122,303             | 4,084,070            |

log4j2的异步日志配置文件如下，采用了同样的输出格式。

```
<?xml version="1.0" encoding="UTF-8"?>
<Configuration status="INFO">
    <Appenders>
        <File name="default" fileName="log4j2-lab.log">
            <PatternLayout pattern="%d{HH:mm:ss.SSS} [%thread] [%-5level] [%logger{30}] - %msg%n"/>
        </File>
        <Async name="defaultAsync">
            <AppenderRef ref="default"/>
        </Async>
    </Appenders>
    <Loggers>
        <Root level="info">
            <AppenderRef ref="defaultAsync"/>
        </Root>
    </Loggers>
</Configuration>
```

结果和官方的性能测试相悖，log4j2的异步比logback差距了一个数量级。

| 线程数 | log4j2(ops/s) | logback(ops/s) |
| ------ | ------------- | -------------- |
| 1      | 186,722       | 7,538,561      |
| 2      | 156,574       | 4,879,026      |
| 4      | 112,581       | 3,948,502      |
| 8      | 105,942       | 4,018,552      |
| 16     | 98,952        | 4,040,151      |
| 32     | 99,801        | 4,084,070      |

**AsyncLogger** 

它的开启方式有两种，一种是通过配置文件直接指定Logger是异步的，可以做到一部分异步，一部分是同步，相对灵活。比如官网是在做性能测试的时候是这么配置的，只有com.foo.Bar是异步的。

```
<?xml version="1.0" encoding="UTF-8"?>
 
<!-- No need to set system property "log4j2.contextSelector" to any value
     when using <asyncLogger> or <asyncRoot>. -->
 
<Configuration status="WARN">
  <Appenders>
    <!-- Async Loggers will auto-flush in batches, so switch off immediateFlush. -->
    <RandomAccessFile name="RandomAccessFile" fileName="asyncWithLocation.log"
              immediateFlush="false" append="false">
      <PatternLayout>
        <Pattern>%d %p %class{1.} [%t] %location %m %ex%n</Pattern>
      </PatternLayout>
    </RandomAccessFile>
  </Appenders>
  <Loggers>
    <!-- pattern layout actually uses location, so we need to include it -->
    <AsyncLogger name="com.foo.Bar" level="trace" includeLocation="true">
      <AppenderRef ref="RandomAccessFile"/>
    </AsyncLogger>
    <Root level="info" includeLocation="true">
      <AppenderRef ref="RandomAccessFile"/>
    </Root>
  </Loggers>
</Configuration>
```

另外一种是直接通过命令行选项开启全部logger异步，无需额外配置。

```
<!-- 使用jvm参数-Dlog4j2.contextSelector=org.apache.logging.log4j.core.async.AsyncLoggerContextSelector -->

<?xml version="1.0" encoding="UTF-8"?>
<Configuration status="INFO">
    <Appenders>
        <RandomAccessFile name="default" fileName="log4j2-lab.log" immediateFlush="false" append="false">
            <PatternLayout pattern="%d{HH:mm:ss.SSS} [%thread] [%-5level] [%logger{30}] - %msg%n"/>
        </RandomAccessFile>
    </Appenders>
    <Loggers>
        <Root level="info">
            <AppenderRef ref="default"/>
        </Root>
    </Loggers>
</Configuration>
```

无论是哪一种方式去开启AsyncLogger都需要引入 disruptor的依赖。

```
<dependency>
  <groupId>com.lmax</groupId>
  <artifactId>disruptor</artifactId>
  <version>3.4.2</version>
</dependency>
```

通过测试，吞吐的表现比log4j2 的 AsyncAppender 好很多但是和 logback的AsyncAppender相比还是差了一个数量级。

logback的性能数据和log4j2官方给出的相近，而log4j2的性能数据缺和官方给出的差距非常大。这点就让人很迷惑了。http://logging.apache.org/log4j/2.x/manual/async.html 这是官方对应同步和异步性能测试的参考数据。