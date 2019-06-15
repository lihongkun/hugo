---
title: 线程封闭与ThreadLocal
date: 2018-12-03
categories: ["concurrent"]
---
访问共享数据,通常需要使用同步来保证变量的并发安全性.避免同步的方式就是不共享数据,如果数据只有单线程访问则不需要同步.这叫做线程封闭.

线程封闭分为两种方式 

**栈封闭** 通常我们使用的局部变量,天然具备线程封闭性,它没有被其他地方访问,方法结束后即不可访问.

**ThreadLocal类** 它提供了get和set等方法,这些方法为每个使用变量的线程存储一份独立的副本.因此get总是返回由当前执行线程在调用set时设置的最新值.

<!--more-->

#### 使用示例

它的主要方法和功能如下 ;

```
protected T initialValue() ; // 初始化
public T get() ; // 获得当前线程下的ThreadLocal类存储的对象
public void set(T value); // 设置当前线程下ThreadLocal类存储的对象
public void remove(); // 删除当前线程下ThreadLocal类存储的对象
```

一般使用的时候可能会重写initialValue方法,来自定义的自己的初始化.

举个使用的例子,SimpleDateFormat不是线程安全的,如何封装可以使其具备线程安全性呢

```
public class ThreadLocalDateFormat {

	// 每个线程都 创建一个SimpleDateFormat来处理
	private ThreadLocal<SimpleDateFormat> formatter;
	
	public ThreadLocalDateFormat(final String pattern){
		formatter = new ThreadLocal<SimpleDateFormat>(){
			@Override
			protected SimpleDateFormat initialValue() {
				return new SimpleDateFormat(pattern);
			}
		};
	}
	
	public String format(Date date){
		SimpleDateFormat sdf = formatter.get();
		String res = sdf.format(date);
		formatter.remove();
	}
}
```

用法很简单,每次对ThreadLocal对象的操作,只影响当前线程.

#### 实现原理

看下其中主要方法的实现

```
public T get() {
	Thread t = Thread.currentThread();
	ThreadLocalMap map = getMap(t);
	if (map != null) {
		ThreadLocalMap.Entry e = map.getEntry(this);
		if (e != null) {
			@SuppressWarnings("unchecked")
			T result = (T)e.value;
			return result;
		}
	}
	return setInitialValue();
}

public void set(T value) {
	Thread t = Thread.currentThread();
	ThreadLocalMap map = getMap(t);
	if (map != null)
		map.set(this, value);
	else
		createMap(t, value);
}

public void remove() {
	ThreadLocalMap m = getMap(Thread.currentThread());
	if (m != null)
		m.remove(this);
}

ThreadLocalMap getMap(Thread t) {
	return t.threadLocals;
}
```

每个方法中都会以当前线程为参数取一个ThreadLocalMap , 这个ThreadLocalMap 即是真正存储ThreadLocal值的地方.它是Thread的一个成员变量.

```
static class ThreadLocalMap {

	static class Entry extends WeakReference<ThreadLocal<?>> {
		/** The value associated with this ThreadLocal. */
		Object value;

		Entry(ThreadLocal<?> k, Object v) {
			super(k);
			value = v;
		}
	}

	ThreadLocalMap(ThreadLocal<?> firstKey, Object firstValue) {
		table = new Entry[INITIAL_CAPACITY];
		int i = firstKey.threadLocalHashCode & (INITIAL_CAPACITY - 1);
		table[i] = new Entry(firstKey, firstValue);
		size = 1;
		setThreshold(INITIAL_CAPACITY);
	}
	
}
```

ThreadLocalMap的定义在Thread类里面.顾名思义它是一个专门实现的Map结构, 每个线程的ThreadLocal的对象存储在Entry对象里面 key 是 ThreadLocal的引用, value 是 当前ThreadLocal对应的变量值. 而存储它们的引用关系是 Thread -> ThreadLocalMap -> Entry , 所以ThreadLocal对象都是绑定在自己的线程,不存在公用的现象.

#### 注意事项

**ThreadLocal与线程池一起使用**

在使用线程池的时候,线程是只初始化一次的,容易造成ThreadLocal类也是只初始化一次.那么如果线程执行过程中它的值被改变,则会导致结果不一致.在这种场景下,可以在在每个任务执行结束后使用ThreadLocal的remove方法来删除当前线程的ThreadLocal值.这样在下一次get或者set的时候它将重新初始化.

**内存泄漏问题**

虽然其中的Entry是继承自WeakReference , 在构造的时候 ThreadLocalMap的时候,key是被包装成弱引用的,而value没有.所以在线程没有结束的时候强引用的value是一直不会被回收的.避免的方法也是在使用之后,调用remove方法来去掉value的引用,使它能够及时被垃圾回收.