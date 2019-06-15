---
title: Springboot的embeded tomcat目录
date: 2018-03-08
categories: ["springframework","troubleshooting"]
---

Springboot官方使用web的配置内嵌了tomcat , 其目录在正式环境下存在着诸多问题.<!--more-->

```

// pom.xml
 <parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>1.5.10.RELEASE</version>
</parent>

<!-- Add typical dependencies for a web application -->
<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
</dependencies>

// 主类

package hello;

import org.springframework.boot.*;
import org.springframework.boot.autoconfigure.*;
import org.springframework.stereotype.*;
import org.springframework.web.bind.annotation.*;

@Controller
@EnableAutoConfiguration
public class SampleController {

    @RequestMapping("/")
    @ResponseBody
    String home() {
        return "Hello World!";
    }

    public static void main(String[] args) throws Exception {
        SpringApplication.run(SampleController.class, args);
    }
}

```

极其简洁,无需部署到容器里面默认使用了内嵌型的tomcat8 ,相信很多人也是这么直接使用的.官方给的最佳实践有时候未必适合自己

### 问题描述

按照官方例子,未进行修改启动后在/tmp目录下生成了 [tomcat-随机数-线程号] 和 [tomcat-docbase-随机数-线程号] 的文件夹. 随着线上的服务发布重启,不断新创建目录.然而目录却是空的 看着甚是碍眼.有一天线上有些上传文件的业务全部抛出找不到文件的异常.重启后恢复正常.


于是复盘,发现临时文件被人删除.关注下这两个文件夹到底是做什么的.springboot使用的是embeded版本的tomcat 对比下独立版本的tomcat 少了一些配置目录还有 work 以及 webapp 目录. 其中

- work目录是运行时临时文件存储的地方,比如上传文件的临时目录,或者后端脚本编译缓存. 

- webapp 即 静态文件或者后端脚本存储的地方. 由于我们是动静分离,其实webapp是没有用到的.

那么这2个目录如果修改位置呢.官方只提供了work的配置.


```
// work 目录创建到 程序运行目录去
// 在启动目录下生成一个work目录
// [tomcat-随机数-线程号]

server.baseDir=./

```

### 探索

既然没有暴露出配置,那么只能从源码里面找相关的线索


```

// TomcatEmbeddedServletContainerFactory.java

public EmbeddedServletContainer getEmbeddedServletContainer(
			ServletContextInitializer... initializers) {
	Tomcat tomcat = new Tomcat();
	File baseDir = (this.baseDirectory != null ? this.baseDirectory
			: createTempDir("tomcat"));
	tomcat.setBaseDir(baseDir.getAbsolutePath());
	Connector connector = new Connector(this.protocol);
	tomcat.getService().addConnector(connector);
	customizeConnector(connector);
	tomcat.setConnector(connector);
	tomcat.getHost().setAutoDeploy(false);
	configureEngine(tomcat.getEngine());
	for (Connector additionalConnector : this.additionalTomcatConnectors) {
		tomcat.getService().addConnector(additionalConnector);
	}
	prepareContext(tomcat.getHost(), initializers);
	return getTomcatEmbeddedServletContainer(tomcat);
}

protected void  prepareContext(Host host, ServletContextInitializer[] initializers) {
	File docBase = getValidDocumentRoot();
	docBase = (docBase != null ? docBase : createTempDir("tomcat-docbase"));
	TomcatEmbeddedContext context = new TomcatEmbeddedContext();
	....
	context.setDocBase(docBase.getAbsolutePath());
	....
}

```

上述代码中的 baseDir 就是暴露了配置的 tomcat work目录,而 prepareContext里面的getValidDocumentRoot 就是 tomcat-docbase 目录 ,这个方法在它的父类AbstractEmbeddedServletContainerFactory中实现

```
// AbstractEmbeddedServletContainerFactory.java

private static final String[] COMMON_DOC_ROOTS = { "src/main/webapp", "public",
			"static" };

protected final File getValidDocumentRoot() {
	File file = getDocumentRoot();
	// If document root not explicitly set see if we are running from a war archive
	file = file != null ? file : getWarFileDocumentRoot();
	// If not a war archive maybe it is an exploded war
	file = file != null ? file : getExplodedWarFileDocumentRoot();
	// Or maybe there is a document root in a well-known location
	file = file != null ? file : getCommonDocumentRoot();
	....
	return file;
}
```
我们关注下这个DocumentRoot 的顺序是 getDocumentRoot>getWarFileDocumentRoot>getExplodedWarFileDocumentRoot>getCommonDocumentRoot.其中getDocumentRoot是TomcatEmbeddedServletContainerFactory setDocumentRoot设置进去的,也就是我们可以通过自己覆盖springboot的TomcatEmbeddedServletContainerFactory这个bean的实例化来实现


### 解决方案

于是声明一个TomcatEmbeddedServletContainerFactory这个bean的实例化来实现来覆盖springboot默认的参数配置

```
@Bean
public TomcatEmbeddedServletContainerFactory tomcatEmbeddedServletContainerFactory() {
	TomcatEmbeddedServletContainerFactory tomcatFactory = new TomcatEmbeddedServletContainerFactory();

	tomcatFactory.setBaseDirectory(baseDirectory);
	tomcatFactory.setDocumentRoot(documentRoot);
	
	return tomcatFactory;
}
```

至此目录问题完美解决