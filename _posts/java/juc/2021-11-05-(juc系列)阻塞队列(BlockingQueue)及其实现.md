---
layout: post
category: [Java,阻塞队列,BlockingQueue]
tags:
  - Java
  - 阻塞队列
  - BlockingQueue
---

本文源码基于: <font color='red'>JDK13</font>

整体的类图:

![2021-10-20-21-56-47](http://img.couplecoders.tech/2021-10-20-21-56-47.png)

## BlockingQueue 接口

### 官方注释翻译

什么是阻塞队列?

一个队列，它支持:

* 获取元素时，如果队列为空，可以等待元素入队，直到队列不为空
* 存储元素时，如果队列满了，可以等待元素出队，知道队列腾出空间

这就是一个阻塞队列了~.

阻塞队列的方法，有四种形式来处理，操作没有办法被立刻满足，但是未来某些时间点可能满足的情况:

* 抛出异常
* 返回特殊值(null/false等)
* 阻塞直到操作被满足
* 阻塞直到给定的最大等待时间.

下表是一个总结:

方法类型 | 抛出异常 | 特殊值 | 等待 | 支持超时的等待
--- | --- | --- | --- | ---
insert | add(e) | offer(e) | put(e) | offer(e,time,unit)
remove | remove() | poll() | take() | poll(time,unit)
examine | element() | peek() | 不支持 | 不支持

阻塞队列不接受空值. 它的实现在尝试添加空值时将会抛出NPE.空值被用来表明`poll`操作错误了.

阻塞队列可以设置为有界的. 他可以有一个剩余容量，超过这个容量，不阻塞的put方法都无法成功. 没有指定容量的阻塞队列，都默认剩余的容量是`Integer.MAX_VALUE`.

阻塞队列的实现类，被设计为在生成消费模型中使用，同时支持`Collection`接口. 因此，它支持从队列中删除一个给定的元素. 然而，这些方法执行的不是很高效，而且只打算偶尔用用，主要用于队列中的消息被取消了.

阻塞队列的实现类是线程安全的. 所有入队的方法原子性的实现他们的操作，使用内部的锁或者其他形式的同步控制。然而，批量的集合操作`addAll，containsAll，retainAll，removeAll`
不是线程安全的，除非特别给它实现了一下. 所以，`addAll`方法可以在添加了其中部分元素后抛出异常.

阻塞队列本质上不识闲一些类似于`close``shutdown`方法去表明不会再有元素添加进来了. 这类的需求旺旺由子类独立实现.

比如，一个公共的策略是， 由生产者写入一个特殊值，这个特殊值将导致所有消费者中断，以此来实现上面的需求.

使用实例:

一个常见的生产消费场景，注意阻塞队列可以线程安全的被多个生产者和消费者使用.

```java
 class Producer implements Runnable {
    private final BlockingQueue queue;

    Producer(BlockingQueue q) {
        queue = q;
    }

    public void run() {
        try {
            while (true) {
                queue.put(produce());
            }
        } catch (InterruptedException ex) { ...handle ...}
    }

    Object produce() { ...}
}

class Consumer implements Runnable {
    private final BlockingQueue queue;

    Consumer(BlockingQueue q) {
        queue = q;
    }

    public void run() {
        try {
            while (true) {
                consume(queue.take());
            }
        } catch (InterruptedException ex) { ...handle ...}
    }

    void consume(Object x) { ...}
}

class Setup {
    void main() {
        BlockingQueue q = new SomeQueueImplementation();
        Producer p = new Producer(q);
        Consumer c1 = new Consumer(q);
        Consumer c2 = new Consumer(q);
        new Thread(p).start();
        new Thread(c1).start();
        new Thread(c2).start();
    }
}
```

### 接口方法

大部分方法在上面的注释中，有个表格，定义了以什么样的策略做什么操作. 这里只备注剩下的几个接口咯.

* add
* offer
* put
* offer(time,unit)
* take
* poll
* remainingCapacity 剩余容量
* remove
* contains 是否包含
* drainTo
* drainTo(collection, int number) 从队列中移除可用元素，并且放到给定的集合中. 最多移除给定数量个.

## ArrayBlockingQueue

### 官方注释翻译

使用数组实现的一个有界的阻塞队列，这个队列按照FIFO的顺序提供元素.

队列的第一个元素，也就是队列头部，是入队最久的元素，队列尾部是入队时间最少的元素. 新元素将插入到队列的尾部，队列的获取操作将从队列的头部获取元素.

这是一个经典的有界缓冲，一个固定大小的数组，持有元素，被生产者插入元素和被消费者获取元素. 一旦创建，容量就不能再更改了.

向一个满了的队列插入元素，将会导致阻塞，从一个空的队列中获取元素，也会阻塞.

这个类支持了可选的生产消费线程阻塞公平的等待顺序策略，默认情况下，这个顺序是不保证的.

但是，创建队列时，指定了公平的策略，那么就会保证线程以FIFO的顺序来访问了.

公平策略通常会降低吞吐量但是减少不确定性，以及能够避免过度的饥饿.

这个类及其迭代器实现了集合类和迭代器的所有可选方法.

这个类也是Java集合框架的一部分.

### 源码

#### 定义

```java
public class ArrayBlockingQueue<E> extends AbstractQueue<E>
        implements BlockingQueue<E>, java.io.Serializable {
```

`ArrayBlockingQueue`继承自`AbstractQueue`，拥有队列的常见方法，同时实现了`BlockingQueue`接口，有阻塞队列相关特性.

#### 属性

```java
    /** The queued items */
// 用数组保存的队列中的元素
final Object[]items;

        /** items index for next take, poll, peek or remove */
        // 下一个移除的元素的索引，代指队首
        int takeIndex;

        /** items index for next put, offer, or add */
        // 下一个添加的元素的索引，代指队尾
        int putIndex;

        /** Number of elements in the queue */
        // 当前队列中的元素数量
        int count;

/*
 * Concurrency control uses the classic two-condition algorithm
 * found in any textbook.
 */

// 锁
/** Main lock guarding all access */
final ReentrantLock lock;

/** Condition for waiting takes */
// 等待条件，消费者等待
private final Condition notEmpty;

/** Condition for waiting puts */
// 等待条件，生产者等待
private final Condition notFull;

/**
 * Shared state for currently active iterators, or null if there
 * are known not to be any.  Allows queue operations to update
 * iterator state.
 */
// 迭代器？
transient Itrs itrs;

```

一些核心属性的介绍，其中由数组保存队列中的元素，两个下标分别指向队头和队尾.

#### 构造方法

```java

// 指定容量
public ArrayBlockingQueue(int capacity){
        this(capacity,false);
        }

// 指定容量和公平性策略，默认的公平性策略是非公平
public ArrayBlockingQueue(int capacity,boolean fair){
        if(capacity<=0)
        throw new IllegalArgumentException();
        this.items=new Object[capacity];
        lock=new ReentrantLock(fair);
        notEmpty=lock.newCondition();
        notFull=lock.newCondition();
        }

// 用一个给定的集合初始化阻塞队列，除了初始化属性外，还将集合中的所有元素放入队列
public ArrayBlockingQueue(int capacity,boolean fair,
        Collection<?extends E> c){
        this(capacity,fair);

final ReentrantLock lock=this.lock;
        lock.lock(); // Lock only for visibility, not mutual exclusion
        try{
final Object[]items=this.items;
        int i=0;
        try{
        for(E e:c)
        items[i++]=Objects.requireNonNull(e);
        }catch(ArrayIndexOutOfBoundsException ex){
        throw new IllegalArgumentException();
        }
        count=i;
        putIndex=(i==capacity)?0:i;
        }finally{
        lock.unlock();
        }
        }

```

可以指定阻塞队列的容量，以及公平性策略.

此外还支持将一个给定的集合中的所有元素放入队列中.

#### 入队操作

* add
* put
* offer
* offer(time,unit)

这四个方法，分别对应阻塞队列处理`队列满了却还是要入队`情况的四种策略.

##### add 抛出异常

```java

public boolean add(E e){
        return super.add(e);
        }
```

调用父类`AbstractQueue`的`add`方法，如果队列满了就抛出异常.

##### offer 返回特殊值

如果成功，就返回true，失败返回false。

```java

public boolean offer(E e){
        Objects.requireNonNull(e);
final ReentrantLock lock=this.lock;
        lock.lock();
        try{
        if(count==items.length)
        return false;
        else{
        enqueue(e);
        return true;
        }
        }finally{
        lock.unlock();
        }
        }
```

首先加锁，然后判断当前队列是否满了，如果满了返回false。 否则调用`enqueue`进入入队操作.

```java

private void enqueue(E e){
// assert lock.isHeldByCurrentThread();
// assert lock.getHoldCount() == 1;
// assert items[putIndex] == null;
final Object[]items=this.items;
        // 放入队尾
        items[putIndex]=e;
        // 如果超过数组长度，就返回到0
        if(++putIndex==items.length)putIndex=0;
        // 元素＋1
        count++;
        // 队列不为空，唤醒等待者
        notEmpty.signal();
        }
```

这是一个核心的入队方法，多种添加元素的方法实际上都是调用的它.

##### put 超时

```java

public void put(E e)throws InterruptedException{
        Objects.requireNonNull(e);
final ReentrantLock lock=this.lock;
        lock.lockInterruptibly();
        try{
        while(count==items.length)
        notFull.await();
        enqueue(e);
        }finally{
        lock.unlock();
        }
        }
```

如果队列是满的，直接在`notFull`条件上await等待. 被唤醒后进行入队操作.

##### offer(e,time,unit) 支持超时的等待操作

```java

public boolean offer(E e,long timeout,TimeUnit unit)
        throws InterruptedException{

        Objects.requireNonNull(e);
        long nanos=unit.toNanos(timeout);
final ReentrantLock lock=this.lock;
        lock.lockInterruptibly();
        try{
        // 如果队列满了
        while(count==items.length){
        // 且超时了，返回0
        if(nanos<=0L)
        return false;
        nanos=notFull.awaitNanos(nanos);
        }
        enqueue(e);
        return true;
        }finally{
        lock.unlock();
        }
        }
```

如果队列满了，就自旋. 如果超时了，返回false。没有超时就在`notFull`条件上进行等待. 被唤醒后进行入队操作.

#### 出队操作

##### poll 返回特殊值

```java
    public E poll(){
final ReentrantLock lock=this.lock;
        lock.lock();
        try{
        return(count==0)?null:dequeue();
        }finally{
        lock.unlock();
        }
        }
```

如果队列为空，就返回`null`. 这就是为啥阻塞队列不支持`null`元素的原因，因为`null`值被用来代表队列中为空. 不为空则进行出队操作.

```java
    private E dequeue(){
// assert lock.isHeldByCurrentThread();
// assert lock.getHoldCount() == 1;
// assert items[takeIndex] != null;
final Object[]items=this.items;
@SuppressWarnings("unchecked")
// 从队首获取第一个元素
        E e=(E)items[takeIndex];
                // 队首变为空
                items[takeIndex]=null;
                // 队首指针移动
                if(++takeIndex==items.length)takeIndex=0;
                // 元素数量-1
                count--;
                // 告诉迭代器
                if(itrs!=null)
                itrs.elementDequeued();
                // 通知等待的生产者，队列中有空闲位置了
                notFull.signal();
                return e;
                }
```

这是核心的出队操作，按照注释里的步骤完成多个相关属性的改变. 出队操作核心上都是调用的这个方法.

##### take 阻塞

```java

public E take()throws InterruptedException{
final ReentrantLock lock=this.lock;
        lock.lockInterruptibly();
        try{
        while(count==0)
        notEmpty.await();
        return dequeue();
        }finally{
        lock.unlock();
        }
        }
```

如果队列为空，则在`notEmpty`条件上等待，被唤醒后执行出队操作。

##### poll(time,unit) 超时版本的阻塞

```java

public E poll(long timeout,TimeUnit unit)throws InterruptedException{
        long nanos=unit.toNanos(timeout);
final ReentrantLock lock=this.lock;
        lock.lockInterruptibly();
        try{
        while(count==0){
        if(nanos<=0L)
        return null;
        nanos=notEmpty.awaitNanos(nanos);
        }
        return dequeue();
        }finally{
        lock.unlock();
        }
        }
```

如果队列为空，且超时了，就返回null。如果没有超时，就等待指定的毫秒数.

#### 查看系列方法

* size 直接返回count值即可.
* peek 返回队首的元素，但是不弹出,可以用来查看当前队首的元素
* remainingCapacity 返回剩余容量

#### 总结

`ArrayBlockingQueue` 是一个比较简单的阻塞队列实现.

由数组保存元素，队首队尾两个指针负责控制入队和出队的位置.

线程安全由`ReentrantLock`保证，内部所有对数组的读取及改动均需要加锁.

阻塞功能由锁带的`Condition`实现，两个`Condition`分别负责`队列不为空``队列没有满`，分别使生产者和消费者阻塞，及条件满足后的唤醒功能.

## LinkedBlockingQueue

### 官方注释翻译

一个用链表实现的可以是有界的阻塞队列. 元素排序为FIFO.

队头元素是在队列中时间最长的元素，队尾元素是在队列中时间最短的元素.

新的元素插入到队列尾部，获取操作从队头获取元素.

链表实现的队列通常比数组实现的有更高的吞吐量，但是在高并发情况下，性能更加不可预测.

通常的容量边界提供了一个扩容队列的操作， 默认情况下，容量是: Integer.MAX_VALUE. 链表的节点在每一次插入操作时动态创建，除非这次插入会超过队列容量.

这个类和他的迭代器实现了`Collection`和`Iterator`接口的所有可选方法.这个类也是Java集合框架的一部分.

### 源码

#### 定义

```java
public class LinkedBlockingQueue<E> extends AbstractQueue<E>
        implements BlockingQueue<E>, java.io.Serializable {
```

实现了基础的`AbstractQueue`接口，因此具有所有的队列常用方法，同时实现了`BlockingQueue`接口，也具有阻塞队列的所有特性.

#### 链表节点定义

```java
    static class Node<E> {
    E item;

    /**
     * One of:
     * - the real successor Node
     * - this Node, meaning the successor is head.next
     * - null, meaning there is no successor (this is the last node)
     */
    Node<E> next;

    Node(E x) {
        item = x;
    }
}
```

比较简单的一个定义, 持有当前的元素及下一个节点的指针.

这个指针有三种情况:

* Node 一个真实的节点
* 当前节点， 意味着当前节点的下一个，是`head.next`.
* null 意味着没有后继节点了. 当前节点是最后一个节点.

#### 属性

```java
// 初始设定的容量
private final int capacity;

// 当前数量
private final AtomicInteger count=new AtomicInteger();

/**
 * Head of linked list.
 * Invariant: head.item == null
 */
// 头结点，头结点的item一定为null
transient Node<E> head;

/**
 * Tail of linked list.
 * Invariant: last.next == null
 */
// 尾节点，尾节点的next指针一定是null
private transient Node<E> last;

/** Lock held by take, poll, etc */
// 获取元素时的锁
private final ReentrantLock takeLock=new ReentrantLock();

/** Wait queue for waiting takes */
// 不为空的等待条件
private final Condition notEmpty=takeLock.newCondition();

/** Lock held by put, offer, etc */
// 写入元素时的锁
private final ReentrantLock putLock=new ReentrantLock();

/** Wait queue for waiting puts */
// 队列有空闲的等待条件
private final Condition notFull=putLock.newCondition();
```

* 首先保存了最大容量与当前容量，用来实现有界队列。
* 其次保存了头结点和尾节点，用来实现链表保存实际的元素
* 最后持有两把锁，分别锁队头和队尾，用来保证线程安全
* 每把锁有对应的等待条件，用来休眠/唤醒线程，用来实现线程阻塞

#### 构造方法

```java

public LinkedBlockingQueue(){
        this(Integer.MAX_VALUE);
        }

public LinkedBlockingQueue(int capacity){
        if(capacity<=0)throw new IllegalArgumentException();
        this.capacity=capacity;
        last=head=new Node<E>(null);
        }

public LinkedBlockingQueue(Collection<?extends E> c){
        this(Integer.MAX_VALUE);
final ReentrantLock putLock=this.putLock;
        putLock.lock(); // Never contended, but necessary for visibility
        try{
        int n=0;
        for(E e:c){
        if(e==null)
        throw new NullPointerException();
        if(n==capacity)
        throw new IllegalStateException("Queue full");
        enqueue(new Node<E>(e));
        ++n;
        }
        count.set(n);
        }finally{
        putLock.unlock();
        }
        }

```

提供了三个构造方法，可以指定容量，然后初始化头结点.

此外还支持将给定的集合初始化进队列.

#### 入队操作

##### add 抛出异常

调用的`AbstractQueue`的方法，如果队列满了直接抛出异常.

##### offer(e) 返回true/false

```java
    public boolean offer(E e){
        if(e==null)throw new NullPointerException();
// 当前数量
final AtomicInteger count=this.count;
        // 如果队列满了，返回false
        if(count.get()==capacity)
        return false;
final int c;
// 初始化当前节点
final Node<E> node=new Node<E>(e);
// 写入锁的加锁
final ReentrantLock putLock=this.putLock;
        putLock.lock();
        try{
        // 加锁后再次检查一下容量
        if(count.get()==capacity)
        return false;
        // 入队操作
        enqueue(node);
        // 数量+1
        c=count.getAndIncrement();
        // 如果还有空闲容量，唤醒等待的其他生产者
        if(c+1<capacity)
        notFull.signal();
        }finally{
        putLock.unlock();
        }
        // 如果当前写入前，容量为0，也就是当前节点是给空队列放入的第一个元素，唤醒等待的消费者
        if(c==0)
        signalNotEmpty();
        return true;
        }
```

两次检查队列容量，如果超出限制，就返回false。否则的话调用入队操作. 此外，如果当前元素，是给空队列放入的第一个元素，唤醒其他消费者，告诉他们，队列不为空了.

```java
    private void enqueue(Node<E> node){
        // assert putLock.isHeldByCurrentThread();
        // assert last.next == null;
        // 将当前节点链接在最后一个节点的下一个
        last=last.next=node;
        }
```

这是核心的元素入队操作，比较简单，只是将当前元素链接在当前链表的尾部即可.

##### put 阻塞

```java

public void put(E e)throws InterruptedException{
        if(e==null)throw new NullPointerException();
final int c;
// 创建当前节点
final Node<E> node=new Node<E>(e);
final ReentrantLock putLock=this.putLock;
final AtomicInteger count=this.count;
        // 写入的锁加锁
        putLock.lockInterruptibly();
        try{
        /*
         * Note that count is used in wait guard even though it is
         * not protected by lock. This works because count can
         * only decrease at this point (all other puts are shut
         * out by lock), and we (or some other waiting put) are
         * signalled if it ever changes from capacity. Similarly
         * for all other uses of count in other wait guards.
         */
        // 如果队列满了，自旋且等待
        while(count.get()==capacity){
        notFull.await();
        }
        // 被唤醒后，说明队列不满了，执行入队操作
        enqueue(node);
        c=count.getAndIncrement();
        // 如果队列不满，协助唤醒其他生产者
        if(c+1<capacity)
        notFull.signal();
        }finally{
        putLock.unlock();
        }
        // 如果当前元素是第一个元素，唤醒其他的消费者
        if(c==0)
        signalNotEmpty();
        }
```

总体和`offer`很相似，只是在发现队列已经满了的时候，不是返回false。而是在`notFull`条件上进行等待，等待别的线程唤醒. 唤醒后就可以继续入队了。

##### offer(e,time,unit)

```java

public boolean offer(E e,long timeout,TimeUnit unit)
        throws InterruptedException{

        if(e==null)throw new NullPointerException();
        long nanos=unit.toNanos(timeout);
final int c;
final ReentrantLock putLock=this.putLock;
final AtomicInteger count=this.count;
        putLock.lockInterruptibly();
        try{
        while(count.get()==capacity){
        if(nanos<=0L)
        return false;
        nanos=notFull.awaitNanos(nanos);
        }
        enqueue(new Node<E>(e));
        c=count.getAndIncrement();
        if(c+1<capacity)
        notFull.signal();
        }finally{
        putLock.unlock();
        }
        if(c==0)
        signalNotEmpty();
        return true;
        }
```

和`put`相似，只是在返现队列满的情况下，如果已经超时，就返回false，如果没有超时，就让当前线程休眠给定的毫秒数，再次判断是否能够入队元素.

#### 出队操作

```java

public E poll(){
// 当前数量
final AtomicInteger count=this.count;
        // 如果当前为空，返回null.
        if(count.get()==0)
        return null;
final E x;
final int c;
final ReentrantLock takeLock=this.takeLock;
        // 读锁加锁
        takeLock.lock();
        try{
        // 再次检查队列是否为空
        if(count.get()==0)
        return null;
        // 执行出队操作
        x=dequeue();
        c=count.getAndDecrement();
        // 如果当前元素不是队列中的唯一一个元素，就协助唤醒消费者
        if(c>1)
        notEmpty.signal();
        }finally{
        takeLock.unlock();
        }
        // 如果出队前，队列是满的，那么出队后，队列不满，唤醒其他生产者
        if(c==capacity)
        signalNotFull();
        return x;
        }
```

如果队列为空，返回null的出队方法.

首先检查数组容量，为空则返回null。之后对读锁进行加锁，再次检查容量.

如果容量不为空，执行核心出队操作。 出队后，如果队列中还有元素，就协助唤醒消费者.

如果出队前，队列是满的，那么当前元素是满的队列出队的第一个元素，唤醒其他生产者.

```java

private E dequeue(){
        // assert takeLock.isHeldByCurrentThread();
        // assert head.item == null
        // 链表的头结点
        Node<E> h=head;
        // 链表的第一个节点
        Node<E> first=h.next;

        h.next=h; // help GC
        // 头结点改成first
        head=first;
        E x=first.item;
        first.item=null;
        // 返回节点
        return x;
        }
```

链表的核心出队方法, 比入队复杂了一点.

将头结点(空的占位节点)指向第一个真实节点，将真实节点的元素返回即可.

##### take() 阻塞

```java

public E take()throws InterruptedException{
final E x;
final int c;
final AtomicInteger count=this.count;
final ReentrantLock takeLock=this.takeLock;
        takeLock.lockInterruptibly();
        try{
        while(count.get()==0){
        notEmpty.await();
        }
        x=dequeue();
        c=count.getAndDecrement();
        if(c>1)
        notEmpty.signal();
        }finally{
        takeLock.unlock();
        }
        if(c==capacity)
        signalNotFull();
        return x;
        }
```

首先加锁，然后判断队列是否为空，如果为空，就在`notEmpty`条件上阻塞，等待唤醒.

被唤醒后，说明当前队列不为空，执行出队操作.

如果出队后，队列不为空，协助唤醒消费者. 如果出队前，队列是满的，那么就唤醒生产者.

##### poll(time,unit)

```java

public E poll(long timeout,TimeUnit unit)throws InterruptedException{
final E x;
final int c;
        long nanos=unit.toNanos(timeout);
final AtomicInteger count=this.count;
final ReentrantLock takeLock=this.takeLock;
        takeLock.lockInterruptibly();
        try{
        while(count.get()==0){
        if(nanos<=0L)
        return null;
        nanos=notEmpty.awaitNanos(nanos);
        }
        x=dequeue();
        c=count.getAndDecrement();
        if(c>1)
        notEmpty.signal();
        }finally{
        takeLock.unlock();
        }
        if(c==capacity)
        signalNotFull();
        return x;
        }

```

和`take`方法很相似，只是在发现队列为空时，需要判断是否超时，如果超时，返回null。如果没有超时，就让当前线程阻塞给定的时间，而不是无限的阻塞.

#### 查看方法

* size 返回当前数量
* remainingCapacity 剩余容量
* peek 获取当前队头元素，但是不弹出，主要用于查看队头元素内容

#### 总结

`LinkedBlockingQueue` 是另外一个比较简单的阻塞队列实现. 内部使用链表来存储元素.

* 首先保存了最大容量与当前容量，用来实现有界队列。
* 其次保存了头结点和尾节点，用来实现链表保存实际的元素,且方便入队与出队操作
* 持有两把锁，分别锁队头和队尾，用来保证线程安全
* 每把锁有对应的等待条件`Condition`，用来休眠/唤醒, 入队和出队的线程，也就是生产者和消费者线程，用来实现线程阻塞及条件满足后的唤醒功能.

由于保存了队头和队尾节点，入队和出队操作的性能都是比较不错的，使用两把锁，分别控制入队和出队的同步控制. 能够最小化锁竞争，提升性能。

与数组实现的`ArrayBlockingQueue`相比，吞吐量会更高一些，但是在高并发的情况下，会有一些不可预测的性能损失.

<br>


完。
<br>
<br>
<br>


## 联系我
最后，欢迎关注我的个人公众号【 呼延十 】，会不定期更新很多后端工程师的学习笔记。
也欢迎直接公众号私信或者邮箱联系我，一定知无不言，言无不尽。
![](http://img.couplecoders.tech/%E6%89%AB%E7%A0%81_%E6%90%9C%E7%B4%A2%E8%81%94%E5%90%88%E4%BC%A0%E6%92%AD%E6%A0%B7%E5%BC%8F-%E6%A0%87%E5%87%86%E8%89%B2%E7%89%88.png)


<br>
<br>




**以上皆为个人所思所得，如有错误欢迎评论区指正。**


**欢迎转载，烦请署名并保留原文链接。**


**联系邮箱：huyanshi2580@gmail.com**


**更多学习笔记见个人博客或关注微信公众号 &lt;呼延十 &gt;------><a href="{{ site.baseurl }}/">呼延十</a>**