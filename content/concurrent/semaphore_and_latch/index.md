---
title: 同步工具类 - 信号量和闭锁
date: 2018-09-17
categories: ["concurrent"]
---
底层实现是AbstractQueuedSynchronizer的同步工具类有不少,先来聊聊信号量(Semaphore),闭锁(Latch)
<!--more-->

### 信号量

计数信号量是用来控制同时访问某个特定资源的**操作数量**,或者同时执行某个指定操作的数量.

主要提供的方法如下

```
//构造函数,指定许可数量还有是否是公平排队
public Semaphore(int permits);
public Semaphore(int permits, boolean fair);

// 获得许可,可以指定数量和是否可被中断
public void acquire() throws InterruptedException;
public void acquireUninterruptibly();
public void acquire(int permits) throws InterruptedException;
public void acquireUninterruptibly(int permits) ;

// 尝试获得许可,可指定数量,等待时间
public boolean tryAcquire() ;
public boolean tryAcquire(long timeout, TimeUnit unit)throws InterruptedException;
public boolean tryAcquire(int permits) 
public boolean tryAcquire(int permits, long timeout, TimeUnit unit)throws InterruptedException;

// 释放许可
public void release(int permits);

// 可用许可数量
public int availablePermits() ;

// 获取剩余的所有可用许可
public int drainPermits();

// 减少许可数量 - 构造后发现有些资源不可用
// 使用此函数减少数量
protected void reducePermits(int reduction);

// 等待队列
public final boolean hasQueuedThreads() ;
public final int getQueueLength();
protected Collection<Thread> getQueuedThreads();
```

它内部维护着一组许可,在执行某个指定操作时需要先获得许可(acquire),结束后释放许可(release).如果没有许可,那么acquire将阻塞,直到有许可或者中断、超时.如此可以达到控制并发访问量的目的。

它可以用来实现资源池,或者对容器实现边界.二值许可的信号量可以当做互斥体(显式锁)来使用.

```
public class Pool {
	private static final int MAX_AVAILABLE = 100;
	private final Semaphore available = new Semaphore(MAX_AVAILABLE, true);

	public Object getItem() throws InterruptedException {
		available.acquire();
		return getNextAvailableItem();
	}

	public void putItem(Object x) {
		if (markAsUnused(x))
			available.release();
	}

	// Not a particularly efficient data structure; just for demo
	protected Object[] items = new Object[MAX_AVAILABLE]; 
	protected boolean[] used = new boolean[MAX_AVAILABLE];

	protected synchronized Object getNextAvailableItem() {
		for (int i = 0; i < MAX_AVAILABLE; ++i) {
			if (!used[i]) {
				used[i] = true;
				return items[i];
			}
		}
		return null; // not reached
	}

	protected synchronized boolean markAsUnused(Object item) {
		for (int i = 0; i < MAX_AVAILABLE; ++i) {
			if (item == items[i]) {
				if (used[i]) {
					used[i] = false;
					return true;
				} else
					return false;
			}
		}
		return false;
	}
}
```
这是官方举的一个例子,控制资源池的访问.许可数量为100,也就是资源被访问的最高并发数为100.

### 闭锁

闭锁可用延迟线程的进度直到其到达某个状态.CountDownLatch可以使一个或者多个线程等待一组事件的发生.它的主要方法如下:


```
// 初始化 , 计数器必须大于0
public CountDownLatch(int count) {
	if (count < 0) throw new IllegalArgumentException("count < 0");
	this.sync = new Sync(count);
}

//进入等待
public void await() throws InterruptedException ;
public boolean await(long timeout, TimeUnit unit) throws InterruptedException 

// 事件发生,递减计数器
public void countDown() ;

// 当前计数器的值
public long getCount();
```

闭锁状态包含一个计数器,该计数器被初始化为一个正数,表示需要等待的事件数量. countDown方法递减计数器,表示已经有一个事件已经发生了.而await方法等待计数器到达零,这表示所有的事件都已经发生了.如果计数器非 零,那么await会一直阻塞直到计数器为零或者等待中的线程中断或者等待超时.


**示例一**

```
// approach 1
// 创建连接

ZooKeeper zk = new ZooKeeper(hosts, SESSION_TIMEOUT, new Watcher() {  
	public void process(WatchedEvent event) {
	}  
});   

// 创建子节点 略

// approach 2
// 创建连接
CountDownLatch latch = new CountDownLatch(1);

ZooKeeper zk = new ZooKeeper(hosts, SESSION_TIMEOUT, new Watcher() {  
	public void process(WatchedEvent event) {
	    // 连接建立时,打开latch,唤醒wait在该latch上的线程  
		if (event.getState() == KeeperState.SyncConnected) {  
			latch.countDown();  
		}  
	}  
});

latch.await();

// 创建子节点 略


```
上面一段代码演示了两种方式方式创建zk连接然后立刻创建znode. 方式一会概率性出现创建的节点的时候抛出异常.原因是创建ZooKeeper连接是异步的,如果连接还没有创建成功进行操作则会抛出异常.

方式二就是解决方法.使用闭锁,连接成功了才打开闭锁.执行后续的操作.这是一个典型的闭锁的典型用法.

**示例二**

再举个等待多个事件的场景.

假设一次广告播放请求需要去请求多家DSP取其中价格高的进行播放,要求在50ms内返回.程序需要多路进行调用,然后取结果进行处理.而且还要设置一个超时时间,没有在指定时间内的返回不进行处理.


```
private static ExecutorService ES = Executors.newFixedThreadPool(3);
	
public static void main(String[] args) throws Exception {
	
	final CountDownLatch latch = new CountDownLatch(3);
	
	// 请求多家DSP
	List<Future<Integer>> futureList = new ArrayList<>();
	for(int i=0;i<3;i++){
		futureList.add(ES.submit(new DspInvoker(String.valueOf(i), latch)));
	}
	
	//等待执行多家DSP返回,或者超时
	latch.await(5, TimeUnit.SECONDS);
	
	//处理结果
	for(int i=0;i<3;i++){
		Future<Integer> future = futureList.get(i);
		if(future.isDone())
			System.out.println(future.get());
	}
	
	ES.shutdown();
}

// DSP请求线程
private static class DspInvoker implements Callable<Integer>{
	
	private String name;
	
	private CountDownLatch latch;
	
	public DspInvoker(String name,CountDownLatch latch){
		this.name = name;
		this.latch = latch;
	}

	@Override
	public Integer call() throws Exception {
		
		Random rand = new Random();
		int mills = rand.nextInt(1000)*10;
		try{
			Thread.sleep(mills);
			System.out.println("I'm "+name+",will sleep "+mills+" millseconds");
			//请求结束,减小闭锁计数
			latch.countDown();
		}
		catch (Exception ex) {
			ex.printStackTrace();
		}
		
		return mills;
	}
}
```

示例代码模拟了3个线程去请求DSP并等待其5s返回并处理结果.


```
I'm 2,will sleep 1460 millseconds
I'm 0,will sleep 4000 millseconds
4000
1460
I'm 1,will sleep 9460 millseconds
```
取其中的一次结果看到0和2号线程在规定的时间内返回了结果并且被处理了.而1号线程超时了,结果没有被处理.


### 小结

信号量用于控制资源的并发访问数,闭锁让线程等待某个或者某些事件发生才继续执行.