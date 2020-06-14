---
title: Spring IoC 容器事件
date: 2020-06-13
categories: ["springframework"]
---

Spring容器除了提供Bean的生命周期扩展点，还需要提供容器的生命周期扩展点。容器不像bean一样是由开发者定义的。框架代码编写的时候并不知道谁会关心。所以Spring采用的方式是将容器的生命周期通过事件机制发布出来，关心事件的开发者自行订阅。这是一个观察者模式的典型应用。<!--more-->

#### 场景

看一个简单的场景。有动态配置A，当它发生变化的时候需要按配置重新组织一个责任链的顺序，如果配置错误则不生效，使用上一次的配置并且告警。

```
public class EhanceFilterChain implements ApplicationContextAware {
	
	private ApplicationContext applicationContext;
	
	public List<IFilter> filterList;
	
	/**
	 *	filter顺序的动态配置
	 **/
	@DynamicValue(key="ehance_filter_chain_filters")
	public String filterListConfig;
	
	/**
	 *	动态配置变化监听函数
	 **/
	@DynamicValueListerner(key="ehance_filter_chain_filters")
	public void orderFilterList(){
		// 动态配置变更，组织责任链。如果配置错误则告警
		List<IFilter> filterListNew = new ArrayList<IFilter>();
		try{
			for(...){
               filterListNew.add(applicationContext.getBean("filterBeanName"));
            }
            this.filterList = filterListNew;
		}
		catch(Exception ex){
			///  monitor alert
		}
		
	}
	
	@Override
    public void setApplicationContext(ApplicationContext applicationContext) throws BeansException {
        this.applicationContext = applicationContext;
    }
	
}
```

那么问题来了，如果配置错误，还没处理前，应用被重启，处理错误导致责任链为空，容器正常启动，服务正常暴露出去。在关键业务这种情况是不允许的。启动中如果解析错误则需要让服务停止对外暴露。那么应该如何判断容器是否是启动或者bean刷新呢 ？

#### 解决

Spring容器提供了容器的事件机制，能够监听容器的生命周期事件。只需要实现ApplicationListener接口。

```
public class EhanceFilterChain implements ApplicationListener<ContextRefreshedEvent> {
	// 省略其他
	@Override
    public void onApplicationEvent(ContextRefreshedEvent contextRefreshedEvent) {
        ApplicationContext context = contextRefreshedEvent.getApplicationContext();
        if(context.getParent() == null){
           List<IFilter> filterListNew = new ArrayList<IFilter>();
            try{
                for(...){
                   filterListNew.add(applicationContext.getBean("filterBeanName"));
                }
                this.filterList = filterListNew;
            }
            catch(Exception ex){
            	// 关闭服务
                context.close();
            }
        }
    }
}
```

#### 容器事件

Spring容器事件是一个典型的观察者模式，它提供了一种容器的扩展机制。内置的容器事件有`ContextRefreshedEvent` `ContextStartedEvent` `ContextStoppedEvent` `ContextClosedEvent`

分别对应着容器生命周期的 refresh、start、stop、和close方法。同时它还提供了开发者自定义事件的方法。

首先需要定义一个事件，继承自ApplicationEvent

```
public class BlackListEvent extends ApplicationEvent {

    private final String address;
    private final String content;

    public BlackListEvent(Object source, String address, String content) {
        super(source);
        this.address = address;
        this.content = content;
    }

    // accessor and other methods...
}
```

接着定义一个被观察者，它需要有一个ApplicationEventPublisher来发布事件，容器提供了一个接口ApplicationEventPublisherAware来注入ApplicationEventPublisher。而ApplicationEventPublisher使用publishEvent方法发布事件。

```
public class EmailService implements ApplicationEventPublisherAware {

    private List<String> blackList;
    private ApplicationEventPublisher publisher;

    public void setBlackList(List<String> blackList) {
        this.blackList = blackList;
    }

    public void setApplicationEventPublisher(ApplicationEventPublisher publisher) {
        this.publisher = publisher;
    }

    public void sendEmail(String address, String content) {
        if (blackList.contains(address)) {
            publisher.publishEvent(new BlackListEvent(this, address, content));
            return;
        }
        // send email...
    }
}
```

事件能够发布以后，就需要实现一个或者多个观察者。它们都需要实现ApplicationListener接口，在收到事件后进行对应的处理。

```
public class BlackListNotifier implements ApplicationListener<BlackListEvent> {

    private String notificationAddress;

    public void setNotificationAddress(String notificationAddress) {
        this.notificationAddress = notificationAddress;
    }

    public void onApplicationEvent(BlackListEvent event) {
        // notify appropriate parties via notificationAddress...
    }
}
```

其他的事情是由Spring容器代劳的，开发者只需要关心事件的发布和订阅。并且两种动作是可以解耦的。发布者并不知道订阅者的存在。

#### 缺点

容器事件可以做到代码的解耦，但是通知范围仅仅存在于容器内部，或者说是单进程内。它只能做代码级别的解耦。在分布式环境中用处并不大。分布式环境下的事件通知还是要使用消息队列中间件。