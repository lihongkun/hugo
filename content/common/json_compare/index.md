---
title: 常见JSON序列化库性能比较
date: 2019-08-18
categories: ["common","java"]
---

JSON（JavaScript Object Notation，JavaScript对象表示法，读作/ˈdʒeɪsən/）是一种由道格拉斯·克罗克福特构想和设计、轻量级的数据交换语言，该语言以易于让人阅读的文字为基础，用来传输由属性值或者序列性的值组成的数据对象。很多接口协议中都默认以它为序列化协议，如SpringCloud里面都是以HTTP+JSON的方式来提供服务。

<!--more-->

在一些接口性能要求高的场景下慎重地选择一个JSON序列化的库是比较必要。最近一次压测中，头部的CPU热点 数据发现，有6%的CPU时间发生在协议的JSON序列化上面，5%CPU时间花在某些必要字段的JSON构建上面。接口耗时跟JSON序列化强相关，显然如果通过选用更合适的序列化库来实现或者选用其他更高效的序列化协议，可以降低接口的时间。于是进行了下列实验。

待序列化的对象为DemoResponse

```
public class DemoEntity {

    private int id;

    private String name;

    private String category;

    private Long price;

    private Long appId;

    private Long ctr;
}

public class DemoResponse {

    private int code;

    private List<DemoEntity> data;
}

// 初始化数据
public DemoResponse initDemoResponse(){
	List<DemoEntity> data = new ArrayList<DemoEntity>();

	for (long index = 0; index < DATA_SIZE; index++) {
		DemoEntity entity = new DemoEntity();
		entity.setAppId(index);
		entity.setCategory(String.valueOf(index));
		entity.setCtr(index);
		entity.setId((int) index);
		entity.setName(String.valueOf(index));
		entity.setPrice(index);
		data.add(entity);
	}

	DemoResponse response = new DemoResponse();
	response.setCode((int) DATA_SIZE);
	response.setData(data);
}
```

分别使用fastjson，gson，jackson和裸写的序列方式来进行耗时的比较。首先需要引入对应的库，使用的都是比较新的版本。

```
<dependency>
	<groupId>com.google.code.gson</groupId>
	<artifactId>gson</artifactId>
	<version>2.8.5</version>
</dependency>
<dependency>
	<groupId>com.alibaba</groupId>
	<artifactId>fastjson</artifactId>
	<version>1.2.50</version>
</dependency>
<dependency>
	<groupId>com.fasterxml.jackson.core</groupId>
	<artifactId>jackson-databind</artifactId>
	<version>2.9.8</version>
</dependency>
```

分别对其进行LOOP_SIZE次的循环，然后输出序列化的总时间。

```
public class JsonTest {

    private static final long DATA_SIZE = 200;

    private static final int LOOP_SIZE = 10000;

    public static void main(String[] args) throws JsonProcessingException {

        DemoResponse response = initDemoResponse();

        long timeWatch = System.currentTimeMillis();
        for(int i=0;i<LOOP_SIZE;i++){
            JSON.toJSONString(response);
        }
        System.out.println("fastjson : "+(System.currentTimeMillis() - timeWatch));

        Gson gson = new Gson();

        timeWatch = System.currentTimeMillis();
        for(int i=0;i<LOOP_SIZE;i++){
            gson.toJson(response) ;
        }
        System.out.println("gson : "+(System.currentTimeMillis() - timeWatch));

        ObjectMapper objectMapper = new ObjectMapper();
        timeWatch = System.currentTimeMillis();
        for(int i=0;i<LOOP_SIZE;i++){
            objectMapper.writeValueAsString(response);
        }
        System.out.println("jackson : "+(System.currentTimeMillis() - timeWatch));

        timeWatch = System.currentTimeMillis();
        for(int i=0;i<LOOP_SIZE;i++){
            buildResponseJson(response) ;
        }
        System.out.println("raw : "+(System.currentTimeMillis() - timeWatch));
    }
}
```

LOOP_SIZE为1万的时候，实验值如下：

| DATA_SIZE | raw    | gson   | fastjson | jackson |
| --------- | ------ | ------ | -------- | ------- |
| 10        | 250ms  | 411ms  | 481ms    | 260ms   |
| 50        | 311ms  | 1264ms | 782ms    | 330ms   |
| 100       | 500ms  | 1735ms | 900ms    | 527ms   |
| 200       | 898ms  | 2700ms | 1468ms   | 744ms   |
| 300       | 1347ms | 3324ms | 1841ms   | 1109ms  |

从上面的数据可以很容易看出，gson是三个里面性能最差的一个，jackson表现跟裸写的接近。裸写的JSON序列化在数据量增大的时候性能表现就下降了，鉴于可维护性等方面的考虑，选用jackson还是比较合适。

