---
title: Springboot使用logback的坑点
date: 2018-03-01
categories: ["springframework","troubleshooting"]
---

尽管SpringBoot能够在application.properties来配置一些日志相关的内容,但是针对一个比较复杂,或者是有着自己运维体系的应用,这是远远不够用的.所以拓展自己的日志配置文件是必须的,官方推荐的是使用logback-spring.xml直接覆盖<!--more-->,那么参照源码里面的TestCase可能配置内容如下.


```
<configuration>
	<include resource="org/springframework/boot/logging/logback/base.xml" />

	<property name="LOG_PATH" value="XXX" />
	<property name="LOG_PATTEN" value="[%-5level] %date [%thread] [%logger{36}:%line] >>> %msg%n" />

	
	<appender name="FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
		<File>xxx.log</File>
		<rollingPolicy class="ch.qos.logback.core.rolling.TimeBasedRollingPolicy">
			<FileNamePattern>xxx.%d{yyyy-MM-dd}.log</FileNamePattern>
		</rollingPolicy>
		<encoder charset="UTF-8">
			<pattern>${LOG_PATTEN}</pattern>
		</encoder>
	</appender>
	
	<appender name="ERROR" class="xxx.basic.logger.appender.logback.HttpAppender">
		<url>http://xxx:8081/api/logSetting</url>
		<filter class="ch.qos.logback.classic.filter.LevelFilter">
			<level>ERROR</level>
			<OnMismatch>DENY</OnMismatch>
			<OnMatch>ACCEPT</OnMatch>
		</filter>
	</appender>

	<logger name="com.alibaba.druid" level="ERROR" />
	....

	<root>
		<level value="INFO" />
		<appender-ref ref="FILE" />
		<appender-ref ref="ERROR" />
	</root>
</configuration>
```

突然有一天线上磁盘告警,一般挂载到根目录下的磁盘是不会被业务直接使用的所以比较小.于是找到是tmp目录下有个很奇葩的spring.log.4接近30G .看日志内容是某个业务放量,打开了一个日志开关.于是对该应用日志配置文件进行排查.确定没有该日志文件的直接配置.于是转向了框架默认.

查看了一下上面所述的配置文件所引用的内容.发现base.xml默认也是声明了一些log行为.


```

base.xml

<included>
	<include resource="org/springframework/boot/logging/logback/defaults.xml" />
	<property name="LOG_FILE" value="${LOG_FILE:-${LOG_PATH:-${LOG_TEMP:-${java.io.tmpdir:-/tmp}}}/spring.log}"/>
	<include resource="org/springframework/boot/logging/logback/console-appender.xml" />
	<include resource="org/springframework/boot/logging/logback/file-appender.xml" />
	<root level="INFO">
		<appender-ref ref="CONSOLE" />
		<appender-ref ref="FILE" />
	</root>
</included>

file-appender.xml

<included>
	<appender name="FILE"
		class="ch.qos.logback.core.rolling.RollingFileAppender">
		<encoder>
			<pattern>${FILE_LOG_PATTERN}</pattern>
		</encoder>
		<file>${LOG_FILE}</file>
		<rollingPolicy class="ch.qos.logback.core.rolling.FixedWindowRollingPolicy">
			<fileNamePattern>${LOG_FILE}.%i</fileNamePattern>
		</rollingPolicy>
		<triggeringPolicy
			class="ch.qos.logback.core.rolling.SizeBasedTriggeringPolicy">
			<MaxFileSize>10MB</MaxFileSize>
		</triggeringPolicy>
	</appender>
</included>

```
虽然我们include了上述的文件也通用声明了name为FILE的appender,但是没有被重新定义.于是只能去掉.但是没有这个base.xml关于SpringBoot的相关的启动信息和运行时的其他信息便不会输出.于是看下了base.xml 所包含的另一个文件.


```
<!--
Default logback configuration provided for import, equivalent to the programmatic
initialization performed by Boot
-->

<included>
	<conversionRule conversionWord="clr" converterClass="org.springframework.boot.logging.logback.ColorConverter" />
	<conversionRule conversionWord="wex" converterClass="org.springframework.boot.logging.logback.WhitespaceThrowableProxyConverter" />
	<conversionRule conversionWord="wEx" converterClass="org.springframework.boot.logging.logback.ExtendedWhitespaceThrowableProxyConverter" />
	<property name="CONSOLE_LOG_PATTERN" value="${CONSOLE_LOG_PATTERN:-%clr(%d{yyyy-MM-dd HH:mm:ss.SSS}){faint} %clr(${LOG_LEVEL_PATTERN:-%5p}) %clr(${PID:- }){magenta} %clr(---){faint} %clr([%15.15t]){faint} %clr(%-40.40logger{39}){cyan} %clr(:){faint} %m%n${LOG_EXCEPTION_CONVERSION_WORD:-%wEx}}"/>
	<property name="FILE_LOG_PATTERN" value="%d{yyyy-MM-dd HH:mm:ss.SSS} ${LOG_LEVEL_PATTERN:-%5p} ${PID:- } --- [%t] %-40.40logger{39} : %m%n${LOG_EXCEPTION_CONVERSION_WORD:-%wEx}"/>

	<appender name="DEBUG_LEVEL_REMAPPER" class="org.springframework.boot.logging.logback.LevelRemappingAppender">
		<destinationLogger>org.springframework.boot</destinationLogger>
	</appender>

	<logger name="org.apache.catalina.startup.DigesterFactory" level="ERROR"/>
	<logger name="org.apache.catalina.util.LifecycleBase" level="ERROR"/>
	<logger name="org.apache.coyote.http11.Http11NioProtocol" level="WARN"/>
	<logger name="org.apache.sshd.common.util.SecurityUtils" level="WARN"/>
	<logger name="org.apache.tomcat.util.net.NioSelectorPool" level="WARN"/>
	<logger name="org.crsh.plugin" level="WARN"/>
	<logger name="org.crsh.ssh" level="WARN"/>
	<logger name="org.eclipse.jetty.util.component.AbstractLifeCycle" level="ERROR"/>
	<logger name="org.hibernate.validator.internal.util.Version" level="WARN"/>
	<logger name="org.springframework.boot.actuate.autoconfigure.CrshAutoConfiguration" level="WARN"/>
	<logger name="org.springframework.boot.actuate.endpoint.jmx" additivity="false">
		<appender-ref ref="DEBUG_LEVEL_REMAPPER"/>
	</logger>
	<logger name="org.thymeleaf" additivity="false">
		<appender-ref ref="DEBUG_LEVEL_REMAPPER"/>
	</logger>
</included>
```

它定义的是SpringBoot的默认logger.于是文章开头的logback-spring.xml便修改为


```
<configuration>
	<include resource="org/springframework/boot/logging/logback/defaults.xml" />
	....
</configuration>
```

/tmp/spring.log.*的文件便不会再有日志输出.使用命令 【 >spring.log.4 】把文件内容置成空.然后再删除掉,问题解决.