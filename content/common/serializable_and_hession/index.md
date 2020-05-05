---
title: Serializable和Hession
date: 2019-12-07
categories: ["java","serialize"]
---

Serializable是Java提供的原生序列化方式，它提供了配套的ObjectOutputStream和ObjectIutputStream来处理Java对象的序列化读写，解析效率性能比较高，但是消耗的存储却捉襟见肘。很多框架中仅仅作为一个基础实现，但是基本无人使用。比如 Dubbo 框架中并不是使用它作为默认的序列化方式，而是使用hession。下面看看这两种序列化方式的优劣。

<!--more-->

### Serializable

Java原生支持，无需引入任何依赖。

```
DemoResponse demoResponse = InitializeUtils.initDemoResponse();

// 执行效率
ObjectOutputStream objectOutputStream = new ObjectOutputStream(new ByteArrayOutputStream());
long timeWatch = System.currentTimeMillis();
for (int i = 0; i < Constants.LOOP_SIZE; i++) {
	objectOutputStream.writeObject(demoResponse);
}
objectOutputStream.flush();
System.out.println(System.currentTimeMillis() - timeWatch);

// 存储空间
objectOutputStream = new ObjectOutputStream(new GZIPOutputStream(new FileOutputStream("native.txt")));
objectOutputStream.writeObject(demoResponse);
objectOutputStream.flush();
objectOutputStream.close();
```

针对DemoResponse下的data的列表元素数量设置不同的值，尝试对其进行序列化1万次，对比结果如下表

| DATA_SIZE | jackson | protobuf | serializable |
| --------- | ------- | -------- | ------------ |
| 10        | 260 ms  | 156 ms   | 47ms         |
| 50        | 330 ms  | 219 ms   | 47ms         |
| 100       | 527 ms  | 296 ms   | 47ms         |
| 200       | 744 ms  | 437 ms   | 47ms         |
| 300       | 1109 ms | 562 ms   | 47ms         |

单个对象的增大对其影响并不是很大，解析效率比较稳定。而其单次序列化出的对象大小是4KB，大约是JSON序列化的4倍多。

#### Hession

hesssion具备了原生序列化的效率，又减少了序列化后的对象大小，经常被用于RPC框架之中。

```
<dependency>
	<groupId>com.caucho</groupId>
	<artifactId>hessian</artifactId>
	<version>4.0.63</version>
</dependency>
```

首先需要引入依赖，它可以直接使用原生对象直接进行序列化，无需依赖其他插件或者生成对象。完全是运行时行为。使用同样的数据进行测试，代码如下：

```
DemoResponse demoResponse = InitializeUtils.initDemoResponse();

// 执行效率
HessianOutput hessianOutput = new HessianOutput(new ByteArrayOutputStream());
long timeWatch = System.currentTimeMillis();
for (int i = 0; i < Constants.LOOP_SIZE; i++) {
	hessianOutput.writeObject(demoResponse);
}
System.out.println(System.currentTimeMillis() - timeWatch);
// 存储空间
hessianOutput = new HessianOutput(new GZIPOutputStream(new FileOutputStream("hession.txt")));
hessianOutput.writeObject(demoResponse);
hessianOutput.flush();
hessianOutput.close();
```

针对DemoResponse下的data的列表元素数量设置不同的值，尝试对其进行序列化1万次，对比结果如下表

| DATA_SIZE | jackson | protobuf | hession |
| --------- | ------- | -------- | ------- |
| 10        | 260 ms  | 156 ms   | 15ms    |
| 50        | 330 ms  | 219 ms   | 16ms    |
| 100       | 527 ms  | 296 ms   | 16ms    |
| 200       | 744 ms  | 437 ms   | 16ms    |
| 300       | 1109 ms | 562 ms   | 18ms    |

其解析效率比serializable好一些，同时其序列化后的对象大小也比serializable的4KB小很多，为1KB。

serializable和hession的解析效率虽然非常高效，但是其序列化后对象的大小相较于protobuf等其他序列化方式却大的比较多。