---
layout: post
tags:
  - Java
  - 阻塞双端队列
  - BlockingDeque
---


本文源码基于: <font color='red'>JDK13</font>


## BlockingDeque 接口

### 官方注释翻译

和阻塞队列很像的，那么这个阻塞双端队列，我就翻译的简单点了.

首先他是一个支持阻塞操作的双端队列，当队列为空，要获取，可以阻塞。当队列满了，要写入，可以阻塞.

同样的，阻塞操作也有四种风格

* 抛出异常
* 返回特殊值
* 阻塞
* 超时的阻塞

对应的方法如下表:

**队头操作**

方法类型 | 抛出异常 | 特殊值 | 阻塞 | 超时阻塞
--- | --- | --- | --- | ---
insert | addFirst(e) | offerFirst(e) | putFirst(e)  | offerFirst(e,time,unit)
remove | removeFirst | pollFirst() | takeFirst() | pollFirst(time,unit)
examine | getFirst() | peekFirst() | 不支持 | 不支持

**队尾操作**

方法类型 | 抛出异常 | 特殊值 | 阻塞 | 超时阻塞
--- | --- | --- | --- | ---
insert | addLast(e) | offerLast(e) | putLast(e)  | offerLast(e,time,unit)
remove | removeLast | pollLast() | takeLast() | pollLast(time,unit)
examine | getLast() | peekLast() | 不支持 | 不支持

像阻塞队列一样，阻塞双端队列也是线程安全的.不允许控制，并且可以是有界的队列.

阻塞双端队列的实现，可以用作一个`FIFI的阻塞队列`。 继承自阻塞队列的方法，对应调用的阻塞双端队列的方法表如下:

方法 | 阻塞队列方法 | 等效的阻塞双端队列方法
--- | --- | ---
insert | put(e) | putLast(E)
remove | take() | takeFirst()
examine | peek() | peekFirst().

### 接口方法

* addFirst 队首添加
* addLast 队尾添加
* offerFirst 队首添加
* offerLast 队尾添加
* putFirst 阻塞版本的队首添加
* putLast 阻塞版本的队尾添加
* offerFirst 超时阻塞版本的队首添加
* offerLast 超时阻塞版本的队尾巴添加
* takeFirst 超时版本的队首移除
* takeLast 超时版本的队尾移除
* pollFirst 队首移除
* pollLast 队尾移除
* removeFirstOccurrence 移除队首
* removeLastOccurrence 移除队尾
* add 添加,接下来的8个方法继承自阻塞队列
* offer 添加
* put 添加
* offer 添加
* remove 移除
* poll 移除
* take 移除
* poll 移除
* element 获取元素
* peek 获取元素
* remove 移除
* contains 是否包含
* size 容量
* iterator 迭代器
* push 添加



## LinkedBlockingDeque 链表双端阻塞队列

### 官方注释翻译


一个可选是否有界的双端阻断队列. 使用链表实现.

可选的容量边界，使用构造函数来初始化，可以防止超出范围的扩容操作. 如果容量没有特殊指定的话，是`Integer.MAX_VALUE`.

链表的节点根据每一个插入操作，动态的进行创建，除非超过了给定的边界.

大部分操作的时间负责度都是线性的. 另外的有: `remove,removeFirstOccurrence`等一些移除方法和`contains`方法.

这个类和他的迭代器，实现了`Collection`和`Iterator`接口的所有可选方法.

### 源码

#### 定义

```java

public class LinkedBlockingDeque<E>
    extends AbstractQueue<E>
    implements BlockingDeque<E>, java.io.Serializable {
```

一个双端队列～.

#### 链表节点 Node

```java

    static final class Node<E> {
        /**
         * The item, or null if this node has been removed.
         */
        E item;

        /**
         * One of:
         * - the real predecessor Node
         * - this Node, meaning the predecessor is tail
         * - null, meaning there is no predecessor
         */
        Node<E> prev;

        /**
         * One of:
         * - the real successor Node
         * - this Node, meaning the successor is head
         * - null, meaning there is no successor
         */
        Node<E> next;

        Node(E x) {
            item = x;
        }
    }
```

比较粗暴，保存了当前节点的实际元素，以及指向前后节点的指针.

#### 属性

```java
    transient Node<E> first;

    /**
     * Pointer to last node.
     * Invariant: (first == null && last == null) ||
     *            (last.next == null && last.item != null)
     */
    transient Node<E> last;

    /** Number of items in the deque */
    private transient int count;

    /** Maximum number of items in the deque */
    private final int capacity;

    /** Main lock guarding all access */
    final ReentrantLock lock = new ReentrantLock();

    /** Condition for waiting takes */
    private final Condition notEmpty = lock.newCondition();

    /** Condition for waiting puts */
    private final Condition notFull = lock.newCondition();

```


* 保存了队列的头结点和尾节点，用来实现双端的列表
* 保存了当前数量和最大容量，用来实现有界队列
* lock用来对队列进行同步控制
* `notEmpty`和`notFull`两个条件用来进行阻塞和唤醒线程.


#### 构造方法

```java

    public LinkedBlockingDeque() {
        this(Integer.MAX_VALUE);
    }

    public LinkedBlockingDeque(int capacity) {
        if (capacity <= 0) throw new IllegalArgumentException();
        this.capacity = capacity;
    }

    public LinkedBlockingDeque(Collection<? extends E> c) {
        this(Integer.MAX_VALUE);
        addAll(c);
    }
```

对最大容量进行初始化.

同时还支持将给定集合的所有元素进行初始化入队操作.

#### 入队操作

* addFirst
* addLast
* offerFirst
* offerLast
* putFirst
* putLast
* offerFirst
* offerLast

8个方法，分别对应队头和队尾的4种插入方法.

##### add 抛出异常

```java

    public void addFirst(E e) {
        if (!offerFirst(e))
            throw new IllegalStateException("Deque full");
    }

    public void addLast(E e) {
        if (!offerLast(e))
            throw new IllegalStateException("Deque full");
    }

```

调用插入方法，如果失败，直接抛出异常.


##### offer(e) 返回特殊值

```java

    public boolean offerFirst(E e) {
        if (e == null) throw new NullPointerException();
        Node<E> node = new Node<E>(e);
        final ReentrantLock lock = this.lock;
        lock.lock();
        try {
            return linkFirst(node);
        } finally {
            lock.unlock();
        }
    }

    /**
     * @throws NullPointerException {@inheritDoc}
     */
    public boolean offerLast(E e) {
        if (e == null) throw new NullPointerException();
        Node<E> node = new Node<E>(e);
        final ReentrantLock lock = this.lock;
        lock.lock();
        try {
            return linkLast(node);
        } finally {
            lock.unlock();
        }
    }
```

首先使用内部的锁进行加锁后，分别将给定节点链接在头部和尾部.

```java

    // 链接在头部
    private boolean linkFirst(Node<E> node) {
        // assert lock.isHeldByCurrentThread();
        // 容量超出，返回false
        if (count >= capacity)
            return false;
        // 第一个节点
        Node<E> f = first;
        // 当前节点成为头结点
        node.next = f;
        first = node;
        if (last == null)
            last = node;
        else
            f.prev = node;
        // 唤醒消费者
        ++count;
        notEmpty.signal();
        return true;
    }

    /**
     * Links node as last element, or returns false if full.
     */
    private boolean linkLast(Node<E> node) {
        // assert lock.isHeldByCurrentThread();
            // 判断容量
        if (count >= capacity)
            return false;
        // 将当前节点链接在尾部
        Node<E> l = last;
        node.prev = l;
        last = node;
        if (first == null)
            first = node;
        else
            l.next = node;
        // 唤醒消费者
        ++count;
        notEmpty.signal();
        return true;
    }
```

##### put 阻塞

```java

    public void putFirst(E e) throws InterruptedException {
        if (e == null) throw new NullPointerException();
        Node<E> node = new Node<E>(e);
        final ReentrantLock lock = this.lock;
        lock.lock();
        try {
            while (!linkFirst(node))
                notFull.await();
        } finally {
            lock.unlock();
        }
    }

    /**
     * @throws NullPointerException {@inheritDoc}
     * @throws InterruptedException {@inheritDoc}
     */
    public void putLast(E e) throws InterruptedException {
        if (e == null) throw new NullPointerException();
        Node<E> node = new Node<E>(e);
        final ReentrantLock lock = this.lock;
        lock.lock();
        try {
            while (!linkLast(node))
                notFull.await();
        } finally {
            lock.unlock();
        }
    }
```

和offer方法很相似，只是在链接失败时，也就是队列满的时候，在`notFull`条件上阻塞等待。


##### offer(e,time,unit) 超时阻塞

和put很相似，只是阻塞不是永久的，而是阻塞给定的毫秒数而已。不再重复。


#### 出队操作

* removeFirst
* removeLast
* pollFirst
* pollLast
* takeFirst
* takeLast
* pollFirst
* pollLast

八个方法，分别对应队头和队尾的4种移除操作.

##### remove 抛出异常

```java

    public E removeFirst() {
        E x = pollFirst();
        if (x == null) throw new NoSuchElementException();
        return x;
    }


    public E removeLast() {
        E x = pollLast();
        if (x == null) throw new NoSuchElementException();
        return x;
    }
```

分别弹出头结点和尾节点，如果为空，则抛出异常.


##### poll 返回特殊值

```java

    public E pollFirst() {
        final ReentrantLock lock = this.lock;
        lock.lock();
        try {
            return unlinkFirst();
        } finally {
            lock.unlock();
        }
    }

    public E pollLast() {
        final ReentrantLock lock = this.lock;
        lock.lock();
        try {
            return unlinkLast();
        } finally {
            lock.unlock();
        }
    }
```

直接调用核心的解除链接，弹出方法. 为空时直接返回null.


```java

    private E unlinkFirst() {
        // assert lock.isHeldByCurrentThread();
            // 如果队首为空，返回空
        Node<E> f = first;
        if (f == null)
            return null;
        // 将第二个元素放到队首，返回当前的队首元素
        Node<E> n = f.next;
        E item = f.item;
        f.item = null;
        f.next = f; // help GC
        first = n;
        if (n == null)
            last = null;
        else
            n.prev = null;
        --count;
        // 唤醒生产者
        notFull.signal();
        return item;
    }

    /**
     * Removes and returns last element, or null if empty.
     */
    private E unlinkLast() {
        // assert lock.isHeldByCurrentThread();
        Node<E> l = last;
        if (l == null)
            return null;
        Node<E> p = l.prev;
        E item = l.item;
        l.item = null;
        l.prev = l; // help GC
        last = p;
        if (p == null)
            first = null;
        else
            p.next = null;
        --count;
        notFull.signal();
        return item;
    }

```

分别解除队首和队尾元素，将他们的下一个作为新的队首和队尾.


##### take 阻塞

```java

    public E takeFirst() throws InterruptedException {
        final ReentrantLock lock = this.lock;
        lock.lock();
        try {
            E x;
            // 如果弹出元素是空，就阻塞等待
            while ( (x = unlinkFirst()) == null)
                notEmpty.await();
            return x;
        } finally {
            lock.unlock();
        }
    }

    public E takeLast() throws InterruptedException {
        final ReentrantLock lock = this.lock;
        lock.lock();
        try {
            E x;
            while ( (x = unlinkLast()) == null)
                notEmpty.await();
            return x;
        } finally {
            lock.unlock();
        }
    }
```

首先分别弹出队首和队尾的元素，如果为空，就在`notEmpty`条件上阻塞等待.

##### poll(e,time,unit)

和`take`很相似，不再重复.


#### 双端队列提供FIFO的队列接口

上面的方法都是针对双端队列的，指定此次操作是队头还是队尾，而双端队列也是直接提供队列的方法的.


```java

    public boolean add(E e) {
        addLast(e);
        return true;
    }

    public boolean offer(E e) {
        return offerLast(e);
    }

    public void put(E e) throws InterruptedException {
        putLast(e);
    }

    public boolean offer(E e, long timeout, TimeUnit unit)
        throws InterruptedException {
        return offerLast(e, timeout, unit);
    }

    public E remove() {
        return removeFirst();
    }

    public E poll() {
        return pollFirst();
    }

    public E take() throws InterruptedException {
        return takeFirst();
    }

    public E poll(long timeout, TimeUnit unit) throws InterruptedException {
        return pollFirst(timeout, unit);
    }
    
```

可以看到，对于普通的队列方法，入队调用`Last`相关， 也就是队尾添加. 出队方法调用`First`相关，也就是队首出队.

因此双端队列可以当做一个`FIFO`的普通队列来使用.


#### 总结


和`LinkedBlockingQueue`很相似，只是提供了双端的接口而已.

* 内部使用链表来存储元素，而且是双端链表，因此保存了队首指针和队尾指针
* 使用`ReentrantLock`来保证内部节点读写之间的同步
* 使用等待条件`notFull`和`notEmpty`来控制生产者和消费者的阻塞与唤醒.
* 支持指定最大容量，当要添加的元素超过了最大容量时，会根据情况进行抛出异常或者阻塞等操作.


## 参考文章


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