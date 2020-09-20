---
title: Spring Boot Actuators
date: 2020-09-20
categories: ["springframework","springboot"]
---

Spring Boot 提供了开箱即用的应用监控功能，对于大厂来说可能比较鸡肋，但是对于一些没有基础建设团队的中小公司是非常好用的。<!--more-->

使用的时候直接引入对应的包 ，主要是 spring-boot-starter-actuator

```
<dependencies>
	<dependency>
		<groupId>org.springframework.boot</groupId>
		<artifactId>spring-boot-starter-actuator</artifactId>
	</dependency>
	<dependency>
		<groupId>org.springframework.boot</groupId>
		<artifactId>spring-boot-starter-web</artifactId>
	</dependency>
</dependencies>

<dependencyManagement>
	<dependencies>
		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-dependencies</artifactId>
			<version>2.1.3.RELEASE</version>
			<type>pom</type>
			<scope>import</scope>
		</dependency>
	</dependencies>
</dependencyManagement>
```

启动应用程序后，可以使用对应的URI去访问指定的监控内容。

```
http://domain/actuator

{
    "_links":{
        "self":{
            "href":"http://localhost:8080/actuator",
            "templated":false
        },
        "health-component-instance":{
            "href":"http://localhost:8080/actuator/health/{component}/{instance}",
            "templated":true
        },
        "health":{
            "href":"http://localhost:8080/actuator/health",
            "templated":false
        },
        "health-component":{
            "href":"http://localhost:8080/actuator/health/{component}",
            "templated":true
        },
        "info":{
            "href":"http://localhost:8080/actuator/info",
            "templated":false
        }
    }
}
```

因为里面的内容有应用的敏感信息默认开启的endpoint是health和info，如果需要开启更多的内容，进行配置。

```
// application.properties
management.endpoints.web.exposure.include=*
```

上面我们配置开启了所有的功能，可以继续从/actuator看出开启的endpoint

```
{
    "_links":{
        "self":{
            "href":"http://localhost:8080/actuator",
            "templated":false
        },
        "auditevents":{
            "href":"http://localhost:8080/actuator/auditevents",
            "templated":false
        },
        "beans":{
            "href":"http://localhost:8080/actuator/beans",
            "templated":false
        },
        "caches-cache":{
            "href":"http://localhost:8080/actuator/caches/{cache}",
            "templated":true
        },
        "caches":{
            "href":"http://localhost:8080/actuator/caches",
            "templated":false
        },
        "health-component-instance":{
            "href":"http://localhost:8080/actuator/health/{component}/{instance}",
            "templated":true
        },
        "health-component":{
            "href":"http://localhost:8080/actuator/health/{component}",
            "templated":true
        },
        "health":{
            "href":"http://localhost:8080/actuator/health",
            "templated":false
        },
        "conditions":{
            "href":"http://localhost:8080/actuator/conditions",
            "templated":false
        },
        "configprops":{
            "href":"http://localhost:8080/actuator/configprops",
            "templated":false
        },
        "env":{
            "href":"http://localhost:8080/actuator/env",
            "templated":false
        },
        "env-toMatch":{
            "href":"http://localhost:8080/actuator/env/{toMatch}",
            "templated":true
        },
        "info":{
            "href":"http://localhost:8080/actuator/info",
            "templated":false
        },
        "loggers":{
            "href":"http://localhost:8080/actuator/loggers",
            "templated":false
        },
        "loggers-name":{
            "href":"http://localhost:8080/actuator/loggers/{name}",
            "templated":true
        },
        "heapdump":{
            "href":"http://localhost:8080/actuator/heapdump",
            "templated":false
        },
        "threaddump":{
            "href":"http://localhost:8080/actuator/threaddump",
            "templated":false
        },
        "metrics-requiredMetricName":{
            "href":"http://localhost:8080/actuator/metrics/{requiredMetricName}",
            "templated":true
        },
        "metrics":{
            "href":"http://localhost:8080/actuator/metrics",
            "templated":false
        },
        "scheduledtasks":{
            "href":"http://localhost:8080/actuator/scheduledtasks",
            "templated":false
        },
        "httptrace":{
            "href":"http://localhost:8080/actuator/httptrace",
            "templated":false
        },
        "mappings":{
            "href":"http://localhost:8080/actuator/mappings",
            "templated":false
        }
    }
}
```

从上面可以找出不少比较有用的信息线程栈或者堆信息，在线上需要使用启动应用的用户来进行导出，一般是运维同学才有权限，但是这种日常的操作使用管理后台的功能来导出是非常方便的。

| Endpoint             | 功能                                                   |
| -------------------- | ------------------------------------------------------ |
| /actuator/mappings   | @RequestMapping 定义的HTTP Endpoint的信息              |
| /actuator/threaddump | 当前的线程栈信息                                       |
| /actuator/heapdump   | 当前堆信息                                             |
| /actuator/beans      | 应用实例化的bean的信息                                 |
| /actuator/caches     | 应用的cache相关信息，使用到了Spring CacheManager的组件 |
| /actuator/conditions | SpringBoot 各类@OnCondition 注解的执行情况             |

上面几个工具更加倾向于问题的定位，而Spring Boot 2.x后加入的 /actuator/metrics 则是使用了 micrometer进行相关的指标采集，很多开源的监控软件，比如普罗米修斯，可以很容易将其作为数据源对指标进行摄入。

```
{
    "names":[
        "jvm.threads.states",
        "jvm.gc.pause",
        "http.server.requests",
        "jvm.memory.used",
        "jvm.gc.memory.promoted",
        "jvm.memory.max",
        "jvm.gc.max.data.size",
        "jvm.memory.committed",
        "system.cpu.count",
        "logback.events",
        "tomcat.global.sent",
        "jvm.buffer.memory.used",
        "tomcat.sessions.created",
        "jvm.threads.daemon",
        "system.cpu.usage",
        "jvm.gc.memory.allocated",
        "tomcat.global.request.max",
        "tomcat.global.request",
        "tomcat.sessions.expired",
        "jvm.threads.live",
        "jvm.threads.peak",
        "tomcat.global.received",
        "process.uptime",
        "tomcat.sessions.rejected",
        "process.cpu.usage",
        "tomcat.threads.config.max",
        "jvm.classes.loaded",
        "jvm.classes.unloaded",
        "tomcat.global.error",
        "tomcat.sessions.active.current",
        "tomcat.sessions.alive.max",
        "jvm.gc.live.data.size",
        "tomcat.threads.current",
        "jvm.buffer.count",
        "jvm.buffer.total.capacity",
        "tomcat.sessions.active.max",
        "tomcat.threads.busy",
        "process.start.time"
    ]
}
```

/actuator/metrics 所采集的指标如上所示，可以根据上面的单个进行采集。比如其中的/actuator/metrics/jvm.memory.used 表示JVM的内存的使用情况。访问后返回的结果是

```
{
    "name":"jvm.memory.used",
    "description":"The amount of used memory",
    "baseUnit":"bytes",
    "measurements":[
        {
            "statistic":"VALUE",
            "value":95404360
        }
    ],
    "availableTags":[
        {
            "tag":"area",
            "values":[
                "heap",
                "nonheap"
            ]
        },
        {
            "tag":"id",
            "values":[
                "CodeHeap 'profiled nmethods'",
                "G1 Old Gen",
                "CodeHeap 'non-profiled nmethods'",
                "G1 Survivor Space",
                "Compressed Class Space",
                "Metaspace",
                "G1 Eden Space",
                "CodeHeap 'non-nmethods'"
            ]
        }
    ]
}
```

有了这些基础的功能，做一个集中式的监控系统就更加方便了。事实上，开源社区贡献的 spring-boot-admin 就是在此为基础上做了一个 管理平台。可以比较方便地使用上述功能。