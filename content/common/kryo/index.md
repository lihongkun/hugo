---
title: Kryo序列化器
date: 2019-12-04
categories: ["java","serialize"]
---

Kryo是一个快速高效的java二进制对象图序列化框架。该项目的目标是高解析效率、高压缩率和易于使用的API。无论是文件、数据库还是网络上的对象，在需要持久化的场景中，该项目可以进入考虑的范围。

<!--more-->

#### 引入依赖

使用它需要引入对应的依赖，与avro、protobuf的序列化方式不同，它完全是运行时的，无需进行代码的生成，也就不需要去定义IDL文件以及引入对应的编译期插件

```
 <dependency>
	<groupId>com.esotericsoftware</groupId>
	<artifactId>kryo</artifactId>
	<version>5.0.0-RC4</version>
</dependency>
```

#### 效率和存储

由于它不需要生成特定的代码才能使用，可以直接使用POJO来进行序列化，则使用和以前JSON例子中同样的对象。

```
DemoResponse response = initDemoResponse();
//注册序列化对象
Kryo kryo = new Kryo();
kryo.register(DemoResponse.class);
kryo.register(DemoEntity.class);
kryo.register(ArrayList.class);
// 测试效率
Output output = new Output(new ByteArrayOutputStream());
long timeWatch = System.currentTimeMillis();
for (int i = 0; i < Constants.LOOP_SIZE; i++) {
	kryo.writeObject(output, response);
}
System.out.println(System.currentTimeMillis() - timeWatch);
// 测试存储
output = new Output(new GZIPOutputStream(new FileOutputStream("kryo.txt")));
for (int i = 0; i < Constants.LOOP_SIZE; i++) {
	kryo.writeObject(output, response);
}
output.flush();
output.close();
```

其中的Kryo对象并**不是线程安全**的，在多线程的环境中需要特别注意。在使用前需要把序列化需要用到的对象先注册到其中。

**效率** 针对DemoResponse下的data的列表元素数量设置不同的值，尝试对其进行序列化1万次，对比结果如下表

| DATA_SIZE | jackson | protobuf | kryo   |
| --------- | ------- | -------- | ------ |
| 10        | 260 ms  | 156 ms   | 172ms  |
| 50        | 330 ms  | 219 ms   | 437ms  |
| 100       | 527 ms  | 296 ms   | 516ms  |
| 200       | 744 ms  | 437 ms   | 765ms  |
| 300       | 1109 ms | 562 ms   | 1110ms |

**存储** DATA_SIZE=300时，使用Kryo序列化并且进行GZIP压缩，文件大小如下表

| JSON   | PROTOBUF | AVRO  | KRYO  |
| ------ | -------- | ----- | ----- |
| 2732KB | 405KB    | 280KB | 289KB |

