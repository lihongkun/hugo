---
title: Spring IoC 容器扩展
date: 2020-05-30
categories: ["springframework"]
---

托管给Spring IoC 容器的Bean虽然不知道容器的存在，但是容器也提供了完整的扩展点，让使用者动态干预bean的定义和实例化，生命周期相关的事件都有对应的hook。<!--more-->

### 生命周期事件

Bean实例化和销毁的时候，容器提供了默认的Hook，它们分别是InitializingBean和DisposableBean。实现后，容器将在bean实例化和销毁的时候进行调用。如果不实现这两个接口，同样可以使用该功能，那就是在配置对应的init-method和destroy-method。JSR-250定义了两个注解`@PostConstruct` and `@PreDestroy`同样是可以实现这样的功能。

```
package com.lihongkun.labs.spring.container.lifecycle;

import org.springframework.beans.factory.DisposableBean;
import org.springframework.beans.factory.InitializingBean;

import javax.annotation.PostConstruct;
import javax.annotation.PreDestroy;

public class LifeCycleBean implements InitializingBean, DisposableBean {

    private String propertyValue;

    public void setPropertyValue(String propertyValue) {
        this.propertyValue = propertyValue;
        System.out.println("[lifecycle event] setter inject");
    }

    public LifeCycleBean(){
        System.out.println("[lifecycle event] constructor");
    }

    @PostConstruct
    public void postConstruct(){
        System.out.println("[lifecycle event] PostConstruct");
    }

    @PreDestroy
    public void preDestroy(){
        System.out.println("[lifecycle event] PreDestroy");
    }

    public void initMethod(){
        System.out.println("[lifecycle event] initMethod");
    }

    public void destroyMethod(){
        System.out.println("[lifecycle event] destroyMethod");
    }

    @Override
    public void destroy() throws Exception {
        System.out.println("[lifecycle event] destroy");
    }

    @Override
    public void afterPropertiesSet() throws Exception {
        System.out.println("[lifecycle event] afterPropertiesSet");
    }
}
```

bean的配置

```
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:context="http://www.springframework.org/schema/context"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="http://www.springframework.org/schema/beans
        https://www.springframework.org/schema/beans/spring-beans.xsd
        http://www.springframework.org/schema/context
        https://www.springframework.org/schema/context/spring-context.xsd">
    <context:component-scan base-package="org.example"/>

    <bean id="lifeCycleBean"
          init-method="initMethod"
          destroy-method="destroyMethod"
          class="com.lihongkun.labs.spring.container.lifecycle.LifeCycleBean" >
        <property name="propertyValue" value="hello" />
    </bean>
</beans>
```

执行后的结果是

```
[lifecycle event] constructor
[lifecycle event] setter inject
[lifecycle event] PostConstruct
[lifecycle event] afterPropertiesSet
[lifecycle event] initMethod
[lifecycle event] PreDestroy
[lifecycle event] destroy
[lifecycle event] destroyMethod
```

可以看出执行顺序是 ： 构造函数 => 属性注入 => PostConstruct =>  InitializingBean => init-method配置 => PreDestroy => DisposableBean => destroy-method配置。 

InitializingBean 和 DisposableBean 的实现方式是和Spring容器耦合的。**推荐的是JSR-250的注解**，跟容器无关，切换其他容器的时候也是有对应的功能。如果不能使用的话，次优选择是init-method配置和destroy-method配置，保持类的干净，也是不耦合于容器。

### 容器扩展点

除了当个bean本身的事件，Spring容器提供了BeanPostProcessor和BeanFactoryPostProcessor两个容器级别的扩展点。它们被大量用在和Spring结合的一些基础框架上。

#### BeanPostProcessor

BeanPostProcessor 作用在实例化后的bean上，允许使用者在容器实例化bean的后，对其进行修改。它提供了两个方法，传入bean和beanName，返回处理后的bean。用法示例如下：

```
import org.springframework.beans.BeansException;
import org.springframework.beans.factory.config.BeanPostProcessor;

public class HelloBeanPostProcessor implements BeanPostProcessor {
    @Override
    public Object postProcessBeforeInitialization(Object bean, String beanName) throws BeansException {
        System.out.println("[lifecycle event] postProcessBeforeInitialization");
        return bean;
    }

    @Override
    public Object postProcessAfterInitialization(Object bean, String beanName) throws BeansException {
        System.out.println("[lifecycle event] postProcessAfterInitialization");
        return bean;
    }
}
```

通常应用于两种场景，**对实现了某个接口的bean进行填充或者该接口相关的操作**。Spring容器使用这个扩展点提供了一些特性。如postProcessBeforeInitialization实现了ApplicationContext相关的Aware机制。

```
class ApplicationContextAwareProcessor implements BeanPostProcessor {

	private final ConfigurableApplicationContext applicationContext;

	private final StringValueResolver embeddedValueResolver;


	/**
	 * Create a new ApplicationContextAwareProcessor for the given context.
	 */
	public ApplicationContextAwareProcessor(ConfigurableApplicationContext applicationContext) {
		this.applicationContext = applicationContext;
		this.embeddedValueResolver = new EmbeddedValueResolver(applicationContext.getBeanFactory());
	}


	@Override
	@Nullable
	public Object postProcessBeforeInitialization(final Object bean, String beanName) throws BeansException {
		AccessControlContext acc = null;

		if (System.getSecurityManager() != null &&
				(bean instanceof EnvironmentAware || bean instanceof EmbeddedValueResolverAware ||
						bean instanceof ResourceLoaderAware || bean instanceof ApplicationEventPublisherAware ||
						bean instanceof MessageSourceAware || bean instanceof ApplicationContextAware)) {
			acc = this.applicationContext.getBeanFactory().getAccessControlContext();
		}

		if (acc != null) {
			AccessController.doPrivileged((PrivilegedAction<Object>) () -> {
				invokeAwareInterfaces(bean);
				return null;
			}, acc);
		}
		else {
			invokeAwareInterfaces(bean);
		}

		return bean;
	}

	private void invokeAwareInterfaces(Object bean) {
		if (bean instanceof Aware) {
			if (bean instanceof EnvironmentAware) {
				((EnvironmentAware) bean).setEnvironment(this.applicationContext.getEnvironment());
			}
			if (bean instanceof EmbeddedValueResolverAware) {
				((EmbeddedValueResolverAware) bean).setEmbeddedValueResolver(this.embeddedValueResolver);
			}
			if (bean instanceof ResourceLoaderAware) {
				((ResourceLoaderAware) bean).setResourceLoader(this.applicationContext);
			}
			if (bean instanceof ApplicationEventPublisherAware) {
				((ApplicationEventPublisherAware) bean).setApplicationEventPublisher(this.applicationContext);
			}
			if (bean instanceof MessageSourceAware) {
				((MessageSourceAware) bean).setMessageSource(this.applicationContext);
			}
			if (bean instanceof ApplicationContextAware) {
				((ApplicationContextAware) bean).setApplicationContext(this.applicationContext);
			}
		}
	}

	@Override
	public Object postProcessAfterInitialization(Object bean, String beanName) {
		return bean;
	}

}
```

上述代码即是Spring容器使用了BeanPostProcessor实现了Aware机制里面的EnvironmentAware、EmbeddedValueResolverAware、ResourceLoaderAware、ApplicationEventPublisherAware、MessageSourceAware、ApplicationContextAware。

另外一种场景是**需要对实例化后的Bean进行代理包装**，postProcessAfterInitialization很容易想到可以直接把bean的实现给替换了，实际上Spring的AOP机制也是用此扩展来实现的。

#### BeanFactoryPostProcessor

BeanFactoryPostProcessor主要使用在修改容器的bean definition上面，它的阶段在更前面的环节，可以达到动态修改bean配置的能力。它只有一个postProcessBeanFactory方法，使用示例如下

```
import org.springframework.beans.BeansException;
import org.springframework.beans.factory.config.BeanFactoryPostProcessor;
import org.springframework.beans.factory.config.ConfigurableListableBeanFactory;

public class HelloBeanFactoryPostProcessor implements BeanFactoryPostProcessor {
    @Override
    public void postProcessBeanFactory(ConfigurableListableBeanFactory configurableListableBeanFactory) throws BeansException {
        System.out.println("[lifecycle event] postProcessBeanFactory");
    }
}
```

典型的应用即Spring容器中@Value("${property}")的实现。它是通过PropertyPlaceholderConfigurer类实现，继承自PropertyResourceConfigurer实现了BeanFactoryPostProcessor。

```
@Override
	public void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) throws BeansException {
		try {
			// 合并本地属性和外部指定的属性文件资源中的属性 
			Properties mergedProps = mergeProperties();

			// Convert the merged properties, if necessary.
			// 将属性的值做转换(仅在必要的时候做)
			convertProperties(mergedProps);

			// Let the subclass process the properties.
			// 对容器中的每个bean定义进行处理，也就是替换每个bean定义中的属性中的占位符 
			processProperties(beanFactory, mergedProps);
		}
		catch (IOException ex) {
			throw new BeanInitializationException("Could not load properties", ex);
		}
	}
```

### 小结

生命周期事件和容器级别的扩展点可以做一些资源初始化销毁、动态修改bean对象以及动态修改bean定义。它们以一定的顺序作用在bean上。以下结果是示例中所输出的顺序。

```
[lifecycle event] postProcessBeanFactory
[lifecycle event] constructor
[lifecycle event] setter inject
[lifecycle event] postProcessBeforeInitialization
[lifecycle event] PostConstruct
[lifecycle event] afterPropertiesSet
[lifecycle event] initMethod
[lifecycle event] postProcessAfterInitialization
[lifecycle event] PreDestroy
[lifecycle event] destroy
[lifecycle event] destroyMethod
```