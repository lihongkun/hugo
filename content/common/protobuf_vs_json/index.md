---
title: protobuf序列化协议
date: 2019-08-20
categories: ["common","java","serialize"]
---

Protocol Buffers 是一种轻便高效的结构化数据存储格式，可以用于结构化数据串行化，或者说序列化。它很适合做数据存储或 RPC 数据交换格式。可用于通讯协议、数据存储等领域的语言无关、平台无关、可扩展的序列化结构数据格式。<!--more-->

#### 使用

以Java为例子，首先需要引入对应的依赖。

```
<properties>
	<project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
	<maven.compiler.source>11</maven.compiler.source>
	<maven.compiler.target>11</maven.compiler.target>
	<protobuf.version>3.5.1</protobuf.version>
</properties>

<dependency>
	<groupId>com.google.protobuf</groupId>
	<artifactId>protobuf-java</artifactId>
	<version>${protobuf.version}</version>
</dependency>
<dependency>
	<groupId>com.google.protobuf</groupId>
	<artifactId>protobuf-java-util</artifactId>
	<version>${protobuf.version}</version>
</dependency>
```

官方提供了从proto文件生成对应的实体类，但是实际开发中并不推荐这么做。推荐使用maven插件来进行编译期的代码生成。pom文件引入对应插件。

```
<build>
	<extensions>
		<extension>
			<groupId>kr.motd.maven</groupId>
			<artifactId>os-maven-plugin</artifactId>
			<version>1.6.1</version>
		</extension>
	</extensions>
	<plugins>
		<plugin>
			<groupId>org.apache.maven.plugins</groupId>
			<artifactId>maven-compiler-plugin</artifactId>
			<configuration>
				<source>11</source>
				<target>11</target>
			</configuration>
		</plugin>
		<plugin>
			<groupId>org.xolstice.maven.plugins</groupId>
			<artifactId>protobuf-maven-plugin</artifactId>
			<version>0.6.1</version>
			<configuration>
				<protocArtifact>com.google.protobuf:protoc:${protobuf.version}:exe:${os.detected.classifier}</protocArtifact>
			</configuration>
			<executions>
				<execution>
					<goals>
						<goal>compile</goal>
						<goal>test-compile</goal>
					</goals>
				</execution>
			</executions>
		</plugin>
	</plugins>
</build>
```

protobuf-maven-plugin会根据对应操作系统下载对应的protobuf编译器。如window下面第一次运行编译会出现如下日志。

```
[INFO] --- protobuf-maven-plugin:0.6.1:compile (default) @ serialize ---
Downloading: https://repo.maven.apache.org/maven2/com/google/protobuf/protoc/3.5.1/protoc-3.5.1-windows-x86_64.exe
Downloaded: https://repo.maven.apache.org/maven2/com/google/protobuf/protoc/3.5.1/protoc-3.5.1-windows-x86_64.exe (5708 KB at 1215.8 KB/sec)
```

下面我们定义一下要使用的类，与 [常见JSON序列化库性能比较](https://www.lihongkun.com/common/json_compare/)  的例子一致。message来定义消息体也就是java的类

```
syntax = "proto3";

//生成文件所在包名
option java_package = "com.lihongkun.serialize";

message ProtoEntity{
    int64 id = 1;
    string name = 2;
    string category = 3;
    int64 price = 4;
    int64 appId = 5;
    int64 ctr = 6;
}

message ProtoResponse{
    int32 code = 1;
    // 列表结构
    repeated ProtoEntity data = 2;
}
```

编译后生成的类,创建都是使用builder的方式。使用如下：

```
private static ProtoDemo.ProtoResponse initProtoResponse() {
	List<ProtoDemo.ProtoEntity> data = new ArrayList<>();

	for (long index = 0; index < DATA_SIZE; index++) {
		ProtoDemo.ProtoEntity.Builder builder = ProtoDemo.ProtoEntity.newBuilder();
		builder.setAppId(index);
		builder.setCategory(String.valueOf(index));
		builder.setCtr(index);
		builder.setId((int) index);
		builder.setName(String.valueOf(index));
		builder.setPrice(index);
		data.add(builder.build());
	}

	ProtoDemo.ProtoResponse.Builder builder = ProtoDemo.ProtoResponse.newBuilder();
	builder.setCode((int) DATA_SIZE);
	builder.addAllData(data);

	return builder.build();
}
```

#### 对比JSON

讲到protobuf序列化通常会拿JSON来进行对比。主要分两方面，**效率**和**存储**

##### 效率

还是以数据大小递增，循环1万次的例子

| DATA_SIZE | jackson | protobuf |
| --------- | ------- | -------- |
| 10        | 260 ms  | 156 ms   |
| 50        | 330 ms  | 219 ms   |
| 100       | 527 ms  | 296 ms   |
| 200       | 744 ms  | 437 ms   |
| 300       | 1109 ms | 562 ms   |

从上述数据可看出，protobuf的效率大大高于JSON，接近一半的效率提升。

##### 存储

在HTTP传输或者一些序列化存储中并不会直接裸用。一般都会加上gzip压缩，所以也是以gzip压缩为例子。

```
// JSON
GZIPOutputStream gzipOutputStream = new GZIPOutputStream(new FileOutputStream("json.txt"));
for(int i=0;i<LOOP_SIZE;i++){
	gzipOutputStream.write(objectMapper.writeValueAsString(response).getBytes());
}
gzipOutputStream.flush();
gzipOutputStream.close();

//protobuf
GZIPOutputStream gzipOutputStream = new GZIPOutputStream(new FileOutputStream("proto.txt"));
for(int i=0;i<LOOP_SIZE;i++){
	gzipOutputStream.write(response.toByteArray());
}
gzipOutputStream.flush();
gzipOutputStream.close();
```

生成的文件JSON是2737 KB ，protobuf是405 KB，存在6倍多的差距。无论是从传输的带宽还是从存储的成本考虑，protobuf都是比较优秀的.

在RPC或者序列化存储的大部分场景下选取protobuf是比较合适的。

#### 何时使用JSON

1. 程序对可读性要求比较高
2. 服务提供的数据是浏览器直接使用的
3. 关联方是用JavaScript编写的
4. 你不想要把数据给预先绑定到固定的模式上面，也就是预定义和拓展性的需求。

可读性和无需预定义是JSON最大的一个优势