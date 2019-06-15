---
title: 原子变量
date: 2018-12-17
categories: ["concurrent"]
---

锁机制提供了独占的方法来访问变量,并且对变量的任何修改都会对随后获得这个锁的其他线程可见.但是如果一个线程在休眠或者自旋的时候持有一个锁,那么其他线程便无法执行下去.而非阻塞算法不会受到单个线程失败的影响.对于**细粒度**的操作,非阻塞算法更高效.它需要借助冲突检查机制来判断更新过程中是否存在来自其他线程的干扰,如果存在则操作失败,并且重试.现代处理器都提供了这种读-改-写(Compare-And-Swap)的指令,来实现这种复杂的并发对象.

<!--more-->

有了硬件级别的支持,Java 5.0之后公开了一些CAS操作,原子变量类.并在其基础上实现了另外的一些并发容器.

#### 原子变量

原子变量位于 java.util.concurrent.atomic包下面，可以按使用方式和意图分为四组

- *基础类型* : AtomicBoolean、AtomicInteger、AtomicLong、LongAdder等
- *数组类型* : AtomicIntegerArray、AtomicLongArray
- *引用类型* : AtomicReference、AtomicMarkableReference、AtomicStampedReference、AtomicReferenceArray
- *域更新器*  : AtomicLongFieldUpdater、AtomicIntegerFieldUpdater、AtomicReferenceFieldUpdater

**基础类型和数组类型**

对基础的数值类型进行包装, 主要适用于计数的场景,很多流量统计的相关框架使用了这种类型的类.

```
public static void main( String[] args )
{
	final int loopTimes = 10000;
	// 使用基础变量进行计数
	final AtomicInteger cnt = new AtomicInteger(0);
	final AtomicLongArray cntArray = new AtomicLongArray(10);

	ExecutorService es = Executors.newFixedThreadPool(5);
	for(int i=0;i<5;i++){
		es.execute(new Runnable() {
			@Override
			public void run() {
				for(int i=0;i<loopTimes;i++) {
					cnt.incrementAndGet();
				}
				for(int i=0;i<loopTimes;i++){
					cntArray.addAndGet(i%10,1);
				}
			}
		});
	}

	es.shutdown();
	while(true){
		if(es.isTerminated()) {
			break;
		}
	}

	System.out.println("final cnt : " + cnt.get());

	for(int i = 0 ; i < cntArray.length();i++){
		System.out.println("final cntArray "+i+" : " + cntArray.get(i));
	}
}
```

**引用类型**

顾名思义,引用类型用于并发环境中更新整个引用.举个并发容器的例子,

```
public class ConcurrentLinkedQueue <E>{

    /**
     * 定义链表节点
     */
    private static class Node<E>{
        
        final E item;

        /**
         * 链表下一个节点使用原子引用
         */
        final AtomicReference<Node<E>> next;
        
        public Node(E item,Node<E> next){
            this.item = item;
            this.next = new AtomicReference<>(next);
        }
    }

    /**
     * 哑节点
     */
    private final Node<E> dummy = new Node<>(null,null);

    /**
     * 头部节点指针
     */
    private final AtomicReference<Node<E>> head = new AtomicReference<>(dummy);

    /**
     * 尾部节点指针
     */
    private final AtomicReference<Node<E>> tail = new AtomicReference<>(dummy);
    
    public boolean put(E item){
        Node<E> newNode = new Node<E>(item,null);
        while(true){
            Node<E> curTail = tail.get();
            Node<E> nextTail = curTail.next.get();
            
            if(curTail == tail.get()){
                // 中间状态 ,尾部节点的下一个已经存在
                // 直接把尾部指针指向当前尾部节点的下一个节点
                if(nextTail != null){
                    tail.compareAndSet(curTail,nextTail);
                }
                else{
                	// 尾部节点下一个节点指针是空,则为稳定状态.操作两个指针
                    if(curTail.next.compareAndSet(null,newNode)){
                        tail.compareAndSet(curTail,nextTail);
                        return true;
                    }
                }
            }
        }
    }
}
```

如上述代码ConcurrentLinkedQueue是一个并发队列. Node为节点数据 . put 方法插入一个数据在队尾,需要移动两个指针. 一个是尾部节点指针,一个是尾部节点的下一个节点的指针也就是当前tail的next. 指针的推进都是使用原子类型来保证.

**域更新器**

属性修改器对比于引用类型是粒度比较小的,它通过反射实现对某个对象的属性修改,并且保证原子性.同样是ConcurrentLinkedQueue的例子,在更新Node节点的next指针的时候,不一定需要使用引用类型来包装,而是可以使用域更新器.

```
public class ConcurrentLinkedQueue <E>{
	
    private static class Node<E>{
        
        private final E item;

        private volatile Node<E> next;
        
        public Node(E item){
            this.item = item;
        }
    }
    
    private static final AtomicReferenceFieldUpdater<Node,Node> nextUpdater = AtomicReferenceFieldUpdater.newUpdater(Node.class,Node.class,"next");
    
   ... 
    
}
```

### ABA问题

CAS算法实现一个重要前提需要取出内存中某时刻的数据,而在下时刻比较并替换,那么在这个时间差内会导致数据的变化.假设操作是 V.compareAndSet(A,X) ,在观测V的值之前,V 的变化是 A->B->A . 我们应该认为V的值也是发生变化的.

这类问题的解决方案是不止更新一个值.AtomicMarkableReference和AtomicStampedReference正是用来解决此类问题的.它们增加了一个标志位或者版本号的概念. 这个更一般数据库设计中的乐观锁是异曲同工.