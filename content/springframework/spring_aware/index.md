---
title: Spring Aware机制
date: 2020-06-07
categories: ["springframework"]
---

在使用spring的过程中比较好的设计是bean不依赖于容器。在一些特殊的情况下需要感知容器的存在，使用容器的提供的资源。Spring IoC容器提供了Aware机制<!--more-->

#### Aware机制的作用

Aware：意识，发现的意思。它的作用即是让bean感知到容器的资源。早年版本的Spring容器如果需要ApplicationContext则经常使用如下代码去先存储其引用，在容器初始化后手动调用setApplicationContext把引用set进去。

```
public class ApplicationContextHolder {

    private static ApplicationContext applicationContext = null;

    public static void setApplicationContext(ApplicationContext applicationContext) {
        ApplicationContextHolder.applicationContext = applicationContext;
    }

    public static ApplicationContext getApplicationContext() {
        return applicationContext;
    }
}
```

如果是web场景下使用ContextLoaderListener来默认初始化容器，取得就有点困难。如果使用Spring的Aware机制则无需自己手动去获得容器的资源，而是Spring容器初始化bean后对其进行注入。上述例子可以修改为

```
@Component
public class ApplicationContextHolder implements ApplicationContextAware {

    private ApplicationContext applicationContext;

    @Override
    public void setApplicationContext(ApplicationContext applicationContext) throws BeansException {
        this.applicationContext = applicationContext;
    }

    public ApplicationContext getApplicationContext() {
        return applicationContext;
    }
}
```

ApplicationContextHolder的applicationContext不再是一个静态字段。当然并不希望到处去使用ApplicationContextHolder而是需要使用到ApplicationContext的时候bean自己去ApplicationContextAware。

#### 其它Aware接口

除了ApplicationContextAware，Spring容器还默认提供了一些常用的容器相关对象发现接口。

```
public class AwareBean implements ApplicationContextAware, 
        ApplicationEventPublisherAware, 
        BeanClassLoaderAware, 
        BeanFactoryAware, 
        MessageSourceAware, 
        BeanNameAware {


    @Override
    public void setApplicationEventPublisher(ApplicationEventPublisher applicationEventPublisher) {
		// 获得ApplicationEventPublisher，可使用来发布Spring容器事件
    }

    @Override
    public void setBeanClassLoader(ClassLoader classLoader) {
		// 动态bean初始化的时候使用和Spring容器一样的ClassLoader
    }

    @Override
    public void setBeanFactory(BeanFactory beanFactory) throws BeansException {
		// 获得 BeanFactory
    }

    @Override
    public void setBeanName(String beanName) {
		// 获得当前bean的名称
    }

    @Override
    public void setMessageSource(MessageSource messageSource) {
		// i18n和一些配置参数解析
    }

    @Override
    public void setApplicationContext(ApplicationContext applicationContext) throws BeansException {
		// 获得 ApplicationContext
    }
}
```

#### 小结

Spring容器提供了Aware机制，使Bean能够感知到容器的资源。此功能虽然是比较方便，但是使得Bean依赖于容器的API，这违背了依赖反转的初衷。因此，只有在一些需要对容器进行动态编程的基础bean才建议使用。