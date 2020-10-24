---
title: Spring 单元测试
date: 2020-10-11
categories: ["springframework","unit test","mockito"]
---

单元测试对于一个开发来说是一个基本素养。Java这方面的工业标准是使用JUnit。在使用了Spring框架及其衍生的相关框架后，会有不同程度的变化。<!--more-->

最基础的用法即使用Spring容器的相关功能，即使这样也需要使用到Spring单元测试相关的支持。

```
<dependencies>
	<dependency>
		<groupId>junit</groupId>
		<artifactId>junit</artifactId>
		<version>4.13</version>
		<scope>test</scope>
	</dependency>
	<dependency>
		<groupId>org.springframework</groupId>
		<artifactId>spring-test</artifactId>
		<scope>test</scope>
	</dependency>
</dependencies>

<dependencyManagement>
	<dependencies>
		<dependency>
			<groupId>org.springframework</groupId>
			<artifactId>spring-framework-bom</artifactId>
			<version>5.2.6.RELEASE</version>
			<type>pom</type>
			<scope>import</scope>
		</dependency>
	</dependencies>
</dependencyManagement>
```

首先需要引入junit和Spring-test包。然后编写单元测试类。

```
@RunWith(SpringJUnit4ClassRunner.class)
@ContextConfiguration(locations = {"classpath:lifecycle.xml"})
public class LifeCycleTest {

    @Autowired
    private ApplicationContext applicationContext;

    @Test
    public void test(){
        applicationContext.getBean("lifeCycleBean");
    }
}
```

使用RunWith注解去指定单元测试使用SpringJUnit4ClassRunner来启动。ContextConfiguration注解指定了ApplicationContext的bean定义文件。其他的操作跟 JUnit 没什么区别了，实现单元测试方法，然后方法加上Test注解即可每个方法进行测试用例的执行。

#### Spring Boot 单元测试

越来越多的应用并不会直接裸用Spring进行开发，而是使用Spring Boot。对于单元测试，它也对其进行了一些简化。

```
<dependencies>
	<dependency>
		<groupId>org.springframework.boot</groupId>
		<artifactId>spring-boot-starter-web</artifactId>
	</dependency>
	<dependency>
		<groupId>org.springframework.boot</groupId>
		<artifactId>spring-boot-starter-test</artifactId>
		<scope>test</scope>
	</dependency>
	<dependency>
		<groupId>junit</groupId>
		<artifactId>junit</artifactId>
		<version>4.13</version>
		<scope>test</scope>
	</dependency>
</dependencies>
```

同样需要引入对应的依赖，分别是junit 和 spring-boot-starter-test ，这里要对Controller进行测试需要引入依赖和编写对应的代码。

```
//HelloController.java

@RestController
public class HelloController {

    @RequestMapping("/hello")
    public String hello(){
        return "hello mvc mock";
    }
}

//Application.java
@SpringBootApplication
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class,args);
    }
}
```

需要单元测试的代码如上，这是一个MVC的应用，需要使用到MvcMock。

```
@RunWith(SpringRunner.class)
@SpringBootTest
public class HelloControllerTest {

    @Autowired
    private WebApplicationContext context;

    private MockMvc mockMvc;

    @Before
    public void init() {
        mockMvc = MockMvcBuilders.webAppContextSetup(context).build();
    }

    @Test
    public void testHello() throws Exception {
        MvcResult mvcResult = mockMvc.perform(MockMvcRequestBuilders.get("/hello").content(""))
                .andExpect(MockMvcResultMatchers.status().isOk())
                .andDo(MockMvcResultHandlers.print())
                .andReturn();
        System.out.println(mvcResult.getResponse().getContentAsString());
    }
}
```

`SpringBootTest` 注解会直接找到对应的Spring Boot 启动类，在单元测试的时候进行启动。而MockMvc是直接通过网络对启动的应用程序进行模拟请求。MockMvcRequestBuilders可以很方便地进行参数或者HTTP协议相关的配置。

对于MvcMock可能会是否有必要学习和使用的疑问，比如在实际的生产过程中使用的OpenAPI，或者自己手动整理的CURL往往能够更加通用。但是单元测试是跟随着编译过程的，能够提早发现问题。他们在软件开发的不同生命周期中。

#### Mockito

很多应用并不是独立存在的，它需要跟外部进行交互。这样的应用单元测试如果要完完整整跑下来，则需要数据库、第三方接口。这些都是不确定的因素，比如第三方接口并不一定会如你的预期，或者数据库的脏数据等等。都可能导致你的单元测试崩溃。

最好的方式就是让你的单元测试程序跟外部依赖解耦。这时候就需要Mock了，在单元测试中如果遇到外部依赖，则给自己返回恰当的值。

引入依赖包

```
<dependency>
	<groupId>org.mockito</groupId>
	<artifactId>mockito-core</artifactId>
	<version>3.5.15</version>
	<scope>test</scope>
</dependency>
```

编写的测试代码如下

```
@RunWith(JUnit4.class)
public class MockitoTest {

    @Test
    public void test(){
        //You can mock concrete classes, not just interfaces
        LinkedList mockedList = mock(LinkedList.class);

        //stubbing
        when(mockedList.get(0)).thenReturn("first");
        when(mockedList.get(1)).thenThrow(new RuntimeException());

        //following prints "first"
        System.out.println(mockedList.get(0));

        //following prints "null" because get(999) was not stubbed
        System.out.println(mockedList.get(999));

        //following throws runtime exception
        System.out.println(mockedList.get(1));
    }
}
```

mock 用来包装一个返回，这里可以是一个接口的方法调用或者其他。上述是模拟返回一个LinkedList，并对其返回进行定义，然后进行测试。运行结果如下

```
first
null

java.lang.RuntimeException
	....
```

when...thenReturn  和 when...thenThrow 分别定义的mockList的行为，执行结果与定义的一致。

官方文档 http://www.javadoc.io/doc/org.mockito/mockito-core/2.8.47/org/mockito/Mockito.html