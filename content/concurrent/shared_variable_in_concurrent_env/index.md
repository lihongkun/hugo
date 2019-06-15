---
title: 共享变量的并发安全性
date: 2018-08-15
categories: ["concurrent"]
---
线程通信模型大体可分为两种，共享变量和消息传递。虽然消息传递（Actor模型）是比较被推崇的，但是Java语言并不支持。所以在并发程序中我们必须要面对共享变量所带来的编程复杂度。
<!--more--> 
所谓共享变量，即一个类的静态域或者实例域。先看一个线程不安全的例子。


```
public static void main(String[] args) {
	
	final Counter counter = new Counter();
	
	ExecutorService es = Executors.newFixedThreadPool(5);
	for(int i=0;i<5;i++){
		es.execute(new Runnable() {
			@Override
			public void run() {
				for(int i=0;i<10000;i++)
					counter.incr();
			}
		});
	}
	
	es.shutdown();
	while(true){
		if(es.isTerminated())
			break;
	}
	
	System.out.println("final cnt : " + counter.cnt);
	
}

private static class Counter{
	
	public int cnt = 0;
	
	public void incr(){
		cnt++;
	}
}
```
5个线程分别对一个变量进行自增操作1w次，结果并非是5w而是少了很多。原因可以看下Java线程的内存模型，每个线程都有自己的本地栈缓存了counter的副本，修改了以后需要刷新到堆中其他线程才能感知到变化。这过程并非是原子的。深入的原理可以参考下 <<深入理解Java内存模型>> http://ifeve.com/java-memory-model-0/

这边只对比下解决的方式

### synchronized

最简单粗暴的方式就是同步原语，早期的Java提供的一种同步方式，在方法上面加上synchronized关键字或者方法块加上synchronized，这样做的话方法或者代码块保证了原子性，只有一个线程能同时访问。


```
// 修改后的方式
private static class Counter{
		
	private Object lock = new Object();
	
	public int cnt = 0;
	
	public void incr(){
		synchronized (lock) {
			cnt++;
		}
	}
}
```


### ReentrantLock

你也可以使用读写锁，当然这里只是很简单的用法。ReentrantLock可以使用在更高级的场景。在这个简单的自增例子中也是很简单粗暴，基本上体现不出它的优势。

```
private static class Counter{
		
	ReentrantLock lock = new ReentrantLock();
	
	public int cnt = 0;
	
	public void incr(){
		lock.lock();
		try{
			cnt++;
		}
		catch (Exception ex) {
			// TODO: handle exception
		}
		finally {
			lock.unlock();
		}
	}
}
```
### 原子类型

JDK 1.5 开始提供了 原子类型，可修改为


```
private static class Counter{
		
    public AtomicInteger cnt = new AtomicInteger(0);
    
    public void incr(){
    	cnt.incrementAndGet();
    }
}
```
原子类型很适合使用来做自增，统计等操作。而且与前面二者不同，使用的是无锁算法。

### volatile

volatile的语义是被它修饰的变量如果发生变更能立刻被其他线程所见。但是它并不适合自增的场景。


```
private static class Counter{
	
	public volatile int cnt = 0;
	
	public void incr(){
		cnt++;
	}
}
```
上面的代码是无法避免问题的，原因是它只能保证可见性，但是自增操作并不是原子性的操作。cnt++是先读取cnt的值然后执行加一并赋值的操作。

volatile的使用原则是可以被写入 volatile 变量的这些有效值独立于任何程序的状态，包括变量的当前状态。如下面shutdown方法并不依赖任何其他状态

```
volatile  boolean shutdownRequested;
 
...
 
public void shutdown() { shutdownRequested = true; }
 
public void doWork() { 
    while (!shutdownRequested) { 
        // do something
    }
}
```



#### 小结

Java的线程通信模型使用的是共享变量，处理共享变量的同步问题不一定都是需要使用synchronized这种开销比较大的，并发度比较低的方式，可以选的方式还有volatile，lock或者原子类型
