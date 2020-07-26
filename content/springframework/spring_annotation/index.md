---
title: Spring 注解配置
date: 2020-07-25
categories: ["springframework"]
---

Spring Bean 的注解配置功能出现的比较早，但是开始流行却是由于SpringBoot的推动。初期只是提供几个注解简化一些配置，使用context:annotation-config来启用。随着AnnotationApplicationContext的出现，注解逐渐丰富，慢慢形成了一种 Java Config的体系，从而摆脱了XML。<!--more-->

### 优缺点

相对于XML文件，注解型的配置依赖于通过字节码元数据装配组件，而非尖括号的声明。通过在相应的类，方法或属性上使用注解的方式，直接组件类中进行配置，而不是使用xml表述bean的装配关系。

早期比如Eclipse这样的工具，在Bean的包名发生了变化的时候并不能同步更新XML中的配置。需要人工去修改包名，往往繁琐且容易被忘记。Refactor功能在XML配置中使用不方便，而在Java代码中使用却是非常方便。

注解的配置方式大部分情况下是去中心化，使用者很难去掌控全局，一开始就对整体很熟悉。不过这种情况随着`@Configuration`注解的出现得到一定的改观，原理配置成XML都可以无缝修改成一个类使用`@Configuration`修饰。

### 实例化和装配

AnnotationApplicationContext 的与 ClassPathXmlApplicationContext最大的不同点就是它的配置都是通过Annotation，那么它是怎么做到的呢？启动的时候直接扫描指定包名下的所有类，看看他们是不是存在指定的注解，然后再把他们解析成Spring 认识的BeanDefinition。

| 注解        | 作用                                                         |
| ----------- | ------------------------------------------------------------ |
| @Component  | 泛指组件，Spring容器会扫描该注解，并为其生成一个托管到容器的Bean |
| @Service    | 功能同@Component，更有语义性，表示Service层的组件            |
| @Repository | 功能同@Component，表示Dao层的Bean                            |
| @Controller | 功能同@Component，表示Controller层的Bean                     |

上述的注解均是可以定义一个bean，采用自动扫描的方式。在类定义的时候同样把它定义为一个bean。

```
//xml 方式

// UserService.java
public class UserService {
	.....
}

// appliationContext.xml
<bean class="xxxx.UserService" />

// 等价的 注解配置
// UserService.java
@Service
public class UserService {
	.....
}
```

可以看到其实只是多了一个注解并不需要进行XML的配置。那么如果需要进行一些属性的注入呢？

这时候就需要一些装配Bean 的注解了。

| 注解       | 作用                                                         |
| ---------- | ------------------------------------------------------------ |
| @Autowired | 按类型装配Bean，默认情况下必须要求依赖对象必须存在。如果想要按名称装配需要配合@Qualifier注解 |
| @Qualifier | 表示要装配的Bean的名称，配合@Autowired                       |
| @Resource  | 按名称进行装配，等同于@Autowired + @Qualifier 一起的功能     |

使用的时候只需要用在属性或者的其中的Setter方法上面，不过Spring目前已经只推荐使用在Setter方法上。

```
// UserService.java
@Service
public class UserService {
	
	private UserMapper userMapper;
	
	@Autowired
	public void setUserMapper(UserMapper userMapper){
		this.userMapper = userMapper;
	}
}
```

### 编程式配置

在类实现上就地进行配置，用起来非常的方便。但是也会造成Bean定义非常的零散。如果需要有一些流程和顺序上的东西。要想知道全局总览性的视图。就会比较困难。大部分情况下，很多人喜欢使用XML和注解混合使用。如果你比较偏执，那么可以尝试下`@Configuration`和`@Bean`来配置出一个具备跟XML一致的流程性的类。

假设，我们有一个业务比较复杂使用责任链的方式进行实现。有十几二十个步骤。

```
@Component
@Order(20)
public class FirstHandler implement IHandler{
	....
}

@Component
@Order(19)
public class SecondHandler implement IHandler{
	....
}


// 省略其它类


@Component
@Order(1)
public class TwentiethHandler implement IHandler{
	....
}

@Component
public class HandlerChain {
	
	private List<IHandler> handlerList;
	
	@Autowired
	public void setHandlerList(List<IHandler> handlerList){
		this.handlerList = handlerList;
	}
}

```

如上述代码，如果全部使用注解也是可以实现的，但是handlerList的顺序对一个新接触系统的人是非常不友好的，因为没有一个地方可以告诉你，列表的顺序和所有的实现在哪里。我们可以换成`@Configuration`的方式，你可以认为它就是等同于一个配置文件。这里我们只需要修改HandlerChain的定义

```
@Configuration
public class HandlerChainConfiguration{
	
	@Autowired
	priavte FirstHandler firstHandler;
	
	@Autowired
	priavte FirstHandler secondHandler;
	
	...
	
	@Autowired
	priavte FirstHandler twentiethHandler;
	
	@Bean
	public HandlerChain handlerChain(){
		List<IHandler> handlerList = new ArrayList<>();
		handlerList.add(firstHandler);
		handlerList.add(secondHandler);
		...
		handlerList.add(twentiethHandler);
		HandlerChain handlerChain = new HandlerChain();
		handlerChain.setHandlerList(handlerList);
		return handlerChain;
	}
}
```

上述代码使用了`@Configuration`和`@Bean` 提供了一种可编程式的Bean定义，具备了很强的灵活性，它完全可以替代XML文件的方式。handlerChain的定义过程中所有的handler一览无余。

### 小结

`@Component` 等定义bean 的注解和`@Autowired`等装配bean的注解，相互配合可以解决任何场景下的bean配置。加上`@Configuration`和`@Bean` 提供的可编程式的定义，为开发者提供了很大的便利，开发者完全可以脱离XML。有了这些基础再加上Java 的SPI机制，Spring Boot Starter就水到渠成了。