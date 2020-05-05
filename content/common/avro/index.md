---
title: Avro序列化器
date: 2019-12-01
categories: [java","serialize"]
---

Apache Avro（以下简称 Avro）是一种与编程语言无关的序列化格式。Avro 数据通过与语言无关的 schema 来定义。schema 通过 JSON 来描述，数据被序列化成二进制文件或 JSON 文件，不过一般会使用二进制文件。在大数据体系下，比较注重存储的压缩率，反而对效率并没有要求得很苛刻。

<!--more-->

#### 引入依赖

同样的例子做一个实验，引入必要的依赖，maven和相关的插件如下：

```
<dependency>
	<groupId>org.apache.avro</groupId>
	<artifactId>avro</artifactId>
	<version>1.9.1</version>
</dependency>

<!-- avro plugin -->
<plugin>
	<groupId>org.apache.avro</groupId>
	<artifactId>avro-maven-plugin</artifactId>
	<version>1.9.1</version>
	<executions>
		<execution>
			<phase>generate-sources</phase>
			<goals>
				<goal>schema</goal>
			</goals>
			<configuration>
				<sourceDirectory>src/main/idl/avro/</sourceDirectory>
			</configuration>
		</execution>
	</executions>
</plugin>
```



#### 编写定义文件

编写对应的schema文件，放置于src/main/idl/avro/avro_demo.avsc,定义了一个response的返回对象。

```
{
  "namespace" : "com.lihongkun.serialize",
  "type": "record",
  "name": "AvroResponse",
  "fields": [
    {"name": "code", "type": "int"},
    {"name": "data", "type" :
        {
            "type" : "array",
            "items" : {
                "namespace" : "com.lihongkun.serialize",
                "type": "record",
                "name": "AvroEntity",
                "fields":[
                    {"name" : "id","type":"int"},
                    {"name" : "name","type":"string"},
                    {"name" : "category","type":"string"},
                    {"name" : "price","type":"long"},
                    {"name" : "appId","type":"long"},
                    {"name" : "ctr","type":"long"}
                ]
            }
        }
    }
  ]
}
```

使用maven compile则生成两个对象AvroEntity 和AvroResponse ，与avsc定义的record是一致的。

#### 测试执行效率和存储

测试代码如下

```
AvroResponse avroResponse = initProtoResponse();

DatumWriter<AvroResponse> recordDatumWriter = new SpecificDatumWriter<>(AvroResponse.class);
DataFileWriter<AvroResponse> dataFileWriter = new DataFileWriter<>(recordDatumWriter);
dataFileWriter.create(AvroResponse.getClassSchema(),new ByteArrayOutputStream());

long timeWatch = System.currentTimeMillis();
for (int i = 0; i < LOOP_SIZE; i++) {
	dataFileWriter.append(avroResponse);
}
System.out.println(System.currentTimeMillis() - timeWatch);

dataFileWriter = new DataFileWriter<>(recordDatumWriter);
dataFileWriter.create(AvroResponse.getClassSchema(),new GZIPOutputStream(new FileOutputStream("avro.txt")));
for (int i = 0; i < LOOP_SIZE; i++) {
	dataFileWriter.append(avroResponse);
}

dataFileWriter.flush();
dataFileWriter.close();
```

同样的对象序列化之后存储占用了大约281KB，而ProtoBuf是405KB，相比其多了124KB。在海量数据的情况下对存储空间的节省是很巨大的。而其序列化效率是介于ProtoBuf和Jackson之间。

