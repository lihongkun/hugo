---
title: thrift序列化协议
date: 2019-09-23
categories: ["java","serialize"]
---

Apache Thrift 脱胎于 Facebook ，是一种高效的、支持多种编程语言的远程服务调用的框架。它的序列化协议同样可用于通讯协议、数据存储等领域的语言无关、平台无关、可扩展的序列化结构数据格式。<!--more-->

#### 使用

以Java为例子，首先需要引入对应的依赖。

```
<dependency>
	<groupId>org.apache.thrift</groupId>
	<artifactId>libthrift</artifactId>
	<version>0.12.0</version>
</dependency>
```

官方提供了从thirft文件生成对应的实体类，实际开发中荐使用maven插件来进行编译期的代码生成，但是thirft的的插件并不像protobuf那样提供对应的下载，而是需要自己去下载，并且指定位置。pom文件引入对应插件。

```
<!-- thirft plugin -->
<plugin>
	<groupId>org.apache.thrift.tools</groupId>
	<artifactId>maven-thrift-plugin</artifactId>
	<version>0.1.11</version>
	<configuration>
		<thriftExecutable>./thrift-0.12.0.exe</thriftExecutable>
		<generator>java</generator>
	</configuration>
	<executions>
		<execution>
			<id>thrift-sources</id>
			<phase>generate-sources</phase>
			<goals>
				<goal>compile</goal>
			</goals>
		</execution>
	</executions>
</plugin>
```

下面我们定义一下要使用的类，与 [常见JSON序列化库性能比较](https://www.lihongkun.com/common/json_compare/)  的例子一致。src/main/thirft 下创建一个*.thirft的文件来定义消息体

```
namespace java com.lihongkun.serialize

struct ThriftEntity{
    1:i64 id;
    2:string name;
    3:string category;
    4:i64 price;
    5:i64 appId;
    6:i64 ctr;
}

struct ThriftResponse{
    1:i32 code;
    2:list<ThriftEntity> data;
}
```

使用它编译后生成的类使用如下：

```
private static ThriftResponse initProtoResponse() {
	List<ThriftEntity> data = new ArrayList<>();

	for (long index = 0; index < DATA_SIZE; index++) {
		ThriftEntity thriftEntity = new ThriftEntity();
		thriftEntity.setAppId(index);
		thriftEntity.setCategory(String.valueOf(index));
		thriftEntity.setCtr(index);
		thriftEntity.setId((int) index);
		thriftEntity.setName(String.valueOf(index));
		thriftEntity.setPrice(index);
		data.add(thriftEntity);
	}

	ThriftResponse  response = new ThriftResponse();
	response.setCode((int) DATA_SIZE);
	response.setData(data);

	return response;
}
```

对于序列化，它并不能直接转成二进制，而是需要thirft对应的辅助类TTransport和TBinaryProtocol来进行处理：

```
ByteArrayOutputStream out = new ByteArrayOutputStream();
TTransport transport = new TIOStreamTransport(out);
TBinaryProtocol protocol = new TBinaryProtocol(transport);

long timeWatch = System.currentTimeMillis();
for(int i=0;i<LOOP_SIZE;i++){
	response.write(protocol);
}
System.out.println(System.currentTimeMillis() - timeWatch);
```

#### 对比

同样从**效率**和**存储**来进行对比

##### 效率

还是以数据大小递增，循环1万次的例子

| DATA_SIZE | jackson | protobuf | thirft |
| --------- | ------- | -------- | ------ |
| 10        | 260 ms  | 156 ms   | 94ms   |
| 50        | 330 ms  | 219 ms   | 250ms  |
| 100       | 527 ms  | 296 ms   | 450ms  |
| 200       | 744 ms  | 437 ms   | 735ms  |
| 300       | 1109 ms | 562 ms   | 937ms  |

从上述数据可看出，随着数据量的增加thrift的效率其实跟json的差距在缩小。

##### 存储

```
GZIPOutputStream gzipOutputStream = new GZIPOutputStream(new FileOutputStream("thrift.txt"));
TTransport gzTransport = new TIOStreamTransport(gzipOutputStream);
TBinaryProtocol gzProtocol = new TBinaryProtocol(gzTransport);
for(int i=0;i<LOOP_SIZE;i++){
	response.write(gzProtocol);
}
gzipOutputStream.flush();
gzipOutputStream.close();
```

生成的文件是1966 KB，介于json 和 protobuf之间 ，json 是2737 KB ，protobuf 是405 KB。



**综上**，thirft的存储和序列化效率比json好，但是相比于protobuf还是有一定的差距。