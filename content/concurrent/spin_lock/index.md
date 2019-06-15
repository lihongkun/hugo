---
title: 自旋锁
date: 2018-09-04
categories: ["concurrent"]
---
自旋锁是指当一个线程尝试获取某个锁时,如果该锁已被其他线程占用,就一直循环检测锁是否被释放,而不是进入线程挂起或睡眠状态.它适用于锁保护的临界区很小的情况,临界区很小的话,锁占用的时间就很短.
<!--more-->

下面是一个自旋锁的实现,lock里面有一个while忙循环也就是自旋的过程.AtomicReference为了保证操作的原子性.
```
public class SpinLock {

	private AtomicReference<Thread> lock = new AtomicReference<Thread>();

	public void lock() {
		Thread currentThread = Thread.currentThread();
		
		// 没有抢到锁就自旋
		while (!lock.compareAndSet(null, currentThread)) {
			System.out.println("spin...");
		}
	}

	public void unlock() {
		Thread currentThread = Thread.currentThread();
		lock.compareAndSet(currentThread, null);
	}
}
```
写一段测试代码.一个抢锁的任务,由多个线程来执行.

```
private static class SpinLockThread extends Thread{
		
	private SpinLock spinLock;
	
	public SpinLockRunable(SpinLock spinLock){
		this.spinLock = spinLock;
	}
	
	@Override
	public void run() {
		try{
			spinLock.lock();
			System.out.println(Thread.currentThread().getName()+"|lock");
			Thread.sleep(1000);
		}
		catch (Exception e) {
		}
		finally {
			System.out.println(Thread.currentThread().getName()+"|unlock");
			spinLock.unlock();
		}
	}
}

public static void main(String[] args) {
		
	final SpinLock spinLock = new SpinLock();
	
	Thread t1 = new SpinLockThread(spinLock);
	Thread t2 = new SpinLockThread(spinLock);
	Thread t3 = new SpinLockThread(spinLock);
	
	t1.start();
	t2.start();
	t3.start();
}
```
输出的结果是lock和unlock中间穿插着很多的spin.也就是自旋的输出.一般是t1先执行.t2和t3进入自旋.而t1结束后,谁将获得锁是不确定的.它无法保证公平性,不保证等待线程按照FIFO顺序获得锁.

## CLH锁

CLH(Craig,Landin,and Hagersten  locks): 是一个自旋锁,能确保无饥饿性,提供先来先服务的公平性.

CLH锁也是一种基于链表的可扩展、高性能、公平的自旋锁,申请线程只在本地变量上自旋.它不断轮询前驱的状态，如果发现前驱释放了锁就结束自旋.


```
public class CLHLock {

	public static class CLHNode {
		public boolean isLocked = false;
	}

	private AtomicReference<CLHNode> tail;
	private ThreadLocal<CLHNode> previous;
	private ThreadLocal<CLHNode> current;

	public CLHLock() {

		tail = new AtomicReference<CLHNode>(new CLHNode());
		current = new ThreadLocal<CLHNode>() {
			protected CLHNode initialValue() {
				return new CLHNode();
			}
		};
		previous = new ThreadLocal<CLHNode>() {
			protected CLHNode initialValue() {
				return null;
			}
		};
	}

	public void lock() {
		CLHNode node = current.get();
		node.isLocked = true;
		CLHNode pre = tail.getAndSet(node);
		previous.set(pre);
		while (pre.isLocked) {
			
		}
	}

	public void unlock() {
		CLHNode node = current.get();
		node.isLocked = false;
		current.set(null); // 去掉引用,可以被垃圾回收
		previous.set(null);// 前置从链表中移除
	}
}
```

上面是一个简单的CLH实现,每个线程都有当前Node和前置Node,他们前后连接组成一个单向链表.每个请求锁的线程都先入队.如果前置节点不是被锁住的状态当前就是成功,否则进入自旋.

JDK并发包里面的基础框架AbstractQueuedSynchronizer 所使用的锁算法就是CLH锁.